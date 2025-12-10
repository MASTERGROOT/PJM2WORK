DECLARE @p0 INT = 192
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
DECLARE @Todate DATETIME = GETDATE()

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


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @RemainRequestDocId TABLE (DocId int,
    DocTypeId int)

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

DECLARE @RefId TABLE (RequestCostLineId int,
    CommittedCostLineId int)

INSERT INTO @RefId
    (RequestCostLineId,CommittedCostLineId)
    SELECT rcl.Id requestid, ccl.Id commitid
    from CommittedCostLines ccl
        LEFT JOIN RequestCostLines rcl ON rcl.Id = ccl.RequestCostLineId
    WHERE (rcl.RefDocId = @DocId AND rcl.RefDocTypeId = @TypeId AND @TypeId IN (24,211))
        OR (ccl.RefDocId = @DocId AND ccl.RefDocTypeId = @TypeId AND @TypeId IN (22,105))
        OR (EXISTS (SELECT 'filter'
        FROM @RemainRequestDocId d
        WHERE d.DocId = rcl.RefDocId AND d.DocTypeId = rcl.RefDocTypeId))

OPTION
(RECOMPILE);


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
            , rcl.DocQty, rcl.DocUnitName, cal.UnitPrice, rcl.Amount, rcl.Description
    FROM RequestCostLines rcl
        INNER JOIN CostAllocationLines cal ON rcl.CostAllocationLineId = cal.Id
        LEFT JOIN BudgetLines bl ON rcl.BudgetLineId = bl.Id
    WHERE (EXISTS (select 'Filter'
    from @RefId c
    WHERE c.CommittedCostLineId IS NULL AND c.RequestCostLineId = rcl.Id))

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
            , ccl.DocQty, ccl.DocUnitName, cal.UnitPrice, ccl.Amount, ccl.Description
    FROM CommittedCostLines ccl
        INNER JOIN CostAllocationLines cal ON ccl.CostAllocationLineId = cal.Id
        LEFT JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
    WHERE (EXISTS (select 'Filter'
    from @RefId c
    WHERE c.CommittedCostLineId = ccl.Id))
) c

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempBudgetRemain', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempBudgetRemain
END;
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
        ,CASE WHEN b.UnitName IN (SELECT * FROM @LSName) THEN 1
            ELSE b.cpQty - b.cqty - b.rcqty
        END NetblQty
        ,b.cpAmount - b.camount - b.rcqty NetblAmount
INTO #TempBudgetRemain
FROM (
    SELECT o.id OrgId 
                ,o.Name
                ,o.code 
                ,bg.*

        FROM Organizations o
        inner JOIN Budgets b ON b.ProjectId = o.id
        inner JOIN
        (
            SELECT bl.WBSId
                    ,bl.Id blId
                    ,rvb.RevisedBudgetId
                    ,LineCode
                    ,bl.Name linename
                    ,ISNULL(bl.Description, bl.Name) description
                    ,bl.ItemCategoryCode
                    ,bl.ItemCategoryName
                    ,bl.ItemMetaCode
                    ,bl.ItemMetaName
                    ,SUM(ISNULL(IIF(rvType.BudgetLineId IS NOT NULL, bl.Amount, 0), 0)) blAmount
                    ,bl.UnitName
                    ,SUM(ISNULL(rvb.CommitQty, 0)) + SUM(ISNULL(rvb.ExpectedQty, 0)) rvQty
                    ,AVG(ISNULL(rvb.CommitUnitPrice, 0) + ISNULL(rvb.ExpectedUnitPrice, 0)) rvUnitPrice
                    ,SUM(ISNULL(rvb.CommitAmount, 0)) + SUM(ISNULL(rvb.ExpectedAmount, 0)) rvAmount
                    ,SUM(ISNULL(rvb.CompleteQty,0)) cpQty
                    ,AVG(ISNULL(rvb.CompleteUnitPrice,0)) cpUnitPrice
                    ,SUM(ISNULL(rvb.CompleteAmount,0)) cpAmount
                    ,ISNULL(SUM(c.cqty),0) cqty
                    ,ISNULL(SUM(c.camount),0) camount
                    ,ISNULL(SUM(rc.rcqty),0) rcqty
                    ,ISNULL(SUM(rc.rcamount),0) rcamount
                    ,b.ProjectId

                   
            FROM dbo.Budgets b 
            inner loop JOIN dbo.BudgetLines bl ON bl.BudgetId = b.Id
            LEFT hash JOIN
            (
                SELECT rvl.BudgetLineId 
                        ,rvl.RevisedBudgetId
                        ,rvl.CommitQty
                        ,rvl.ExpectedQty
                        ,rvl.CompleteQty
                        ,rvl.CommitUnitPrice
                        ,rvl.ExpectedUnitPrice
                        ,rvl.CompleteUnitPrice
                        ,rvl.CommitAmount
                        ,rvl.ExpectedAmount
                        ,rvl.CompleteAmount
                FROM
                (
                    SELECT TOP 1 *
                    FROM dbo.RevisedBudgets
                    WHERE ProjectId = @OrgId
                          --AND date <= @todate
                          and ((RevisedBudgetType = 2 AND Date<=@DocDate) OR RevisedBudgetType = 0)
                    ORDER BY Date DESC
                ) rv
                INNER JOIN dbo.RevisedBudgetLines rvl ON rv.Id = rvl.RevisedBudgetId
            ) rvb ON bl.Id = rvb.BudgetLineId
            LEFT hash JOIN
            (
                SELECT rvl.BudgetLineId
                FROM dbo.RevisedBudgetLines rvl
                     LEFT JOIN dbo.RevisedBudgets rv ON rvl.RevisedBudgetId = rv.Id
                WHERE rv.ProjectId = @OrgId
                      AND rvl.RevisedBudgetType = 0
                GROUP BY rvl.BudgetLineId
            ) rvType ON bl.Id = rvType.BudgetLineId
            outer apply
            (
                SELECT SUM(isnull(c.amount,0)+isnull(difcm.amount,0)) camount
                        ,SUM(ISNULL(c.DocQty,0)+ISNULL(difcm.DocQty,0)) cqty
                        ,c.BudgetLineId
                FROM CommittedCostLines c with(forceseek)
				outer apply
				(
					SELECT 
						SUM(difcm.amount)amount,SUM(difcm.DocQty) DocQty
						,difcm.CommittedCostLineId 
					FROM CommittedCostLines difcm 
					WHERE 
					difcm.CommittedCostLineId =  c.id
					and
					/* difcm.date<=@Todate and  */difcm.AllocationType in (3,4)
                    and difcm.Id NOT IN (SELECT CommitId FROM #TempCommit)
					GROUP by difcm.CommittedCostLineId
				) difcm /*on difcm.CommittedCostLineId =  c.id*/
                WHERE 
				c.OrgId = @OrgId
				-- and c.date <= @Todate
				and c.BudgetLineId = bl.Id
				and c.AllocationType in (1,2)
                and c.Id NOT IN (SELECT CommitId FROM #TempCommit)
                GROUP BY c.BudgetLineId--,rvb.RevisedBudgetId
            ) c /*ON c.BudgetLineId = bl.Id*/
            outer apply
            (
                SELECT SUM(rc.Amount) rcamount, SUM(rc.DocQty) rcqty
                       ,rc.BudgetLineId
                FROM RequestCostLines rc
                WHERE 
                -- rc.date <= @Todate
				-- and
				rc.BudgetLineId = bl.Id
                AND rc.Id NOT IN (SELECT RequestId FROM #TempRequest)
                GROUP BY rc.BudgetLineId
            ) rc /*ON ac.BudgetLineId = c.BudgetLineId*/
            WHERE b.ProjectId = @OrgId
            GROUP BY 
			bl.WBSId, 
            LineCode, 
            bl.Description, 
            BudgetId, 
            b.ProjectId, 
            bl.Id, 
            bl.Name,rvb.RevisedBudgetId
            ,bl.ItemCategoryCode
            ,bl.ItemCategoryName
            ,bl.ItemMetaCode
            ,bl.ItemMetaName
            ,bl.UnitName
        ) bg ON bg.ProjectId = o.Id  
		inner JOIN wbs ON wbs.id = bg.WBSId
        WHERE o.id = @OrgId

) b



/************************************************************************************************************************************************************************/

/*1-core*/
SELECT main.*
    , bud.NetblQty CompleteQty /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteQty,NULL) */
    , CASE WHEN bud.UnitName IN (SELECT * FROM @LSName) THEN bud.NetblAmount
        ELSE bud.cpUnitPrice
        END CompleteUnitPrice 
    , bud.UnitName UnitName /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.UnitName,NULL) */
    , bud.NetblAmount CompleteAmount /* IIF(ROW_NUMBER() OVER (PARTITION BY main.BudgetLineId ORDER BY main.BudgetLineId) = 1,bud.CompleteAmount,NULL) */
    , CASE WHEN bud.UnitName IN (SELECT * FROM @LSName) THEN 1
        ELSE bud.NetblQty - SUM(DocQty) OVER (PARTITION BY main.BudgetlineId ORDER BY main.BudgetLineId)
        END RemainQty
    , bud.NetblAmount - SUM(main.Amount) OVER (PARTITION BY main.BudgetlineId ORDER BY main.BudgetLineId) RemainAmount
FROM (
            SELECT *
        FROM #TempRequest
    UNION ALL
        SELECT *
        FROM #TempCommit
) main
    LEFT JOIN (
        SELECT * 
        FROM #TempBudgetRemain
) bud ON main.BudgetLineId = bud.blId 
ORDER BY main.RefDocId,main.RefDocLineId

/* 2-Org */
select *
from Organizations
where Id = @OrgId

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

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempBudgetRemain', 'U') IS NOT NULL
BEGIN
    DROP TABLE #TempBudgetRemain
END;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
