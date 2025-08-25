/*==> Ref:d:\site\erp\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/

/*รายงานกำไรขั้นต้น รายโครงการ*/

-- DECLARE @p0 DATETIME = '2025-08-22'
-- DECLARE @p1 nvarchar(500) = '204'--'1931'--'1107,1152' --''--
-- DECLARE @p2 BIT = 0

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
/*#TempPOPaid*/
IF OBJECT_ID(N'tempdb..#TempPOPaid') IS NOT NULL
BEGIN
    DROP TABLE #TempPOPaid;
END;

SELECT *
INTO #TempPOPaid
FROM
(
select po.PaidProjectId
			,SUM(po.POTaxbase) POTaxbase
			,SUM(po.POAmount) POAmount
from (

		select po.PaidProjectId,po.TypeVat
					,sum(po.pamount) [POTaxbase]
					,IIF(po.TypeVat != 131,sum(po.pamount) * 1.07,sum(po.pamount)) [POAmount]	
		from(

				/*จ่ายค่าของ Invoice,payment */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode
                        ,IIF(il.CalcVat = 1, vat.SystemCategoryId,131) TypeVat,IIF(il.CalcVat = 1, vat.SystemCategory,'NoVat') SystemCategory ,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
                LEFT JOIN InvoiceLines il ON il.InvoiceId = acl.RefDocId AND acl.RefDocTypeId IN (37,213) AND il.Id = acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM InvoiceLines il
					WHERE il.InvoiceId = acl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId IN (37,213) /* จับทั้ง INAP,INPA ที่ allocate เข้า budgetline ที่เป็น mat */
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 50 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,il.CalcVat
				
				union all
                /*จ่ายค่าของ AdjustInvoice,payment */

				SELECT ccl.CommittedProjectId [PaidProjectId],ccl.[Date],p.Code [PaidDocCode],ccl.RefDocCode
                        ,vat.SystemCategoryId [TypeVat],vat.SystemCategory,sum(ccl.Amount) pamount
				from Payments p
				INNER JOIN PaymentLines pl ON p.Id = pl.PaymentId
				INNER JOIN CommittedCostLines ccl ON pl.DocId = ccl.RefDocId AND ccl.RefDocTypeId = 39
				INNER JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
                -- LEFT JOIN AdjustInvoiceLines ail ON ail.AdjustInvoiceId = ccl.RefDocId AND ccl.RefDocTypeId = 39 AND ail.Id = ccl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM AdjustInvoiceLines il
					WHERE il.AdjustInvoiceId = ccl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 39
					GROUP BY SystemCategoryId, SystemCategory 
				) vat

				where ccl.CommittedProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pl.SystemCategoryId = 39 and ccl.Date <= @Todate --AND pl.DocId = 7
						
				group by ccl.CommittedProjectId,ccl.[Date],p.Code,vat.SystemCategoryId,vat.SystemCategory,ccl.RefDocCode

				union all
				/*จ่ายค่าของ WorkerExpenses */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],pcl.RefDocCode RefDocCode
						,IIF(wel.CalcVat = 1,vat.SystemCategoryId,131) TypeVat
						,IIF(wel.CalcVat = 1,vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
                LEFT JOIN WorkerExpenseLines wel ON wel.WorkerExpenseId = pcl.RefDocId AND pcl.RefDocTypeId  = 97 AND wel.Id = pcl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM WorkerExpenseLines wel
					WHERE wel.WorkerExpenseId = pcl.RefDocId AND wel.SystemCategoryId IN (123,129,131) 
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ WE มีทำ multi vat */

				) vat
				where PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 97 and pcl.Date <= @Todate --AND pcl.RefDocId = 70

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,wel.CalcVat

				union all
				/*จ่ายค่าของ JV  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],pcl.RefDocCode RefDocCode,131 TypeVat,'NoVat' SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 64 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713
				Group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode

				union all
				/*จ่ายค่าของ OP  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode
						,IIF(opl.CalcVat = 1,vat.SystemCategoryId,131) TypeVat
						,IIF(opl.CalcVat = 1,vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
                LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = acl.RefDocId AND acl.RefDocTypeId = 43 AND opl.Id = acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherPaymentLines opl
					WHERE opl.OtherPaymentId = acl.RefDocId AND opl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 43
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 43 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,opl.CalcVat
				
				union all
				/* รับเงินคืนจาก OR  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode RefDocCode
						,IIF(orl.CalcVat = 1,vat.SystemCategoryId,131) TypeVat
						,IIF(orl.CalcVat = 1,vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
                LEFT JOIN OtherReceiveLines orl ON orl.OtherReceiveId = acl.RefDocId AND acl.RefDocTypeId = 44 AND orl.Id = acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherReceiveLines orl
					WHERE orl.OtherReceiveId = acl.RefDocId AND orl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 44
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 44 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,orl.CalcVat

				union all
				/*จ่ายค่าของ ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory
				)po group by po.PaidProjectId,po.TypeVat
		) po
		group by po.PaidProjectId
)po 
option(recompile);
/************************************************************************************************************************************************************************/
/*#TempSCPaid*/
IF OBJECT_ID(N'tempdb..#TempSCPaid') IS NOT NULL
BEGIN
    DROP TABLE #TempSCPaid;
END;

SELECT *
INTO #TempSCPaid
FROM
(
select sc.PaidProjectId
			,SUM(sc.SCTaxbase) SCTaxbase
			,SUM(sc.SCAmount) SCAmount
from (

		select sc.PaidProjectId,sc.TypeVat
					,sum(sc.pamount) [SCTaxbase]
					,IIF(sc.TypeVat != 131,sum(sc.pamount) * 1.07,sum(sc.pamount)) [SCAmount]	
		from(

				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode
				,IIF(il.CalcVat = 1,vat.SystemCategoryId,131) TypeVat,IIF(il.CalcVat = 1,vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				LEFT JOIN Invoicelines il ON il.InvoiceId = acl.RefDocId AND acl.RefDocTypeId IN (37,213) AND il.Id= acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM InvoiceLines il
					WHERE il.InvoiceId = acl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId IN (37,213) /* จับทั้ง INAP,INPA ที่ allocate เข้า budgetline ที่เป็น mat */
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 50 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,il.CalcVat
				
				union all
-- 				/*จ่ายค่าของ AdjustInvoice,payment */

				SELECT ccl.CommittedProjectId [PaidProjectId],ccl.[Date],p.Code [PaidDocCode],ccl.RefDocCode
				,IIF(ail.[CalcVat] = 1, vat.SystemCategoryId, 131) [TypeVat],IIF(ail.CalcVat = 1,vat.SystemCategory, 'NoVat') SystemCategory,sum(ccl.Amount) pamount
				from Payments p
				INNER JOIN PaymentLines pl ON p.Id = pl.PaymentId
				INNER JOIN CommittedCostLines ccl ON pl.DocId = ccl.RefDocId AND RefDocTypeId = 39
				INNER JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
				LEFT JOIN AdjustInvoiceLines ail ON ail.AdjustInvoiceId = ccl.RefDocId AND ccl.RefDocTypeId = 39 AND ail.Id = ccl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM AdjustInvoiceLines il
					WHERE il.AdjustInvoiceId = ccl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 39
					GROUP BY SystemCategoryId, SystemCategory 
				) vat

				where ccl.CommittedProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pl.SystemCategoryId = 39 and ccl.Date <= @Todate --AND pl.DocId = 7
						
				group by ccl.CommittedProjectId,ccl.[Date],p.Code,vat.SystemCategoryId,vat.SystemCategory,ccl.RefDocCode,ail.CalcVat

				union all
				/*จ่ายค่าของ WorkerExpenses */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,IIF(wel.CalcVat = 1,vat.SystemCategoryId,131) TypeVat
						,IIF(wel.CalcVat = 1,vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				LEFT JOIN WorkerExpenseLines wel ON wel.WorkerExpenseId = pcl.RefDocId AND pcl.RefDocTypeId = 97 AND wel.Id = pcl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM WorkerExpenseLines wel
					WHERE wel.WorkerExpenseId = pcl.RefDocId AND wel.SystemCategoryId IN (123,129,131) 
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ WE มีทำ multi vat */

				) vat
				where PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 97 and pcl.Date <= @Todate --AND pcl.RefDocId = 70

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,wel.CalcVat

				union all
				/*จ่ายค่าของ JV  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,'NoVat' SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 64 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713
				Group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode

				union all
				/*จ่ายค่าของ OP  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = acl.RefDocId AND acl.RefDocTypeId = 43 AND opl.Id = acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherPaymentLines opl
					WHERE opl.OtherPaymentId = acl.RefDocId AND opl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 43
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 43 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,opl.CalcVat

				union all
				/* รับเงินคืนจาก OR  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				LEFT JOIN OtherReceiveLines orl ON orl.OtherReceiveId = acl.RefDocId AND acl.RefDocTypeId = 44 AND orl.Id= acl.RefDocLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherReceiveLines orl
					WHERE orl.OtherReceiveId = acl.RefDocId AND orl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 44
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 44 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode,orl.CalcVat

				union all
				/*จ่ายค่าของ ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory )sc group by sc.PaidProjectId,sc.TypeVat

		) sc
		group by sc.PaidProjectId
)sc 
option(recompile);
/************************************************************************************************************************************************************************/
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
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempInvoice', 'U') IS NOT NULL
DROP TABLE #TempInvoice
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

	SELECT il.LocationId,il.id,il.Code,il.[Date],il.RefDocId2,il.RefDocCode2,il.RefDocTypeId2,il.RefDocType2
			,il.BudgetTypeId,il.BudgetType,il.RefDocLineId2,il.VatTypeId,il.VatType
			,CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id)  Invpt 
			,il.CalcVat
			,il.InvoiceAmount,il.InvoiceTaxBase,il.InvoiceTaxAmount
			,il.InvoiceDPAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPAmount
			,il.InvoiceDPTaxbase * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPTaxbase
			,il.InvoiceDPTaxAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPTaxAmount
			,il.InvoiceRTAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceRTAmount
			,il.InvoiceWHT * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceWHT
			,il.InvoiceAdjustAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustAmount
			,il.InvoiceAdjustTaxBase * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustTaxBase
			,il.InvoiceAdjustTaxAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustTaxAmount
	INTO #TempInvoice
	FROM (
		SELECT i.LocationId,i.Id,i.Code,i.[Date],il.RefDocId2,il.RefDocCode2,il.RefDocTypeId2,il.RefDocType2
				,ISNULL(bl.SystemCategoryId,CASE WHEN RefDocTypeId2 = 22 THEN 99 WHEN RefDocTypeId2 = 105 THEN 105 ELSE NULL END) BudgetTypeId
				,ISNULL(bl.SystemCategory,CASE WHEN RefDocTypeId2 = 22 THEN 'Material' WHEN RefDocTypeId2 = 105 THEN 'SubContract' ELSE NULL END) BudgetType
				,ISNULL(il.RefDocLineId2,pal.RefDocLineId)RefDocLineId2,vat.VatTypeId,vat.VatType
				/* ,pt.Invpt */,il.CalcVat
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount)*107/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) ,0)
					ELSE ISNULL((il.Amount - il.SpecialDiscount) ,0) END InvoiceAmount
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL(il.Amount - il.SpecialDiscount,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 100/107,0)
					ELSE ISNULL(il.Amount - il.SpecialDiscount,0) END InvoiceTaxBase
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/107,0)
					ELSE 0 END InvoiceTaxAmount

				,ISNULL(dp.DPAmount,0) /* * pt.Invpt */ InvoiceDPAmount
				,ISNULL(dp.DPTaxbase,0) /* * pt.Invpt */ InvoiceDPTaxbase
				,ISNULL(dp.DPTaxAmount,0) /* * pt.Invpt */ InvoiceDPTaxAmount 
				,ISNULL(rt.RTAmount,0) /* * pt.Invpt */ InvoiceRTAmount
				,ISNULL(wht.WHT,0) /* * pt.Invpt */ InvoiceWHT
				,ISNULL(cn.InvoiceAdjustAmount,0) /* * pt.Invpt */ InvoiceAdjustAmount
				,ISNULL(cn.InvoiceAdjustTaxBase,0) /* * pt.Invpt */ InvoiceAdjustTaxBase
				,ISNULL(cn.InvoiceAdjustTaxAmount,0) /* * pt.Invpt */ InvoiceAdjustTaxAmount
		FROM Invoices i
		left join InvoiceLines il on i.Id = il.InvoiceId
		LEFT JOIN AccountCostLines acl ON acl.RefdoclineId = il.Id AND acl.RefDocTypeId IN (37,213)
		LEFT JOIN Budgetlines bl ON bl.Id = acl.BudgetLineId
		LEFT JOIN ProgressAcceptanceLines pal ON pal.Id = il.RefDocLineId AND pal.ProgressAcceptanceId = il.refdocid AND il.RefDocTypeId IN (209,210)
		-- LEFT JOIN (
		-- 	SELECT Id InvLineId,NULLIF((ISNULL(Amount,0)/ SUM(CASE WHEN SystemCategoryId IN (99,100,105) THEN Amount END)
		-- 		OVER (PARTITION BY invoiceid)),0) Invpt from InvoiceLines where SystemCategoryId IN (99,100,105)
		-- ) pt ON pt.InvLineId = il.Id
		LEFT JOIN (
			select InvoiceId,SUM(Amount) DPAmount,SUM(TaxBase) DPTaxbase,SUM(TaxAmount) DPTaxAmount from InvoiceLines where SystemCategoryId = 54 GROUP BY InvoiceId
		) dp ON i.Id = dp.InvoiceId
		LEFT JOIN (
			select InvoiceId,SUM(Amount) RTAmount from InvoiceLines where SystemCategoryId = 48 GROUP BY InvoiceId
		) rt ON i.Id = rt.InvoiceId
		LEFT JOIN (
			select InvoiceId,SystemCategoryId 
			VatTypeId,SystemCategory VatType from InvoiceLines where SystemCategoryId IN (123,129,131) GROUP BY InvoiceId,SystemCategoryId,SystemCategory
		) vat ON i.Id = vat.InvoiceId
		LEFT JOIN (
				SELECT InvoiceId,SUM(Amount) WHT from InvoiceLines where SystemCategoryId = 138 GROUP BY InvoiceId
				) wht ON wht.InvoiceId = i.Id
		left join (
			select c.Id,cl.RefDocId,cl.RefDocCode
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.AdjustTaxBase),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.AdjustTaxBase),0)
				END InvoiceAdjustTaxBase
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.AdjustTaxAmount),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.AdjustTaxAmount),0)
				END InvoiceAdjustTaxAmount
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.Amount),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.Amount),0)
				END InvoiceAdjustAmount
			from AdjustInvoices c
			left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
			where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1) AND cl.RefDocTypeId = 37
			group by c.Id,cl.RefDocId,cl.RefDocCode,c.DocType,c.DocTypeId
		) cn ON cn.RefDocId = i.Id
		WHERE il.SystemCategoryId IN (99,100,105) and i.DocStatus not in (-1) --AND il.refdocid2 IN (select distinct id from #TempPo)
	) il WHERE il.[Date] <= @Todate AND il.LocationId IN (select ncode from dbo.fn_listCode(@ProjectId))
	option(recompile);
	CREATE INDEX IX_TempInvoice_LocationId ON #TempInvoice(LocationId)
	CREATE INDEX IX_TempInvoice_RefDocLineId2 ON #TempInvoice(RefDocLineId2)
	CREATE INDEX IX_TempInvoice_Id ON #TempInvoice(Id)
	CREATE INDEX IX_TempInvoice_RefDocTypeId2 ON #TempInvoice(RefDocTypeId2)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPV', 'U') IS NOT NULL
DROP TABLE #TempPV
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

	SELECT *
	INTO #TempPV
	FROM (
		SELECT pl.PaymentId,pl.DocId,pl.DocCode,pl.DocTypeId,pl.DocType--,bl.SystemCategoryId BudgetTypeId,bl.SystemCategory BudgetType
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocId,acset.IvId) IvId
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocCode,acset.IvCode) IvCode
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocTypeId,acset.DocTypeId) AcsetDocTypeId
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocType,acset.DocType) AcsetDocType,pt.Pvpt
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.PayAmount,0),ISNULL(pl.PayAmount,0)) 
				+ IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.RetentionSetAmount,0),ISNULL(pl.RetentionSetAmount,0)) PayAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.RetentionSetAmount,0),ISNULL(pl.RetentionSetAmount,0)) RetentionSetAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*(ISNULL(dd.DeductAmount,0) * pt.Pvpt),ISNULL(dd.DeductAmount,0) * pt.Pvpt) DeductAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*(ISNULL(wht.WHT,0) * pt.Pvpt),ISNULL(wht.WHT,0) * pt.Pvpt) WHT
				
		from Payments p
		LEFT JOIN PaymentLines pl ON pl.PaymentId = p.Id
		LEFT JOIN (
			SELECT Id PVLineId,ABS(ISNULL(PayAmount,0)/ NULLIF(SUM(CASE WHEN SystemCategoryId  NOT IN (53,56,57,59,74,107,111,138,141,176) THEN PayAmount END)
					OVER (PARTITION BY PaymentId),0)) Pvpt from PaymentLines where SystemCategoryId  NOT IN (53,56,57,59,74,107,111,138,141,176)
		) pt ON pt.PVLineId = pl.Id
		LEFT JOIN (
			SELECT acct.Id SetId,acct.DocId IvId,acct.DocCode IvCode,acct.DocTypeId,acct.DocType
				,CASE WHEN acct.DocTypeId IN (37,213) THEN ivVat.VatTypeId
						WHEN acct.DocTypeId = 149 THEN 129
						ELSE 131
				END VatTypeId
				,CASE WHEN acct.DocTypeId IN (37,213) THEN ivVat.VatType
						WHEN acct.DocTypeId = 149 THEN 'VatInc'
						ELSE 'NoVat'
				END VatType
			from AcctElementSets acct	
			LEFT JOIN (
				SELECT InvoiceId IvId,SystemCategoryId VatTypeId, SystemCategory VatType FROM InvoiceLines ivl
				WHERE ivl.SystemCategoryId IN (123,129,131)
				GROUP BY InvoiceId,SystemCategoryId,SystemCategory,ivl.RefDocTypeId,ivl.RefDocId
			) ivVat ON ivVat.IvId = acct.DocId AND acct.DocTypeId IN (37,213)
			WHERE acct.ReadyToUse = 1 --AND acct.DocTypeId IN (37,39,40)
		) acset ON acset.SetId = pl.SetId
		LEFT JOIN (
			select cl.AdjustInvoiceId,IIF(cl.RefDocId = 0, c.Id,cl.RefDocId) RefDocId,IIF(cl.RefDocId = 0,c.Code,cl.RefDocCode)RefDocCode
			,IIF(cl.RefDocTypeId = 0,c.DocTypeId,cl.RefDocTypeId) RefDocTypeId,IIF(cl.RefDocTypeId = 0,c.DocType,cl.RefDocType) RefDocType,IIF(c.DocTypeId = 39,cl.Amount*-1,cl.Amount) AdjustAmount
			from AdjustInvoices c
			LEFT JOIN AdjustInvoiceLines cl ON cl.AdjustInvoiceId = c.Id
			where cl.SystemCategoryId in (152,153) 
		) pvcn ON (pvcn.AdjustInvoiceId = pl.DocId AND pl.DocTypeId = 39) OR (pvcn.AdjustInvoiceId = acset.IvId AND acset.DoctypeId =39)
		LEFT JOIN (
				SELECT PaymentId, SUM(PayAmount) DeductAmount from PaymentLines where SystemCategoryId = 176 GROUP BY PaymentId
				) dd ON dd.PaymentId = p.ID
		LEFT JOIN (
				SELECT PaymentId, SUM(DocAmount) WHTBase,SUM(PayAmount) WHT from PaymentLines where SystemCategoryId = 138 GROUP BY PaymentId
				) wht ON wht.PaymentId = p.ID
		where pl.SystemCategoryId IN (37,39,40,44,50,147,149,213,142) AND p.DocStatus NOT IN (-1) --and pl.PaymentId IN (1995)
	) pv
	option(recompile);
	CREATE INDEX IX_TempPV_PaymentId ON #TempPV(PaymentId)
	CREATE INDEX IX_TempPV_DocId ON #TempPV(DocId)
	CREATE INDEX IX_TempPV_DocTypeId ON #TempPV(DocTypeId)
	CREATE INDEX IX_TempPV_IvId ON #TempPV(IvId)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCost', 'U') IS NOT NULL
DROP TABLE #TempCost
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempCost
FROM (
		SELECT acl.AccountProjectId LocationId,acl.RefDocId Id,acl.RefDocCode Code,acl.RefDocTypeId Doctype,acl.[Date],acl.RefDocLineId ActualLineId,bl.SystemCategoryId BudgetTypeId,bl.SystemCategory BudgetType,Doc.VatTypeId,Doc.VatType
				,IIF(acl.RefDocTypeId = 64,1.00,NULLIF(acl.Amount/Doc.SubTotal,0.00)) pt,0.00 DPAmount,0.00 RTAmount,IIF(acl.RefDocTypeId = 64,1.00,NULLIF(acl.Amount/Doc.SubTotal,0.00))*Doc.WHT ActualWHT
				,IIF((doc.VatTypeId = 123 AND doc.CalcVat = 1),ISNULL(acl.Amount,0)*107/100,ISNULL(acl.Amount,0)) * IIF(Doc.isDebit = 1,1,-1)  AS ActualAmount
				,CASE WHEN (Doc.VatTypeId = 129 AND Doc.CalcVat = 1) THEN ISNULL(acl.Amount,0)*100/107 
						WHEN (Doc.VatTypeId = 123 AND Doc.CalcVat = 1) THEN ISNULL(acl.Amount,0)
						ELSE ISNULL(acl.Amount,0)
					END * IIF(Doc.isDebit = 1,1,-1) ActualTaxBase
					,CASE WHEN (Doc.VatTypeId = 129 AND Doc.CalcVat = 1) THEN ISNULL(acl.Amount,0)*7/107
						WHEN (Doc.VatTypeId = 123 AND Doc.CalcVat = 1) THEN ISNULL(acl.Amount,0) * 7/100
						ELSE 0
					END * IIF(Doc.isDebit = 1,1,-1) ActualTaxAmount
				-- ,0.00 AdjustAmount,0.00 AdjustTaxBase,0.00 AdjustTaxAmount,NULL RefDocId2,CAST(NULL AS NVARCHAR(20)) RefDocCode2,NULL RefDocLineId2,0.00 InvoiceAmount,0.00 InvoiceTaxBase,0.00 InvoiceTaxAmount,0.00 InvoiceDPAmount,0.00 InvoiceRTAmount
				-- ,0.00 InvoiceAdjustAmount,0.00 InvoiceAdjustTaxBase,0.00 InvoiceAdjustTaxAmount
				,IIF((DocPaid.VatTypeId = 123 AND DocPaid.CalcVat = 1),ISNULL(pcl.Amount,0)*107/100,ISNULL(pcl.Amount,0)) * IIF(DocPaid.isDebit = 1,1,-1)  AS PayAmount
				,CASE WHEN (DocPaid.VatTypeId = 129 AND DocPaid.CalcVat = 1) THEN ISNULL(pcl.Amount,0)*100/107 
						WHEN (DocPaid.VatTypeId = 123 AND DocPaid.CalcVat = 1) THEN ISNULL(pcl.Amount,0)
						ELSE ISNULL(pcl.Amount,0)
					END * IIF(DocPaid.isDebit = 1,1,-1) PayTaxBase
					,CASE WHEN (DocPaid.VatTypeId = 129 AND DocPaid.CalcVat = 1) THEN ISNULL(pcl.Amount,0)*7/107
						WHEN (DocPaid.VatTypeId = 123 AND DocPaid.CalcVat = 1) THEN ISNULL(pcl.Amount,0) * 7/100
						ELSE 0
					END * IIF(DocPaid.isDebit = 1,1,-1) AS PayTaxAmount
				,0.00 RetentionSetAmount, IIF(pcl.RefDocTypeId = 64,1.00,NULLIF(pcl.Amount/DocPaid.SubTotal,0.00))*DocPaid.DeductAmount DeductAmount, IIF(pcl.RefDocTypeId = 64,1.00,NULLIF(pcl.Amount/DocPaid.SubTotal,0.00))*DocPaid.WHT WHT
		from AccountCostLines acl
		LEFT JOIN BudgetLines bl ON bl.Id = acl.BudgetLineId
		LEFT JOIN PaidCostLines pcl ON pcl.AccountCostLineId = acl.Id
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (107) GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				where opl.guid = acl.RefDocLineGuid --opl.Id = acl.RefDocLineId AND acl.RefDocTypeId = 43 

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal
						,wel.CalcVat,1 isDebit
				FROM workerexpenselines wel 
				LEFT JOIN ( SELECT WorkerExpenseId,SystemCategoryId VatTypeId, SystemCategory VatType FROM WorkerExpenseLines WHERE SystemCategoryId IN (123,129,131) GROUP BY WorkerExpenseId,SystemCategoryId,SystemCategory
					) vat ON vat.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
				SELECT WorkerExpenseId,SUM(Amount) WHT FROM WorkerExpenseLines WHERE SystemCategoryId IN (138) GROUP BY WorkerExpenseId
					) wht ON wht.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
					SELECT WorkerExpenseId,SUM(Amount) SubTotal FROM workerexpenselines WHERE (SystemCategoryId IS NULL OR SystemCategoryId NOT IN (138,123)) GROUP BY WorkerExpenseId
					) st ON st.WorkerExpenseId = wel.WorkerExpenseId
				WHERE wel.guid = acl.RefDocLineGuid --wel.Id = acl.RefDocLineId AND acl.RefDocTypeId = 64

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,129 VatTypeId,'IncVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal
						, 1 CalcVat, isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = acl.RefDocLineGuid --jvl.Id = acl.RefDocLineId AND acl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) Doc
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (107) GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				where opl.guid = pcl.RefDocLineGuid

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal
						,wel.CalcVat,1 isDebit
				FROM workerexpenselines wel 
				LEFT JOIN ( SELECT WorkerExpenseId,SystemCategoryId VatTypeId, SystemCategory VatType FROM WorkerExpenseLines WHERE SystemCategoryId IN (123,129,131) GROUP BY WorkerExpenseId,SystemCategoryId,SystemCategory
					) vat ON vat.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
				SELECT WorkerExpenseId,SUM(Amount) WHT FROM WorkerExpenseLines WHERE SystemCategoryId IN (138) GROUP BY WorkerExpenseId
					) wht ON wht.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
					SELECT WorkerExpenseId,SUM(Amount) SubTotal FROM workerexpenselines WHERE (SystemCategoryId IS NULL OR SystemCategoryId NOT IN (138,123)) GROUP BY WorkerExpenseId
					) st ON st.WorkerExpenseId = wel.WorkerExpenseId
				WHERE wel.guid = pcl.RefDocLineGuid

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,129 VatTypeId,'IncVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal
						, 1 CalcVat,isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = pcl.RefDocLineGuid
		) DocPaid
		WHERE acl.RefDocTypeId IN (64,43,97)
) cost
	WHERE cost.[Date] <= @Todate AND cost.LocationId IN (select ncode from dbo.fn_listCode(@ProjectId))
	option(recompile);
CREATE INDEX IX_TempCost_LocationId ON #TempCost(LocationId)
CREATE INDEX IX_TempCost_ActualLineId ON #TempCost(ActualLineId)

-- Drop the table if it already exists	
IF OBJECT_ID('tempDB..#PoRemain', 'U') IS NOT NULL
DROP TABLE #PoRemain
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT LocationId,(SUM(InvoiceTaxBase)-ISNULL(SUM(InvoiceAdjustTaxBase),0)) - ISNULL(SUM(PayTaxBase)-ISNULL(nonRef.NonRefPayAmount,0),0) PORemain
	,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
	,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount,ISNULL(SUM(InvoiceWHT),0) InvoiceWHT
	,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
	,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
	,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(PayTaxBase),0) PayTaxBase,ISNULL(SUM(PayTaxAmount),0) PayTaxAmount
	,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
	,ISNULL(nonRef.nonRefNetPayAmount,0) NonRefPoNetPayAmount
	,ISNULL(nonRef.NonRefPayAmount,0) NonRefPoPayAmount,ISNULL(nonRef.NonRefRetentionSetAmount,0) NonRefPoRetentionSetAmount,ISNULL(nonRef.NonRefDeductAmount,0) NonRefPoDeductAmount,ISNULL(nonRef.NonRefWHT,0) NonRefPoWHT
	INTO #PoRemain
	FROM (
		select il.LocationId,il.Id,il.Code,il.RefDocTypeId2 Doctype,il.[Date],il.BudgetTypeId,il.BudgetType,il.VatTypeId,il.VatType,il.Invpt
					,SUM(il.InvoiceAmount)InvoiceAmount,SUM(il.InvoiceTaxBase)InvoiceTaxBase,SUM(il.InvoiceTaxAmount)InvoiceTaxAmount,SUM(il.InvoiceDPAmount)InvoiceDPAmount,SUM(il.InvoiceRTAmount)InvoiceRTAmount,SUM(il.InvoiceWHT) InvoiceWHT
					,SUM(il.InvoiceAdjustAmount)InvoiceAdjustAmount,SUM(il.InvoiceAdjustTaxBase)InvoiceAdjustTaxBase,SUM(il.InvoiceAdjustTaxAmount) InvoiceAdjustTaxAmount
					,SUM(il.Invpt*pv.PayAmount) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END) PayTaxBase
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN (il.Invpt*pv.PayAmount) * 7/107
					ELSE 0 END) PayTaxAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN (
					SELECT IvId,SUM(PayAmount) PayAmount,SUM(DeductAmount) DeductAmount,SUM(RetentionSetAmount) RetentionSetAmount,SUM(WHT) WHT
					FROM #TempPV 
					GROUP BY IvId
				) pv ON il.Id = pv.IvId
				WHERE il.BudgetTypeId = 99
				GROUP BY il.LocationId,il.Id,il.Code,il.RefDocTypeId2,il.[Date],il.BudgetTypeId,il.BudgetType,il.VatTypeId,il.VatType,il.Invpt
				UNION ALL
		SELECT LocationId,Id,Code,Doctype,[Date],BudgetTypeId,BudgetType,VatTypeId,VatType,pt
			,ActualAmount InvoiceAmount,ActualTaxBase InvoiceTaxBase,ActualTaxAmount InvoiceTaxAmount
			,0.00 InvoiceDPAmount,0.00 InvoiceRTAmount,0.00 InvoiceWHT
			,0.00 InvoiceAdjustAmount,0.00 InvoiceAdjustTaxBase,0.00 InvoiceAdjustTaxAmount
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,PayTaxBase,PayTaxAmount,RetentionSetAmount,DeductAmount,WHT
		FROM #TempCost
		WHERE BudgetTypeId = 99
	) poRemain
		OUTER APPLY (
		select pcl.PaidProjectId
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) + SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefNetPayAmount
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) *100/107 NonRefPayAmount
		,SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) NonRefRetentionSetAmount
		,SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) NonRefDeductAmount
		,SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefWHT 
		from #TempPV pv
		LEFT JOIN PaidCostLines pcl ON pcl.RefDocId = pv.IvID AND pv.AcsetDocTypeId = 39
		LEFT JOIN BudgetLines bl ON bl.Id = pcl.BudgetLineId
		where bl.SystemCategoryId = 99 AND pv.AcsetDoctypeID = 39 AND pcl.PaidProjectId = poRemain.LocationId
		group by pcl.PaidProjectId
	) nonRef /* มาจากเอกสาร CN ลอยที่มีการทำ PV เเละจัดสรรเข้างบที่เป็น Mat */
	GROUP BY LocationId,nonRef.NonRefNetPayAmount,nonRef.NonRefPayAmount,nonRef.NonRefRetentionSetAmount,nonRef.NonRefDeductAmount,nonRef.NonRefWHT
	option(recompile);


-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#SCRemain', 'U') IS NOT NULL
DROP TABLE #SCRemain
	-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT LocationId,(SUM(InvoiceTaxBase)-ISNULL(SUM(InvoiceAdjustTaxBase),0)) - ISNULL(SUM(PayTaxBase),0)-ISNULL(nonRef.NonRefPayAmount,0) SCRemain
		,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
		,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount,ISNULL(SUM(InvoiceWHT),0) InvoiceWHT
		,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
		,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
		,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(PayTaxBase),0) PayTaxBase,ISNULL(SUM(PayTaxAmount),0) PayTaxAmount
		,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
		,ISNULL(nonRef.nonRefNetPayAmount,0) NonRefScNetPayAmount
		,ISNULL(nonRef.NonRefPayAmount,0) NonRefScPayAmount,ISNULL(nonRef.NonRefRetentionSetAmount,0) NonRefScRetentionSetAmount,ISNULL(nonRef.NonRefDeductAmount,0) NonRefScDeductAmount,ISNULL(nonRef.NonRefWHT,0) NonRefScWHT
	INTO #SCRemain
	FROM (
		select il.LocationId,il.Id,il.Code,il.RefDocTypeId2 Doctype,il.[Date],il.BudgetTypeId,il.BudgetType,il.VatTypeId,il.VatType,il.Invpt
					,SUM(il.InvoiceAmount)InvoiceAmount,SUM(il.InvoiceTaxBase)InvoiceTaxBase,SUM(il.InvoiceTaxAmount)InvoiceTaxAmount,SUM(il.InvoiceDPAmount)InvoiceDPAmount,SUM(il.InvoiceRTAmount)InvoiceRTAmount,SUM(il.InvoiceWHT) InvoiceWHT
					,SUM(il.InvoiceAdjustAmount)InvoiceAdjustAmount,SUM(il.InvoiceAdjustTaxBase)InvoiceAdjustTaxBase,SUM(il.InvoiceAdjustTaxAmount) InvoiceAdjustTaxAmount
					,SUM(il.Invpt*pv.PayAmount) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END) PayTaxBase
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN (il.Invpt*pv.PayAmount) * 7/107
					ELSE 0 END) PayTaxAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN (
					SELECT IvId,SUM(PayAmount) PayAmount,SUM(DeductAmount) DeductAmount,SUM(RetentionSetAmount) RetentionSetAmount,SUM(WHT) WHT
					FROM #TempPV 
					GROUP BY IvId
				) pv ON il.Id = pv.IvId
				WHERE /* il.Id = 17124 AND */ il.BudgetTypeId = 105
				GROUP BY il.LocationId,il.Id,il.Code,il.RefDocTypeId2,il.[Date],il.BudgetTypeId,il.BudgetType,il.VatTypeId,il.VatType,il.Invpt
				UNION ALL
		SELECT LocationId,Id,Code,Doctype,[Date],BudgetTypeId,BudgetType,VatTypeId,VatType,pt
			,ActualAmount InvoiceAmount,ActualTaxBase InvoiceTaxBase,ActualTaxAmount InvoiceTaxAmount
			,0.00 InvoiceDPAmount,0.00 InvoiceRTAmount,0.00 InvoiceWHT
			,0.00 InvoiceAdjustAmount,0.00 InvoiceAdjustTaxBase,0.00 InvoiceAdjustTaxAmount
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,PayTaxBase,PayTaxAmount,RetentionSetAmount,DeductAmount,WHT
		FROM #TempCost
		WHERE BudgetTypeId = 105
	) scRemain
			OUTER APPLY (
		select pcl.PaidProjectId
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) + SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefNetPayAmount
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) *100/107 NonRefPayAmount
		,SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) NonRefRetentionSetAmount
		,SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) NonRefDeductAmount
		,SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefWHT 
		from #TempPV pv
		LEFT JOIN PaidCostLines pcl ON pcl.RefDocId = pv.IvID AND pv.AcsetDocTypeId = 39
		LEFT JOIN BudgetLines bl ON bl.Id = pcl.BudgetLineId
		where bl.SystemCategoryId = 105 AND pv.AcsetDoctypeID = 39 AND pcl.PaidProjectId = scRemain.LocationId
		group by pcl.PaidProjectId
	) nonRef /* มาจากเอกสาร CN ลอยที่มีการทำ PV เเละจัดสรรเข้างบที่เป็น Sub */
	GROUP BY LocationId,nonRef.NonRefNetPayAmount,nonRef.NonRefPayAmount,nonRef.NonRefRetentionSetAmount,nonRef.NonRefDeductAmount,nonRef.NonRefWHT
	option(recompile);

/************************************************************************************************************************************************************************/

/*1-core*/
SELECT o.Id
		,o.[Code(2)]
		,o.[Name(3)]
		,o.OriginalContractNO
		,o.[OriginalContractAmount(4)]
		,o.VODate
		,o.[VOAmount(5)]
		,o.[CurrentContractAmount(6)]
		,o.ContractNO
		,o.[RVOriginalContract TaxBase(7)]
		,o.[RVVOContract TaxBase(8)]
		,o.[RVTotal TaxBase(9)]
		,o.[Current Budget Mat(10)]
		,o.[Current Budget Sub(11)]
		,o.[MatPay Taxbase(12)]
		,o.POPayAmount,o.POPayTaxBase,o.POPayTaxAmount,o.POPayRetention
		,o.POPayDeduct,o.POPayWHT
		,o.[SupPay Taxbase(13)]
		,o.SCPayAmount,o.SCPayTaxBase,o.SCPayTaxAmount,o.SCPayRetention
		,o.SCPayDeduct,o.SCPayWHT
		,o.[PVTotal Taxbase(14)]
		,o.[Gross profit Taxbase(15)]
		,o.[ReMainContract Taxbase(16)]
		,o.[PORemainTaxbase(17)]
		,o.POInvoiceAmount,o.POInvoiceTaxBase,o.POInvoiceTaxAmount
		,o.POInvoiceDPAmount,o.POInvoiceRTAmount, o.POInvoiceWHT
		,o.POInvoiceAdjustAmount,o.POInvoiceAdjustTaxBase,o.POInvoiceAdjustTaxAmount
		,o.[SCRemainTaxbase(18)]
		,o.SCInvoiceAmount,o.SCInvoiceTaxBase,o.SCInvoiceTaxAmount
		,o.SCInvoiceDPAmount,o.SCInvoiceRTAmount,o.SCInvoiceWHT
		,o.SCInvoiceAdjustAmount,o.SCInvoiceAdjustTaxBase,o.SCInvoiceAdjustTaxAmount
		,o.[TotalRemainTaxbase(19)]
		,o.[BudgetRemainMat(20)]
		,o.[BudgetRemainSub(21)]
		,o.[BudgetRemain(22)]
		,o.[EstCostPaidTaxbase(23)]
		,o.[Est Gross profit Taxbase(24)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit Taxbase(25)]),'%') [% Est Gross profit Taxbase(25)] 
		,o.[JvAmount Taxbase(26)]
		,o.[Est Gross profit and loss minus internal rent(27)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit and loss minus internal rent(28)]),'%') [% Est Gross profit and loss minus internal rent(28)]

FROM(

	select	org.Id
		,org.Code [Code(2)] /*(2)*/
		,org.Name [Name(3)]/*(2)*/
		,orgP.ContractNO [OriginalContractNO] 
		,(ISNULL(orgP.ContractAmount,0) * 100 / 107) [OriginalContractAmount(4)] /*(4)*/
		,pvo.VOcontractdate [VODate]
		,ISNULL(pvo.VOSUM,0) [VOAmount(5)] /*(5)*/
		,(ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) [CurrentContractAmount(6)]  /*(6) = (4)+(5)*/
		,m.ContractNO

		--,ISNULL(m.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/
		,ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/

		--,ISNULL(s.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/
		,ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/

		--,(ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/

		,ISNULL(BRMat.BlMatAmount,0) [Current Budget Mat(10)] /*(10)*/
		,ISNULL(BRSub.BlSubAmount,0) [Current Budget Sub(11)] /*(11)*/
		,ISNULL(po.PayTaxBase,0) [MatPay Taxbase(12)] /*(12)*/
		,ISNULL(po.PayAmount,0) POPayAmount,ISNULL(po.PayTaxBase,0) POPayTaxBase,ISNULL(po.PayTaxAmount,0) POPayTaxAmount,ISNULL(po.RetentionSetAmount,0) POPayRetention
		,ISNULL(po.DeductAmount,0) POPayDeduct,ISNULL(po.WHT,0) POPayWHT
		,ISNULL(sc.PayTaxBase,0) [SupPay Taxbase(13)] /*(13)*/
		,ISNULL(sc.PayAmount,0) SCPayAmount,ISNULL(sc.PayTaxBase,0) SCPayTaxBase,ISNULL(sc.PayTaxAmount,0) SCPayTaxAmount,ISNULL(sc.RetentionSetAmount,0) SCPayRetention
		,ISNULL(sc.DeductAmount,0) SCPayDeduct,ISNULL(sc.WHT,0) SCPayWHT
		,ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0) [PVTotal Taxbase(14)]  /*(14) = (12)+(13)*/

		--,((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/

		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0))) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/

		,ISNULL(po.PORemain,0) [PORemainTaxbase(17)] /*(17)*/
		,ISNULL(po.InvoiceAmount,0) POInvoiceAmount,ISNULL(po.InvoiceTaxBase,0) POInvoiceTaxBase,ISNULL(po.InvoiceTaxAmount,0) POInvoiceTaxAmount
		,ISNULL(po.InvoiceDPAmount,0) POInvoiceDPAmount,ISNULL(po.InvoiceRTAmount,0) POInvoiceRTAmount, ISNULL(po.InvoiceWHT,0) POInvoiceWHT
		,ISNULL(po.InvoiceAdjustAmount,0) POInvoiceAdjustAmount,ISNULL(po.InvoiceAdjustTaxBase,0) POInvoiceAdjustTaxBase,ISNULL(po.InvoiceAdjustTaxAmount,0) POInvoiceAdjustTaxAmount
		,ISNULL(sc.SCRemain,0) [SCRemainTaxbase(18)] /*(18)*/
		,ISNULL(sc.InvoiceAmount,0) SCInvoiceAmount,ISNULL(sc.InvoiceTaxBase,0) SCInvoiceTaxBase,ISNULL(sc.InvoiceTaxAmount,0) SCInvoiceTaxAmount
		,ISNULL(sc.InvoiceDPAmount,0) SCInvoiceDPAmount,ISNULL(sc.InvoiceRTAmount,0) SCInvoiceRTAmount,ISNULL(sc.InvoiceWHT,0) SCInvoiceWHT
		,ISNULL(sc.InvoiceAdjustAmount,0) SCInvoiceAdjustAmount,ISNULL(sc.InvoiceAdjustTaxBase,0) SCInvoiceAdjustTaxBase,ISNULL(sc.InvoiceAdjustTaxAmount,0) SCInvoiceAdjustTaxAmount
		,ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0) [TotalRemainTaxbase(19)] /*(19)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) [BudgetRemainMat(20)] /*(20)*/
		,ISNULL(BRMat.BudgetRemainMat,0) /* - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.ActualTaxbase,0) */ [BudgetRemainMat(20)] /*(20) = (10)-(12)-(17)*/

		--,ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemainSub(21)] /*(21)*/
		,ISNULL(BRSub.BudgetRemainSub,0) /* - ISNULL(sp.SCTaxbase,0) - ISNULL(SCRemain.ActualTaxbase,0) */ [BudgetRemainSub(21)] /*(21) = (11)-(13)-(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemain(22)] /*(22) = (20)+(21)*/
		,ISNULL(BRMat.BudgetRemainMat,0) /* - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.ActualTaxbase,0) */ /*(20)*/
		 + ISNULL(BRSub.BudgetRemainSub,0) /* - ISNULL(sp.SCTaxbase,0) - ISNULL(SCRemain.ActualTaxbase,0) */ /*(21)*/
		 [BudgetRemain(22)] /*(22) = (20)+(21)*/

		--,ISNULL((ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0)) + (BRMat.BudgetRemainMat + BRSub.BudgetRemainSub),0) [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/
		,(ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))  /*(19)*/
		  +(ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0)) /*(22)*/
		  [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/


		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--		+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--		+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/

		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) )) /*(23)*/ 
			[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/


		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--	  ELSE	ROUND(ISNULL((((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) /*(6)*/
		--			/ ((((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0)))  /*(15)*/
		--			+ ((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) ,0),2)/*(23)*/ 
		--	END [% Est Gross profit Taxbase(25)] /*(25) = (6) / ((15)+(16)-(23))*/

		,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
			  ELSE	ROUND(ISNULL(
								(( (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) ))) /*(23)*/
							/ ((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) ,0),2)/*(6)*/
			END [% Est Gross profit Taxbase(25)] /*(25) = (24) / (6) */


		,ISNULL(jl.JvAmount,0) [JvAmount Taxbase(26)] /*(26)*/

		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	- ISNULL(jl.JvAmount,0) /*(26)*/
		--      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/

		,( (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) ))) /*(23)*/ 
			- ISNULL(jl.JvAmount,0) /*(26)*/
		      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/

		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--		ELSE ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) /*(6)*/
		--			/ ( (((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--			+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--			- ISNULL(jl.JvAmount,0) )  /*(26)*/
		--		END [% Est Gross profit and loss minus internal rent(28)] /*(28) = (6) / (15)+(16)-(23)-(26)*/

		,CASE WHEN ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
				ELSE  (( (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) ))) /*(23)*/ 
			- ISNULL(jl.JvAmount,0))
					/ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) /*(6)*/
				END [% Est Gross profit and loss minus internal rent(28)] /*(28) = (27) / (6)*/
				
from	Organizations org
left join Organizations_ProjectConstruction orgP on org.Id = orgP.id
left join (	select SUM(isnull(ContractAmount,0)* 100 / 107) VOSUM,
						max(ContractDate) VOcontractdate,
						pv.ProjectConstructionId 
						from ProjectVOes pv
						where ContractDate <= @Todate
						group by pv.ProjectConstructionId
						)pvo on pvo.ProjectConstructionId = org.id
/*รายได้สัญญาณหลักรับแล้ว*/
left join (select orgP.Id,orgP.ContractNO
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from Organizations_ProjectConstruction orgP
			left join TaxItemLines tl on orgP.ContractNO = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by orgP.Id,orgP.ContractNO
			) m on org.Id = m.Id
/*รายได้สัญญาณ VO รับแล้ว*/
left join (select vo.ProjectConstructionId--,vo.Code
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from ProjectVOes vo
			left join TaxItemLines tl on vo.Code = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by vo.ProjectConstructionId
			) s on org.Id = s.ProjectConstructionId
/*จ่ายอุปกรณ์*/
left join #PoRemain po on org.Id = po.LocationId
/*จ่ายค่าแรง*/
left join #SCRemain sc on org.Id = sc.LocationId

/*BudgetMatRemain*/
left join (select bm.ProjectId,bm.Date,bm.BlMatAmount,bm.UseMatAmount,bm.BlMatAmount - bm.UseMatAmount - ISNULL(reAlloc.remainAmount,0)  [BudgetRemainMat]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlMatAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseMatAmount
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.AccountProjectId Orgid,c.BudgetLineId,sum(c.Amount) Amount
								from AccountCostLines c
                                                                where c.AccountProjectId is not null
                                                                          and Date <= @Todate
								group by c.AccountProjectId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 99
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bm 
					OUTER APPLY (
						SELECT cal.CostAllocateProjectId,SUM(cal.Amount) remainAmount
						FROM CostAllocationLines cal
						WHERE cal.IsAllocated = 0 AND cal.CostAllocateProjectId = bm.ProjectId AND cal.RefDocDate <= @Todate AND cal.RefDocTypeId = 37
						GROUP BY cal.CostAllocateProjectId
					) reAlloc 
			)BRMat on org.Id = BRMat.ProjectId
/*BudgetSubRemain*/
left join (select bs.ProjectId,bs.Date,bs.BlSubAmount,bs.UseSubAmount,bs.BlSubAmount - bs.UseSubAmount - ISNULL(reAlloc.remainAmount,0)  [BudgetRemainSub]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlSubAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseSubAmount
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.AccountProjectId OrgId,c.BudgetLineId,sum(c.Amount) Amount
								from AccountCostLines c
								where c.AccountProjectId is not null
                                                                          and Date <= @Todate
								group by c.AccountProjectId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 105
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bs
					OUTER APPLY (
						SELECT cal.CostAllocateProjectId,SUM(cal.Amount) remainAmount
						FROM CostAllocationLines cal
						WHERE cal.IsAllocated = 0 AND cal.CostAllocateProjectId = bs.ProjectId AND cal.RefDocDate <= @Todate AND cal.RefDocTypeId = 213
						GROUP BY cal.CostAllocateProjectId
					) reAlloc 
			)BRSub on org.Id = BRSub.ProjectId
/*JV 41000716 : รายได้ค่าเช่าภายใน*/
left join (select jl.OrgId,sum(isnull(jl.Amount,0)) JvAmount
			from JVLines jl
                        left join JournalVouchers j on j.Id = jl.JournalVoucherId
			where j.Date  <= @Todate
                                        and jl.AccountCode in (41000716)
					and jl.isDebit = 1
			group by jl.OrgId
			) jl on org.Id = jl.OrgId

/*Interrim BF*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrTaxBase
					,sum(irl.TaxAmount) IrTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO = irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) ir on org.Id = ir.OrgId
/*Interrim BF VO*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrVoTaxBase
					,sum(irl.TaxAmount) IrVoTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrVoAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO <> irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) irv on org.Id = irv.OrgId
/*BF OR*/
left join (select ac.OrgId,ac.OrgCode
					,sum(orl.Amount*100/107) BFTaxbase
					,sum(orl.Amount) BFAmount
			from AcctElementSets ac
			inner join OtherReceiveLines orl on ac.DocCode = orl.RefDocCode
			where ac.DocTypeId = 149 and ac.AccountCode = '11130101'
					and orl.SystemCategory = 'SetUpAcctBalFwd' and orl.isDebit = 0
			group by ac.OrgId,ac.OrgCode
			) ac on org.Id = ac.OrgId
/*รายได้สัญญาณหลักรับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORMAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) orm on org.Id = orm.LocationId

/*รายได้สัญญาณ VO รับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORVAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) ors on org.Id = ors.LocationId
where (exists (select 1 from @OrgId a where org.Id = a.Id) or @ProjectId is null)
)o order by o.[Code(2)]
/************************************************************************************************************************************************************************/

/*2-Filter*/
select @Todate [As Of Date]
		--,@ProjectId
		,(SELECT dbo.GROUP_CONCAT(code)  FROM dbo.Organizations WHERE Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) Project
		,IIF(@IncChild = 1,'Include Child','NO') IncChild

/************************************************************************************************************************************************************************/

/*3-Company*/
select * from fn_CompanyInfoTable(@ProjectId)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempInvoice', 'U') IS NOT NULL
DROP TABLE #TempInvoice
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPV', 'U') IS NOT NULL
DROP TABLE #TempPV
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCost', 'U') IS NOT NULL
DROP TABLE #TempCost

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#PoRemain', 'U') IS NOT NULL
DROP TABLE #PoRemain
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#SCRemain', 'U') IS NOT NULL
DROP TABLE #SCRemain