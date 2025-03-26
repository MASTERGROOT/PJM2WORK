/*==> Ref:d:\site\erp\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/

/*รายงานกำไรขั้นต้น รายโครงการ*/

-- DECLARE @p0 DATETIME = '2025-03-04'
-- DECLARE @p1 nvarchar(500) = '143'--'1931'--'1107,1152' --''--
-- DECLARE @p2 BIT = 1

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
/*#TempSCRemain*/
IF OBJECT_ID(N'tempdb..#TempSCRemain') IS NOT NULL
BEGIN
    DROP TABLE #TempSCRemain;
END;

SELECT *
INTO #TempSCRemain
FROM
(
select sc.LocationId,SUM(sc.SCRemainTaxbase) SCRemainTaxbase,SUM(sc.SCRemainAmount) SCRemainAmount
from(
	select sc.LocationId,sc.SystemCategoryId
			,sum(sc.ActualAmount) [SCRemainTaxbase]
			,IIF(sc.SystemCategoryId != 131,sum(sc.ActualAmount) * 1.07,sum(sc.ActualAmount)) [SCRemainAmount]	
	from(
					-- /*SC PO*/
					-- SELECT ccl.CommittedProjectId [LocationId],ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date]
					-- 		,CASE WHEN ccl.RefDocTypeId = 105 AND scl.CalcVat = 1 THEN scvat.SystemCategoryId
					-- 			WHEN ccl.RefDocTypeId = 210 AND vol.CalcVat = 1 THEN vovat.SystemCategoryId
					-- 			WHEN ccl.RefDocTypeId = 22 AND pol.CalcVat = 1 THEN povat.SystemCategoryId
					-- 			WHEN ccl.RefDocTypeId = 23 AND pol.CalcVat = 1 THEN adjpovat.SystemCategoryId
					-- 			ELSE 131
					-- 		END SystemCategoryId
					-- 		,SUM(ccl.Amount) commitAmount
					-- from CommittedCostLines ccl 
					-- INNER JOIN BudgetLines bl ON bl.Id = ccl.BudgetLineId
					-- LEFT JOIN SubContractLines scl ON scl.SubContractId = ccl.RefDocId AND ccl.RefDocTypeId = 105 AND ccl.RefDocLineId = scl.Id
					-- LEFT JOIN VariationOrderLines vol ON vol.VariationOrderId = ccl.RefDocId AND ccl.RefDocTypeId = 210 AND ccl.RefDocLineId = vol.Id
					-- LEFT JOIN POLines pol ON pol.POId = ccl.RefDocId AND ccl.RefDocTypeId = 22 AND ccl.RefDocLineId = pol.Id
					-- LEFT JOIN AdjustPOLines apl ON apl.AdjustPOId = ccl.RefDocId AND ccl.RefDocTypeId = 23 AND ccl.RefDocLineId = apl.Id
					-- OUTER APPLY( 
					-- 		SELECT SystemCategoryId, SystemCategory FROM POLines pol
					-- 		WHERE pol.POId = ccl.RefDocId AND pol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 22
					-- 		GROUP BY SystemCategoryId, SystemCategory ) povat
					-- OUTER APPLY( 
					-- 		SELECT SystemCategoryId, SystemCategory FROM AdjustPOLines apol
					-- 		WHERE apol.AdjustPOId = ccl.RefDocId AND apol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 23
					-- 		GROUP BY SystemCategoryId, SystemCategory ) adjpovat
					-- OUTER APPLY( 
					-- 		SELECT SystemCategoryId, SystemCategory FROM SubContractLines scl
					-- 		WHERE scl.SubContractId = ccl.RefDocId AND scl.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 105
					-- 		GROUP BY SystemCategoryId, SystemCategory ) scvat
					-- OUTER APPLY( 
					-- 		SELECT SystemCategoryId, SystemCategory FROM VariationOrderLines vol
					-- 		WHERE vol.VariationOrderId = ccl.RefDocId AND vol.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 210
					-- 		GROUP BY SystemCategoryId, SystemCategory ) vovat
					-- WHERE ccl.CommittedProjectId = @ProjectId AND ccl.[Date] <= @Todate AND bl.SystemCategoryId IN (105) AND ccl.RefDocTypeId IN (22,23,105,210)
					-- GROUP by ccl.CommittedProjectId,ccl.RefDocId,ccl.RefDocCode,ccl.RefDocTypeId,ccl.[Date],scvat.SystemCategoryId,vovat.SystemCategoryId,scl.CalcVat,vol.CalcVat,pol.CalcVat,povat.SystemCategoryId,adjpovat.SystemCategoryId
					-- UNION ALL
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
					
					WHERE acl.AccountProjectId = @ProjectId AND acl.[Date] <= @Todate AND bl.SystemCategoryId IN (105) AND acl.RefDocTypeId IN (37,213,64,43,44,97)
					Group BY acl.AccountProjectId,acl.RefDocId,acl.RefDocCode,acl.RefDocTypeId,acl.[Date],wel.CalcVat,opl.CalcVat,orl.CalcVat,IlVat.SystemCategoryId
							,OPvat.SystemCategoryId,ORvat.SystemCategoryId,WEvat.SystemCategoryId,IlVat.SystemCategoryId,il.CalcVat
		)sc group by sc.LocationId,sc.SystemCategoryId
	)sc INNER JOIN #TempSCPaid scpd ON scpd.PaidProjectId = LocationId
	group by sc.LocationId
)sc

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
		,o.[SupPay Taxbase(13)]
		,o.[PVTotal Taxbase(14)]
		,o.[Gross profit Taxbase(15)]
		,o.[ReMainContract Taxbase(16)]
		,o.[PORemainTaxbase(17)]
		,o.[SCRemainTaxbase(18)]
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
		,ISNULL(mp.POTaxbase,0) [MatPay Taxbase(12)] /*(12)*/
		,ISNULL(sp.SCTaxbase,0) [SupPay Taxbase(13)] /*(13)*/
		,ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0) [PVTotal Taxbase(14)]  /*(14) = (12)+(13)*/

		--,((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/

		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0))) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/

		,ISNULL(PORemain.PORemainTaxbase,0) [PORemainTaxbase(17)] /*(17)*/
		,ISNULL(SCRemain.SCRemainTaxbase,0) [SCRemainTaxbase(18)] /*(18)*/
		,ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0) [TotalRemainTaxbase(19)] /*(19)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) [BudgetRemainMat(20)] /*(20)*/
		,ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0) [BudgetRemainMat(20)] /*(20) = (10)-(12)-(17)*/

		--,ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemainSub(21)] /*(21)*/
		,ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0) [BudgetRemainSub(21)] /*(21) = (11)-(13)-(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemain(22)] /*(22) = (20)+(21)*/
		,(ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) /*(20)*/
		 + (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) /*(21)*/
		 [BudgetRemain(22)] /*(22) = (20)+(21)*/

		--,ISNULL((ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0)) + (BRMat.BudgetRemainMat + BRSub.BudgetRemainSub),0) [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/
		,(ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))  /*(19)*/
		  +( (ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) 
		     + (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) ) /*(22)*/
		  [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/


		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--		+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--		+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/

		,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0)))) /*(15)*/
			+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
				+ ( (ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) 
				+ (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) )) /*(23)*/ 
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
								(( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0))))  /*(15)*/
									+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
									- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
										+ ( (ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) 
										+ (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) ))) /*(23)*/
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

		,( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0))))  /*(15)*/
			+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
				+ ( (ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) 
				+ (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) ))) /*(23)*/ 
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
				ELSE  (( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.SCTaxbase,0))))  /*(15)*/
							+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
							- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
								+ ( (ISNULL(BRMat.BlMatAmount,0) - /* ISNULL(mp.POTaxbase,0) - */ ISNULL(PORemain.ActualTaxbase,0)) 
								+ (ISNULL(BRSub.BlSubAmount,0) - /* ISNULL(sp.SCTaxbase,0) - */ ISNULL(SCRemain.ActualTaxbase,0)) ))) /*(23)*/ 
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
left join #TempPOPaid mp on org.Id = mp.PaidProjectId
/*จ่ายค่าแรง*/
left join #TempSCPaid sp on org.Id = sp.PaidProjectId
/*TempPORemain*/
-- left join #TempPORemain PORemain on org.Id = PORemain.LocationId
LEFT JOIN (SELECT rm.LocationId,rm.PORemainTaxbase - pd.POTaxbase [PORemainTaxbase],rm.PORemainAmount - pd.POAmount [PORemainAmount] ,rm.PORemainAmount [ActualAmount], rm.PORemainTaxbase [ActualTaxbase]
			FROM #TempPORemain rm INNER JOIN #TempPOPaid pd ON pd.PaidProjectId = rm.LocationId ) PORemain ON org.Id = PORemain.LocationId
/*TempSCRemain*/
-- left join #TempSCRemain SCRemain on org.Id = SCRemain.LocationId
LEFT JOIN (SELECT rm.LocationId,rm.SCRemainTaxbase - pd.SCTaxbase [SCRemainTaxbase],rm.scRemainAmount - pd.SCAmount [SCRemainAmount] ,rm.SCRemainAmount [ActualAmount], rm.SCRemainTaxbase [ActualTaxbase]
			FROM #TempSCRemain rm INNER JOIN #TempSCPaid pd ON pd.PaidProjectId = rm.LocationId ) SCRemain ON org.Id = SCRemain.LocationId
/*BudgetMatRemain*/
left join (select bm.ProjectId,bm.Date,bm.BlMatAmount,bm.UseMatAmount
			from (
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
					where bl.SystemCategoryId = 99
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bm 
			)BRMat on org.Id = BRMat.ProjectId
/*BudgetSubRemain*/
left join (select bs.ProjectId,bs.Date,bs.BlSubAmount,bs.UseSubAmount
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlSubAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseSubAmount
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
					where bl.SystemCategoryId = 105
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bs
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