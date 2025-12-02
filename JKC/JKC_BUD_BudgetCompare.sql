DECLARE @p0 INT = 196
DECLARE @p1 INT = 24 /* PR = 24, PO = 22, WR = 211, SC = 105 */

DECLARE @DocId INT = @p0
DECLARE @TypeId INT = @p1
DECLARE @DocDate DATETIME = (CASE 
                                WHEN @TypeId IN (24,211) THEN (SELECT MAX([Date]) FROM RequestCostLines WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId GROUP BY [Date])
                                WHEN @TypeId IN (22,105) THEN (SELECT MAX([Date]) FROM CommittedCostLines WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId GROUP BY [Date])
                            END)

DECLARE @OrgId INT = (CASE 
                            WHEN @TypeId IN (24,211) THEN (SELECT OrgId FROM RequestCostLines WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId GROUP BY OrgId)
                            WHEN @TypeId IN (22,105) THEN (SELECT OrgId FROM CommittedCostLines WHERE RefDocId = @DocId AND RefDocTypeId = @TypeId GROUP BY [OrgId])
                        END)


DECLARE @RemainRequestDocId TABLE (DocId int,DocTypeId int)

INSERT INTO @RemainRequestDocId
    (DocId,DocTypeId)
SELECT DISTINCT rcl.RefDocId, rcl.RefDocTypeId
FROM RequestCostLines rcl
WHERE (EXISTS (SELECT 'filter' 
                FROM CommittedCostLines ccl 
                WHERE ccl.RefDocId = @DocId AND ccl.RefDocTypeId = @TypeId AND ccl.RequestCostLineId = rcl.Id)
        ) AND @TypeId IN (22,105)

OPTION
(RECOMPILE);

DECLARE @RefId TABLE (RequestCostLineId int,CommittedCostLineId int)

INSERT INTO @RefId
	(RequestCostLineId,CommittedCostLineId)
SELECT rcl.Id requestid, ccl.Id commitid
from RequestCostLines rcl
LEFT JOIN CommittedCostLines ccl ON rcl.Id = ccl.RequestCostLineId
WHERE (rcl.RefDocId = @DocId AND rcl.RefDocTypeId = @TypeId AND @TypeId IN (24,211))
    OR (EXISTS (SELECT 'filter' 
                FROM @RemainRequestDocId d
                WHERE d.DocId = rcl.RefDocId AND d.DocTypeId = rcl.RefDocTypeId))

OPTION
(RECOMPILE);

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempRequest', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempRequest
END;
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempRequest
FROM (
    SELECT rcl.RefDocId, rcl.RefDocCode,rcl.[Date], rcl.RefDocTypeId, rcl.RefDocLineId,rcl.RevisedBudgetId, rcl.BudgetLineId, bl.LineCode,COALESCE(bl.ItemMetaCode,bl.ItemCategoryCode) ItemMetaCode, bl.Description ItemMetaName
            ,cal.DocQty,cal.DocUnitName,cal.UnitPrice,cal.Amount,rcl.Description
    FROM RequestCostLines rcl 
    INNER JOIN CostAllocationLines cal ON rcl.CostAllocationLineId = cal.Id 
    LEFT JOIN BudgetLines bl ON rcl.BudgetLineId = bl.Id
    WHERE (EXISTS (select 'Filter' from @RefId c WHERE c.CommittedCostLineId IS NULL AND c.RequestCostLineId = rcl.Id))

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
    SELECT ccl.RefDocId,ccl.RefDocCode,ccl.[Date], ccl.RefDocTypeId, ccl.RefDocLineId, ccl.CommittedRevisedBudgetId RevisedBudgetId, ccl.BudgetLineId, bl.LineCode,COALESCE(bl.ItemMetaCode,bl.ItemCategoryCode) ItemMetaCode, bl.Description ItemMetaName
            ,cal.DocQty,cal.DocUnitName,cal.UnitPrice,cal.Amount,ccl.Description
    FROM CommittedCostLines ccl 
    INNER JOIN CostAllocationLines cal ON ccl.CostAllocationLineId = cal.Id 
    LEFT JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
    WHERE (EXISTS (select 'Filter' from @RefId c WHERE c.CommittedCostLineId = ccl.Id))
) c

/************************************************************************************************************************************************************************/

/*1-core*/
SELECT main.*
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteQty,NULL) CompleteQty
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteUnitPrice,NULL) CompleteUnitPrice
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.UnitName,NULL) UnitName
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteAmount,NULL) CompleteAmount
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteQty,NULL) -
    IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,SUM(DocQty) OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId),NULL) RemainQty
    ,IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteAmount,NULL) -
    IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,SUM(Amount) OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId),NULL) RemainAmount
FROM (
    SELECT * FROM #TempRequest
    UNION ALL 
    SELECT * FROM #TempCommit
) main
LEFT JOIN (
    SELECT bl.Id BudgetLineId,rbl.RevisedBudgetId,bl.LineCode,bl.WBSCode
        ,bl.ItemCategoryCode,bl.ItemCategoryName,bl.ItemMetaCode,bl.ItemMetaName,rbl.Description
        ,rbl.CompleteQty,bl.UnitName,rbl.CompleteUnitPrice,rbl.CompleteAmount,rbl.Remarks
    FROM BudgetLines bl 
    LEFT JOIN RevisedBudgetLines rbl ON bl.Id = rbl.BudgetLineId
) bud ON main.BudgetLineId = bud.BudgetLineId AND bud.RevisedBudgetId = main.RevisedBudgetId

/* 2-Org */
select * from Organizations where Id = @OrgId

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @OrgId
-----------------------------------------------------------------------------------------------------------------------------------------------;

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


