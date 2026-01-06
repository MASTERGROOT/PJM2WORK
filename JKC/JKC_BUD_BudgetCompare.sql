DECLARE @p0 INT = 374
DECLARE @p1 INT = 24
/* PR = 24, PO = 22, WR = 211, SC = 105 */

DECLARE @DocId INT = @p0
DECLARE @TypeId INT = @p1
DECLARE @DocDate DATETIME = (CASE 
                                WHEN @TypeId IN (24,211) THEN (
                                    SELECT MAX([Date])
                                    FROM RequestCostLines
                                    WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId
                                    GROUP BY [Date])
                                WHEN @TypeId IN (22,105) THEN (
                                    SELECT MAX([Date])
                                    FROM CommittedCostLines
                                    WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId
                                    GROUP BY [Date])
                            END)
-- DECLARE @Todate DATETIME = GETDATE()

DECLARE @OrgId INT = (CASE 
                            WHEN @TypeId IN (24,211) THEN (
                                SELECT OrgId
                                FROM RequestCostLines
                                WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId
                                GROUP BY OrgId)
                            WHEN @TypeId IN (22,105) THEN (
                                SELECT OrgId
                                FROM CommittedCostLines
                                WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId
                                GROUP BY [OrgId])
                        END)
DECLARE @LSName TABLE (UnitName NVARCHAR(20))
INSERT INTO @LSName (UnitName)
    SELECT value FROM STRING_SPLIT((SELECT aliasName FROM unitmeasurements WHERE aliasName LIKE '%LS%'), ',')

/*หา revise ที่จะดึงมาเป็นตัวหลัก*/
DECLARE @RevisedBudgetId int = ( SELECT TOP 1 id FROM dbo.RevisedBudgets WHERE ProjectId = @OrgId 
AND Date <= @DocDate
AND DocStatus >= 4
ORDER BY CreateTimestamp DESC )

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- DECLARE @RemainRequestDocId TABLE (DocId int,
--     DocTypeId int)

-- INSERT INTO @RemainRequestDocId
--     (DocId,DocTypeId)
--     SELECT DISTINCT rcl.RefDocId, rcl.RefDocTypeId
--     FROM RequestCostLines rcl
--     WHERE (EXISTS (SELECT 'filter'
--         FROM CommittedCostLines ccl
--         WHERE ccl.RefDocId = @DocId AND ccl.RefDocTypeId = @TypeId AND ccl.RequestCostLineId = rcl.Id)
--             ) AND @TypeId IN (22,105)

-- OPTION
-- (RECOMPILE);
DECLARE @BudgetLineId TABLE (BudgetLineId int)
INSERT INTO @BudgetLineId
    (BudgetLineId)
    SELECT BudgetlineId
    FROM RequestCostLines
    WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId
    UNION ALL
    SELECT BudgetlineId
    FROM CommittedCostLines
    WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId

OPTION
(RECOMPILE);
-- SELECT * from @BudgetLineId

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempRequest', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempRequest
END;
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempRequest
FROM (
    SELECT rcl.Id RequestId,rcl.RefDocId, rcl.RefDocCode, rcl.[Date], rcl.RefDocTypeId, rcl.RefDocLineId, rcl.RevisedBudgetId, rcl.BudgetLineId, bl.LineCode, COALESCE(bl.ItemMetaCode,bl.ItemCategoryCode) ItemMetaCode, bl.Description ItemMetaName
            , rcl.RemainQty DocQty, rcl.DocUnitName, IIF(rcl.RemainQty <= 0, 0, cal.UnitPrice) UnitPrice, rcl.RemainAmount Amount, rcl.Description
    FROM (
        SELECT r1.*
            ,r2.*
        from RequestCostLines r1
        LEFT JOIN (
            SELECT bse.DocId,bse.DocCode,bse.doctype,bse.DocTypeId,bse.DocLineId,bser.RemainQty,bser.RemainAmount,bser.Zero
            from BookedStockElementSets bse
            INNER JOIN BookedStockElementSets_BookedStockElementSetRemain bser ON bse.Id = bser.Id
            --WHERE DocTypeId = 24 AND DocId = 367/* DocTypeId = 24 AND Id = 2172 */
        ) r2 ON r1.RefDocId = r2.DocId AND r1.RefDocTypeId = r2.DocTypeId AND r1.RefDocLineId = r2.DocLineId
        WHERE r1.CommittedCostLineId IS NULL  
    ) rcl
        LEFT JOIN CostAllocationLines cal ON rcl.CostAllocationLineId = cal.Id
        LEFT JOIN BudgetLines bl ON rcl.BudgetLineId = bl.Id
    WHERE rcl.BudgetLineId IN (SELECT BudgetLineId FROM @BudgetLineId)
        AND rcl.RevisedBudgetId = @RevisedBudgetId
        AND (rcl.Zero = 0 OR (rcl.RefDocId = @DocId AND rcl.RefDocTypeId = @TypeId))

) r


-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCommit', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempCommit
END;
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempCommit
FROM (
    SELECT ccl.Id CommitId,ccl.RefDocId, ccl.RefDocCode, ccl.[Date], ccl.RefDocTypeId, ccl.RefDocLineId, ccl.CommittedRevisedBudgetId RevisedBudgetId, ccl.BudgetLineId, bl.LineCode, COALESCE(bl.ItemMetaCode,bl.ItemCategoryCode) ItemMetaCode, bl.Description ItemMetaName
            , ccl.DocQty, ccl.DocUnitName, IIF(ccl.DocQty <= 0, 0, cal.UnitPrice) UnitPrice, ccl.Amount, ccl.Description
    FROM CommittedCostLines ccl
        INNER JOIN CostAllocationLines cal ON ccl.CostAllocationLineId = cal.Id
        LEFT JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
    WHERE ccl.BudgetLineId IN (SELECT BudgetLineId FROM @BudgetLineId)
        AND ccl.CommittedRevisedBudgetId = @RevisedBudgetId


) c



/************************************************************************************************************************************************************************/

/*1-core*/
SELECT main.*,avgup.AvgUnitPrice
    ,bud.CompleteQty /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteQty,NULL) */
    ,bud.CompleteUnitPrice 
    ,bud.UnitName /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.UnitName,NULL) */
    ,bud.CompleteAmount /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteAmount,NULL) */
    ,CASE WHEN bud.UnitName IN (SELECT * FROM @LSName) THEN 1
        ELSE bud.CompleteQty - SUM(DocQty) OVER (PARTITION BY main.BudgetlineId ORDER BY main.BudgetLineId)
        END RemainQty
    ,bud.CompleteAmount - SUM(main.Amount) OVER (PARTITION BY main.BudgetlineId ORDER BY main.BudgetLineId) RemainAmount
    ,dbo.SitePath(main.RefDocTypeId,main.RefDocId) AS DocPath
    ,CASE WHEN main.RefDocId = @DocId and main.RefDocTypeId = @TypeId THEN 1 ELSE 0 END AS IsCurrentDoc
    ,CASE WHEN main.DocQty <= 0 THEN 1 ELSE 0 END AS IsZeroQty
FROM (
            SELECT *
        FROM #TempRequest
    UNION ALL
        SELECT *
        FROM #TempCommit
) main
    LEFT JOIN (
    SELECT bl.Id BudgetLineId,rbl.RevisedBudgetId,bl.LineCode,bl.WBSCode
        ,bl.ItemCategoryCode,bl.ItemCategoryName,bl.ItemMetaCode,bl.ItemMetaName,rbl.Description
        ,rbl.CompleteQty,bl.UnitName,rbl.CompleteUnitPrice,rbl.CompleteAmount,rbl.Remarks
    FROM BudgetLines bl 
    LEFT JOIN RevisedBudgetLines rbl ON bl.Id = rbl.BudgetLineId AND rbl.RevisedBudgetId = @RevisedBudgetId
) bud ON main.BudgetLineId = bud.BudgetLineId 
LEFT JOIN (
        SELECT ItemMetaCode, SUM(Amount) / SUM(DocQty) AvgUnitPrice
        FROM
        (
            SELECT ItemMetaCode, DocQty,Amount
            FROM #TempRequest
            UNION ALL
            SELECT ItemMetaCode, DocQty,Amount
            FROM #TempCommit
        ) x 
GROUP BY ItemMetaCode
) avgup ON avgup.ItemMetaCode = main.ItemMetaCode
ORDER BY main.RefDocId,main.RefDocLineId

/* 2-Org */
select *
from Organizations
where Id = @OrgId

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @OrgId
---------------------------------------------------------------------------------------------------------------------------------------------;


-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCommit', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempCommit
END;

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempRequest', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempRequest
END;


SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
