/*==> Ref:d:\site\erp\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/

/*รายงานกำไรขั้นต้น รายโครงการ*/

DECLARE @p0 DATETIME = '2025-03-04'
DECLARE @p1 nvarchar(500) = '143'--'1931'--'1107,1152' --''--
DECLARE @p2 BIT = 1

DECLARE @Todate DATETIME = @p0
DECLARE @ProjectId nvarchar(500) = @p1
DECLARE @IncChild BIT = @p2

/************************************************************************************************************************************************************************/
DECLARE @OrgId TABLE (Id int not null);

INSERT INTO @OrgId(Id)     /*Save More OrgId Or Single OrgId Not Include Child to Temp.*/
            
            SELECT   distinct orgD.ChildrenId       
            FROM   dbo.fn_organizationDepends() orgD
			where (@incChild = 1 and orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)))
			or (isnull(@incChild,0) = 0 and  orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)) and orgD.OrgId = orgD.ChildrenId)
            

/************************************************************************************************************************************************************************/
/*#Tempbudget*/
IF OBJECT_ID(N'tempdb..#Tempbudget') IS NOT NULL
BEGIN
    DROP TABLE #Tempbudget;
END;

SELECT *
INTO #Tempbudget
FROM
(

select *
from (
		select ProjectId,Id,Date
				, ROW_NUMBER () over (partition by ProjectId,BudgetId order by ProjectId,BudgetId,Date DESC) rvNo
				, Code
				, Description
		from RevisedBudgets
		--where Date <= @Todate
) rv
where rv.rvNo  = 1
)r 
option(recompile);
/************************************************************************************************************************************************************************/
/*#TempPORemain*/
IF OBJECT_ID(N'tempdb..#TempPORemain') IS NOT NULL
BEGIN
    DROP TABLE #TempPORemain;
END;

SELECT *
INTO #TempPORemain
FROM
(
	select po.LocationId
			,SUM(po.PORemainTaxbase) PORemainTaxbase
			,SUM(po.PORemainAmount) PORemainAmount
from (
		select po.LocationId,po.SystemCategoryId
			,sum(po.ActualAmount) [PORemainTaxbase]
			,IIF(po.SystemCategoryId != 131,sum(po.ActualAmount) * 1.07,sum(po.ActualAmount)) [PORemainAmount]
			from(
				-- /*SC PO*/
				-- 	SELECT ccl.CommittedProjectId [LocationId],ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date]
				-- 			,CASE WHEN ccl.RefDocTypeId = 105 AND scl.CalcVat = 1 THEN scvat.SystemCategoryId
				-- 				WHEN ccl.RefDocTypeId = 210 AND vol.CalcVat = 1 THEN vovat.SystemCategoryId
				-- 				WHEN ccl.RefDocTypeId = 22 AND pol.CalcVat = 1 THEN povat.SystemCategoryId
				-- 				WHEN ccl.RefDocTypeId = 23 AND pol.CalcVat = 1 THEN adjpovat.SystemCategoryId
				-- 				ELSE 131
				-- 			END SystemCategoryId
				-- 			,SUM(ccl.Amount) commitAmount
				-- 	from CommittedCostLines ccl 
				-- 	INNER JOIN BudgetLines bl ON bl.Id = ccl.BudgetLineId
				-- 	LEFT JOIN SubContractLines scl ON scl.SubContractId = ccl.RefDocId AND ccl.RefDocTypeId = 105 AND ccl.RefDocLineId = scl.Id
				-- 	LEFT JOIN VariationOrderLines vol ON vol.VariationOrderId = ccl.RefDocId AND ccl.RefDocTypeId = 210 AND ccl.RefDocLineId = vol.Id
				-- 	LEFT JOIN POLines pol ON pol.POId = ccl.RefDocId AND ccl.RefDocTypeId = 22 AND ccl.RefDocLineId = pol.Id
				-- 	LEFT JOIN AdjustPOLines apl ON apl.AdjustPOId = ccl.RefDocId AND ccl.RefDocTypeId = 23 AND ccl.RefDocLineId = apl.Id
				-- 	OUTER APPLY( 
				-- 			SELECT SystemCategoryId, SystemCategory FROM POLines pol
				-- 			WHERE pol.POId = ccl.RefDocId AND pol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 22
				-- 			GROUP BY SystemCategoryId, SystemCategory ) povat
				-- 	OUTER APPLY( 
				-- 			SELECT SystemCategoryId, SystemCategory FROM AdjustPOLines apol
				-- 			WHERE apol.AdjustPOId = ccl.RefDocId AND apol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 23
				-- 			GROUP BY SystemCategoryId, SystemCategory ) adjpovat
				-- 	OUTER APPLY( 
				-- 			SELECT SystemCategoryId, SystemCategory FROM SubContractLines scl
				-- 			WHERE scl.SubContractId = ccl.RefDocId AND scl.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 105
				-- 			GROUP BY SystemCategoryId, SystemCategory ) scvat
				-- 	OUTER APPLY( 
				-- 			SELECT SystemCategoryId, SystemCategory FROM VariationOrderLines vol
				-- 			WHERE vol.VariationOrderId = ccl.RefDocId AND vol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 210
				-- 			GROUP BY SystemCategoryId, SystemCategory ) vovat
				-- 	WHERE ccl.CommittedProjectId = @ProjectId AND ccl.[Date] <= @Todate AND bl.SystemCategoryId IN (99) AND ccl.RefDocTypeId IN (22,23,105,210)
				-- 	GROUP by ccl.CommittedProjectId,ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date],scvat.SystemCategoryId,vovat.SystemCategoryId,scl.CalcVat,vol.CalcVat,pol.CalcVat,povat.SystemCategoryId,adjpovat.SystemCategoryId
				-- 	union all
				-- 	/*Inven*/
				-- 	SELECT ccl.CommittedProjectId [LocationId],ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date],131 SystemCategoryId,SUM(ccl.Amount) commitAmount
				-- 	from CommittedCostLines ccl 
				-- 	INNER JOIN BudgetLines bl ON bl.Id = ccl.BudgetLineId
				-- 	WHERE ccl.CommittedProjectId = @ProjectId AND ccl.[Date] <= @Todate AND bl.SystemCategoryId IN (99) AND ccl.RefDocTypeId IN (1,2)
				-- 	GROUP by ccl.CommittedProjectId,ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date]
				-- 	UNION ALL
					/* AP,JV,OP,OR,WE */
					SELECT acl.AccountProjectId [LocationId],acl.RefDocId,acl.RefDocCode,acl.RefDocTypeId,acl.[Date]
							/* ,CASE WHEN acl.RefDocTypeId = 97 THEN wel.CalcVat
								WHEN acl.RefDocTypeId = 37 THEN 1
								WHEN acl.RefDocTypeId = 43 THEN opl.CalcVat
								WHEN acl.RefDocTypeId = 44 THEN orl.CalcVat
								WHEN acl.RefDocTypeId = 64 THEN 0
							END CalVat */ /* ไว้เช็คว่าบรรทัดไหนคิด vat บ้าง */
							,CASE WHEN acl.RefDocTypeId = 37 THEN ISNULL(IlVat.SystemCategoryId,131)
								WHEN acl.RefDocTypeId = 64  AND il.CalcVat = 1 THEN ISNULL(IlVat.SystemCategoryId,131)
								WHEN acl.RefDocTypeId = 43 AND opl.CalcVat = 1 THEN ISNULL(OPvat.SystemCategoryId,131)
								WHEN acl.RefDocTypeId = 44 AND Orl.CalcVat = 1 THEN ISNULL(ORvat.SystemCategoryId,131)
								WHEN acl.RefDocTypeId = 97 AND wel.CalcVat = 1  THEN ISNULL(WEvat.SystemCategoryId,131)
								ELSE 131
							END SystemCategoryId,SUM(acl.Amount) [ActualAmount]--, ROW_NUMBER() OVER (PARTITION BY acl.RefdocId,acl.RefDocTypeId ORDER BY acl.RefdocId)
					from AccountCostLines acl 
					INNER JOIN BudgetLines bl ON bl.Id = acl.BudgetLineId
					LEFT JOIN WorkerExpenseLines wel ON acl.RefDocId = wel.WorkerExpenseId AND acl.RefDocTypeId = 97 AND acl.RefDocLineId = wel.Id
                    LEFT JOIN Invoicelines il ON acl.RefDocId = il.InvoiceId AND acl.RefDocTypeId IN (37,213) AND acl.RefDocLineId = il.Id 
                    LEFT JOIN OtherPaymentLines opl ON acl.RefDocId = opl.OtherPaymentId AND acl.RefDocTypeId = 43 AND acl.RefDocLineId = opl.Id
                    LEFT JOIN OtherReceiveLines orl ON acl.RefDocId = orl.OtherReceiveId AND acl.RefDocTypeId = 44 AND acl.RefDocLineId = orl.Id
					OUTER APPLY( 
							SELECT SystemCategoryId, SystemCategory FROM InvoiceLines il
							WHERE il.InvoiceId = acl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId IN (37,213)
							GROUP BY SystemCategoryId, SystemCategory ) IlVat
					OUTER APPLY( 
							SELECT SystemCategoryId, SystemCategory FROM AdjustInvoiceLines ajil
							WHERE ajil.AdjustInvoiceId = acl.RefDocId AND ajil.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 39
							GROUP BY SystemCategoryId, SystemCategory ) AdjIlVat
					OUTER APPLY( 
							SELECT SystemCategoryId, SystemCategory FROM OtherPaymentLines opl
							WHERE opl.OtherPaymentId = acl.RefDocId AND opl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 43
							GROUP BY SystemCategoryId, SystemCategory ) OPvat
					OUTER APPLY( 
							SELECT SystemCategoryId, SystemCategory FROM OtherReceiveLines orl
							WHERE orl.OtherReceiveId = acl.RefDocId AND orl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 44
							GROUP BY SystemCategoryId, SystemCategory ) ORvat
					OUTER APPLY( 
							SELECT SystemCategoryId, SystemCategory FROM WorkerExpenseLines wel
							WHERE wel.WorkerExpenseId = acl.RefDocId AND wel.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 97
							GROUP BY SystemCategoryId, SystemCategory ) WEvat
					
					WHERE acl.AccountProjectId = @ProjectId AND acl.[Date] <= @Todate AND bl.SystemCategoryId IN (99) AND acl.RefDocTypeId IN (37,213,64,43,44,97)
					Group BY acl.AccountProjectId,acl.RefDocId,acl.RefDocCode,acl.RefDocTypeId,acl.[Date],wel.CalcVat,opl.CalcVat,orl.CalcVat,IlVat.SystemCategoryId
							,OPvat.SystemCategoryId,ORvat.SystemCategoryId,WEvat.SystemCategoryId,IlVat.SystemCategoryId,il.CalcVat
		)po group by po.LocationId,po.SystemCategoryId
	)po group by po.LocationId
)po 
option(recompile);
/************************************************************************************************************************************************************************/
-- select bm.ProjectId,bm.Date,(bm.BlMatAmount * 100 / 107) BlMatAmount,bm.UseMatAmount,((bm.BlMatAmount * 100 / 107)-bm.UseMatAmount) [BudgetRemainMat]
-- 			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlMatAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseMatAmount
					,SUM(rl.CompleteAmount) - SUM(isnull(c.Amount,0)) [BudgetRemainMat]
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.OrgId,c.BudgetLineId,sum(c.Amount) Amount
								from CommittedCostLines c
                                                                where c.OrgId is not null
                                                                          and Date <= @Todate
								group by c.OrgId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where /* bl.SystemCategoryId IN (99,105) AND */ r.ProjectId = @ProjectId AND rl.[Date] <= @Todate	
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					-- )bm 
SELECT bl.SystemCategory,SUM(rl.CompleteAmount) from RevisedBudgetLines rl
LEFT JOIN BudgetLines bl ON bl.Id = rl.BudgetLineId
where rl.RevisedBudgetId = 1483 GROUP BY bl.SystemCategory