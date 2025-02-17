/*==> Ref:f:\pjm2\gservice\content\printing\reportcommands\bud_projectsummaryreport_revise.sql ==>*/
 
/* PROJECT SUMMARY REPORT*/

/*Last Edit : Pichet : 2020-07-07 : Fix Performance*/
/*Last Edit : Pichet : 2020-07-23 : Fix Performance*/
/*Last Edit : Bankเอง : 2020-09-25 : MS-16384*/
/* Last Edit : Bankเอง : 2020-11-19 : MS-17536 แก้เรื่องที่ยอด CommitedCost ไม่ตรง */
/* 06-01-2020 : Edit By แบงค์เอง MS-17684 แก้ไขเรื่องที่ช่อง Invoice กับ Receipt เขาอยากเปลี่ยนให้โชว์ชนกับตัวของรายงาน 2 ตัว */
/* Last Edit : Bank เอง : 2020-12-08 : MS-15831 เพิ่มเติมเรื่องฟิลเตอร์ ContractDate และ Status ในรายงานได้ */
/*2021-03-18 : Edit By Bank เอง MS-19181 แก้ไขให้ช่อง Invoice กับ Receipt กลับไปเป็นแบบเก่าเพราะเขาตั้งใจจะให้ชนกับหน้า Project ได้ */
/*2022-01-27 : Edit By Bank เอง : MS-22880 ปรับเรื่องการดึงดาต้าของ PO ที่มี Milestone แตกต่างจากตัวเอกสาร เพื่อให้สามารถชนกับรายงาน Budget ได้ */
/*2022-03-08 : Edit By Sornthep : เอาที่แบงค์เขียนของการ์ด MS-22880 ออก เนื่องจากเวอร์ชั่นล่าสุด เก็บ data orgid ที่ commitcostlines ถูกต้องตาม milestone แล้ว  */
/*2022-03-16 : Edit By Bank เอง : แก้เรื่องการส่ง ORG ไปที่ Store remaining ให้ส่งแค่ ORG ไม่ซ้ำก็พอ ส่งซ้ำบางทีมันเยอะเกิน มันหนักไป */
/*2023-02-15 : Edit By ยิม :  MS-27507 ย้าย table  ProjectProgress ไปใช้ ProjectScheduleProgresses แทน (อันเก่าไม่ใช้แล้ว)*/
/*2023-03-01 : Edit By ไอซ์ : MS-27631 :  [KKR] PROJECT SUMMARY REPORT ยอดที่แสดงในรายงานต้องเป็นยอดก่อน VAT*/
/*2023-06-07 : Pichet : MS-21648*/
/*2023-06-28 : Pichet : MS-28644 [3bs][PROJECT SUMMARY REPORT] ช่อง Receipt แสดงยอดไม่ตรงกับหน้า Job Info */
/*2023-08-21 : Pichet : MS-29428 รายงาน PROJECT SUMMARY REPORT แสดงข้อมูลช่อง   RECEIPT  ผิด*/
/*2023-08-21 : Pichet : MS-29439 มีการทำรับเงินแล้ว มาดูในรายงานยอด Receipt กับไม่แสดง*/
/*2023-08-09 : Pichet : MS-29233 รายงาน Project Summary คอลัมน์ Current Budget แก้ให้ใช้ Baseline เมื่อไม่พบ Revise ตาม Filter*/

 --DECLARE @p0 DATETIME = '2024-12-18'
 --declare @p1 nvarchar(500) = '4'--'1931'--'1107,1152' --''--
 --DECLARE @p2 BIT = 1
 --DECLARE @p3 DATETIME = ''
 --DECLARE @p4 DATETIME = ''

 --DECLARE @p5  nvarchar(500) = null
 --DECLARE @p6 nvarchar(500) = null
 --DECLARE @p7 nvarchar(500) = null
 --DECLARE @p8 nvarchar(100) = null

DECLARE @Todate DATETIME = @p0
declare @projectCode nvarchar(500) = @p1
DECLARE @checkRemainAllocate BIT = @p2
DECLARE @ToContractDate DATETIME = @p3
DECLARE @EndContractDate DATETIME = @p4

DECLARE @ConstructionStatus  nvarchar(500) = @p5
DECLARE @FinancialStatus nvarchar(500) =@p6
DECLARE @ProgressStatus nvarchar(500) = @p7
DECLARE @SearchprojectCode nvarchar(100) = @p8
--declare @TaxMethod int
--declare @TaxRate decimal

--select @TaxMethod = TaxMethod, @TaxRate = TaxRate from InterimPayments where OrgId = @OrgId 

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*##### Company condition Report #####*/
declare @RND int = 2
declare @ten real = 10
declare @minval decimal(21,12) = power(@ten,-@RND)  -- for check fraction



IF OBJECT_ID(N'tempdb..#temporg', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #temporg;
    END;

select o.Id 
 into #temporg
 from 
 Organizations org 
 left join Organizations o on o.Path like org.Path + '%'
 where 
( 
	(isnull( @projectCode,'')  =''  or org.Id in (SELECT ncode FROM dbo.fn_listCode(@projectCode)))
	AND (isnull( @SearchprojectCode,'')  ='' or org.Code LIKE '%' + @SearchprojectCode + '%')
)


 IF OBJECT_ID(N'tempdb..#tempGroup', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #tempGroup;
    END;


if(isnull( @projectCode,'')  != '' or isnull( @SearchprojectCode,'')  != '')
begin

	select 

	torg.Id

	into #tempGroup

	from #temporg torg
	inner join Organizations org on torg.Id = org.Id
	cross apply string_split(replace(replace(replace(org.Path,concat('|' ,torg.Id ,'|'),''),'||',','),'|',''),',') pathid
	left join #temporg torg2 on pathid.value = torg2.Id
	group by
	torg.Id
	having
	sum(iif(torg2.Id is null ,0,1)) = 0

end

/************************************* TempRoleOrg *******************************************/

-- DECLARE @DoctypeList NVARCHAR(MAX) = '22,126'; 
DECLARE @WorkerId INT  = dbo.fn_currentUser(); 
IF OBJECT_ID(N'tempdb..#TempRoleOrg') IS NOT NULL
BEGIN
    DROP TABLE #TempRoleOrg;
END;

DECLARE @isPowerUser BIT = 0

IF @WorkerId IS NULL
BEGIN
	SET @isPowerUser = 1
END

IF @isPowerUser = 0
BEGIN
	SELECT @isPowerUser = IIF(@WorkerId = w.Id,1,0) FROM dbo.CompanyConfigs cf
	INNER JOIN dbo.Workers w ON cf.Value = w.UserName
	WHERE ConfigName = 'GODWorker'
END

SELECT *
INTO #TempRoleOrg
FROM (
    SELECT 
			DISTINCT op.ChildrenId [OrgId],IIF(m.OrganizationId IS NULL,1,0) [AllOrg]
		FROM 
		dbo.Roles r
		INNER JOIN dbo.OrganizationMembers m ON r.Id = m.RoleId	
		LEFT JOIN dbo.fn_organizationDepends() op ON m.OrganizationId = op.OrgId
		WHERE m.WorkerId = @WorkerId --AND op.ChildrenId = @projectCode

) o;


 /*======================= Set ProjectId ============================*/
 DECLARE @tmpProject NVARCHAR(MAX)
select @tmpProject = dbo.GROUP_CONCAT(DISTINCT o.Id)
 from 
 Organizations org 
 left join Organizations o on o.Path like org.Path + '%'
 where 
 (isnull( @projectCode,'')  =''  or org.Id in (SELECT ncode FROM dbo.fn_listCode(@projectCode)))
	AND (isnull( @SearchprojectCode,'')  ='' or org.Code LIKE '%' + @SearchprojectCode + '%')


DECLARE @exists bit  = 0
IF EXISTS(SELECT 1 from #temporg)
BEGIN
	SET @exists = 1
END 

IF	OBJECT_ID('tempdb..#tempallo') IS NOT NULL
BEGIN													   
	DROP TABLE #tempallo

END

IF	OBJECT_ID('tempdb..#tempact') IS NOT NULL
BEGIN													   
	DROP TABLE #tempact

END
IF	OBJECT_ID('tempdb..#tempbudget') IS NOT NULL
BEGIN													   
	DROP TABLE #tempbudget

END

IF	OBJECT_ID('tempdb..#tempProjectStatus') IS NOT NULL
BEGIN													   
	DROP TABLE #tempProjectStatus
END

/*##### ส่วนคิด Remaining #####*/

CREATE TABLE #tempallo (   LocationId INT, remainingallo decimal(21,6) )
CREATE TABLE #tempact (   OrgId INT, remain decimal(21,6) )

/*##### Doc Commit Detail #####*/
insert into #tempallo
EXEC	[dbo].[sp_ManeeSystemCoreRemainingCommitBudgetRptManyProject] 
		@Todate = @Todate,
		@OrgId = @tmpProject;

/*##### Doc Account Detail #####*/
insert into #tempact
EXEC	[dbo].[sp_ManeeSystemCoreRemainingAccountBudgetRptManyProject]
		@Todate = @Todate,
		@OrgId = @tmpProject


	select  o.id,
			o.level-4 level,
			o.name,
			o.Code,
			o.Parent,
			iif(o.level >= 4 ,o.parent,oparent.parent) opa 
			,iif(o.level >= 4 ,o.code,oparent.code) oparentcode
			,o.path path
			,IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*isnull(op.CurrencyRate,1)) * 100 / 107),ISNULL(op.ContractAmount,0)*isnull(op.CurrencyRate,1)) ContractAmount
			,IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*isnull(op.CurrencyRate,1) + isNULL(pvo.SUMVO,0)) * 100 / 107),ISNULL(op.ContractAmount,0)*isnull(op.CurrencyRate,1) + isNULL(pvo.SUMVO,0)) CurrenctContract
			,budget.baseline BaselineBudget2
			,isnull(cost.CommitAmt,0)  + isnull(ta.remainingallo,0) CommittedCost 
			,isnull(ActualAmt,0) + IIF(@checkRemainAllocate = 1,isnull(tact.remain,0),0) ActualCost
			,isnull(PaidAmt,0) + IIF(@checkRemainAllocate = 1,isnull(tact.remain,0),0) PaidCost
			,iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,isnull(budget.ReviseBudget,0))  - (isnull(cost.CommitAmt,0)  + isnull(ta.remainingallo,0)) Forecast
			,iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,isnull(budget.ReviseBudget,0)) CurrenctBudget
			,CASE (ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + isNULL(pvo.SUMVO,0))
				WHEN 0 THEN 0
				ELSE ((ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + ISNULL(pvo.SUMVO,0) - iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,isnull(budget.ReviseBudget,0)) ) /  (ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + isNULL(pvo.SUMVO,0))) * 100
			 END [CurrencyProfit]
			,isnull(pp.WorkProgress,0) ActualProgress

			,Isnull(ISS.Completion,0) * op.CurrencyRate		[Completion] /*MS-28644*/

			,Isnull(IVAR.Invoice,0) * op.CurrencyRate		[Invoice] /*MS-28644*/

			,Isnull(RC.Receipt,0) * op.CurrencyRate			[Receipt] /*MS-28644*/

			,(Isnull(IVAR.Invoice,0) * op.CurrencyRate)-(isnull(ActualAmt,0) + IIF(@checkRemainAllocate = 1,isnull(tact.remain,0),0)) GassProfit

			,oparent.Name Name1
			,oparent.Code Code1
			,ISNULL(commitcost.CommitAmount,0) + IIF(@checkRemainAllocate = 1,ISNULL(ta.remainingallo,0),0) CommittedCost2
			,ISNULL(baseline.Amount,0) [BaselineBudget]
	into #tempbudget
	from Organizations o 
	inner join Organizations_ProjectConstruction op on o.id= op.id

    OUTER APPLY (
        SELECT TaxMethod ,TaxRate FROM InterimPayments
        WHERE OrgId = o.Id
        GROUP BY OrgId,TaxMethod ,TaxRate
    ) ir
	left join Organizations oparent on o.parent = oparent.id 
	left join #tempallo ta on ta.LocationId = o.Id
	left join #tempact tact on tact.OrgId =o.id 
	left hash join ( 
				select 
						b.ProjectId
						,sum(isNUll(bl.amount,0)) Baseline
						,sum(isnull(revise.CompleteAmount,0)) ReviseBudget
						,count(revise.id) ReviseCount
				 from Budgets b
				left join BudgetLines bl on bl.BudgetId = b.Id
				left hash join (	select revise.* from (
											SELECT  rb.RunNumber,
													rb.id,
													isnull(rbl.CompleteAmount, 0) CompleteAmount,
													rb.ProjectId,
													rb.BudgetId,
													rbl.BudgetLineId
											FROM 
											(
												SELECT projectid, MAX(RunNumber) runnumber
												FROM RevisedBudgets 
												where RevisedBudgets.Date <= @Todate
												GROUP BY ProjectId
											) b 
											INNER loop JOIN RevisedBudgets rb ON rb.ProjectId = b.ProjectId AND rb.RunNumber = b.runnumber
											left loop join RevisedBudgetLines rbl on rbl.RevisedBudgetId = rb.Id
											)revise
										 )revise on revise.BudgetLineId = bl.Id

				group by b.ProjectId

				)budget on budget.ProjectId = o.Id
	left hash join (	select SUM(isnull(ContractAmount,0)) SUMVO,
						max(ContractDate) contractdate,
						pv.ProjectConstructionId 
						from ProjectVOes pv
						where ContractDate <= @Todate
						group by pv.ProjectConstructionId
						)pvo on pvo.ProjectConstructionId = o.id
	left hash join (select	sum(c.amount) CommitAmt,
								
								c.OrgId [OrgId],
								sum(acl.AcctAmt) ActualAmt,
								sum(pcl.PaidAmt) PaidAmt

						from CommittedCostLines c
						
						left join (select CommittedCostLineId
										  ,ISNULL(sum(amount),0) AcctAmt 
									from AccountCostLines 
									where Date <= @Todate
									group by CommittedCostLineId )acl on acl.CommittedCostLineId = c.Id							
						left join (select CommittedCostLineId
										  ,ISNULL(sum(amount),0) PaidAmt 
									from PaidCostLines 
									where Date <= @Todate
									group by CommittedCostLineId )pcl on pcl.CommittedCostLineId = c.Id
						
						WHERE c.OrgId IN (SELECT Id FROM #temporg)

						AND c.Date <= @Todate
						
						group by c.OrgId
					)cost on cost.OrgId = o.id
	left hash join (select ProjectId,
					MAX(PlanValuePercent) WorkProgress
					from dbo.ProjectScheduleProgresses
					where EffectiveDate <= @Todate
					 group by ProjectId)pp on pp.ProjectId = o.id


outer apply /*MS-28644*/
(


	select ISNULL(sum (ISS.[Completion]),0)  [Completion]
	from
	(
		select 
		--ISNULL(sum (
			case
				when ir.TaxMethod in (131, 199, 207) then isnull(issl.CostAmount, 0)
				when ir.TaxMethod = 129 then (isnull(issl.LineAmount, 0) * 100.00) / (100.00 + issl.TaxRate)
				else 
				isnull(issl.LineAmount, 0)
			end 
			* 
			iss.DocCurrencyRate
		--),0) 
		[Completion]
		from InspectionSheetLines issl 
		LEFT JOIN dbo.InspectionSheets iss ON iss.Id = issl.InspectionSheetId
		WHERE exists (
			select 1 from InspectionSheets ssd where ssd.OrgId = o.Id and ssd.Id = issl.InspectionSheetId and ssd.DocStatus != -1
		) and issl.SystemCategoryId = 128
	) ISS

)	ISS

outer apply /*MS-28644*/
(
	Select SUM([Invoice]) [Invoice]
	From (
	Select
	ISNULL(SUM(ISNULL(IVARL.CostAmount, 0)), 0) [Invoice]
	From InvoiceARLines IVARL
	Where exists (
		Select 1 From InvoiceARs IVAR Where IVAR.LocationId = o.Id AND IVAR.Id = IVARL.InvoiceARId AND IVAR.DocStatus != -1
	) and IVARL.SystemCategoryId IN (99,128,177)
	UNION ALL
	Select ISNULL(SUM(ISNULL(ORARL.Amount, 0)), 0) [Invoice]
	From OtherReceiveLines ORARL
	Where Exists (
		Select 1 From OtherReceives IVOR Where IVOR.LocationId = o.Id and IVOR.Id = ORARL.OtherReceiveId and IVOR.DocStatus != -1
	) AND (ORARL.OtherReceiveId IN  (Select OtherReceiveId From OtherReceiveLines Where SystemCategoryId IN (44) AND isSet = 1 Group By OtherReceiveId))
	AND ORARL.SystemCategoryId IN (107)
	) IV
) IVAR

outer apply /*MS-28644*/
(
	select sum(rc.[Receipt]) [Receipt]
	from
	(
		select 
		isnull(sum(round((rep_final.ReceiptAmount + rep_final.RetentionSetAmount) - rep_final.Vat - rep_final.CalDeposit_Credit + rep_final.SubDeposit, 2)), 0) [Receipt]
		from (
			select
				rep.ReceiptAmount,
				rep.RetentionSetAmount,
				isnull((rep.RetentionSetAmount + rep.ReceiptAmount) / nullif(rep.ReceiptPerUnitDeposit_Debit, 0), 0) [SubDeposit],
				isnull((rep.ReceiptAmount + rep.RetentionSetAmount) / nullif(rep.ReceiptPerUnitVat, 0), 0) [Vat],
				isnull((rep.ReceiptAmount + rep.RetentionSetAmount) / nullif(rep.ReceiptPerUnitDeposit_Credit, 0), 0) [CalDeposit_Credit]
			from (
				select 
					*,
					isnull(dep.AR / nullif(dep.Deposit_Debit, 0), 0) [ReceiptPerUnitDeposit_Debit],
					isnull(dep.AR / nullif(dep.VatAmount, 0), 0) [ReceiptPerUnitVat],
					isnull(dep.AR / nullif(dep.Deposit_Credit, 0), 0) [ReceiptPerUnitDeposit_Credit]
				from (
						select
							*,
							case ir.TaxMethod 
								when 131 then 0.0
								else ( (inv.InvoiceLine - inv.Discount) - inv.Deposit_Debit ) * (ir.TaxRate / 100.00)
							end [VatAmount],
							((inv.InvoiceLine - inv.Discount) + inv.Deposit_Credit - inv.Deposit_Debit) + 
							( 
							 case ir.TaxMethod 
								when 131 then 0.0
								else ( (inv.InvoiceLine - inv.Discount) - inv.Deposit_Debit ) * (ir.TaxRate / 100.00)
							end
							) [AR]
						from (
							select
								rcl.ReceiptId,
								rcl.DocAmount,
								rcl.ReceiptAmount,
								rcl.RetentionSetAmount,
								rcl.RefIVId 
							from ReceiptLines rcl 
							where rcl.SystemCategoryId = 38

								and exists (
									select 1 from Receipts rc 
										where rc.DocTypeId = 51
											and rc.DocStatus != -1 
											and rc.LocationId = o.Id
											and rc.Id = rcl.ReceiptId
								)
						) rc
						cross apply (
							Select 
								sum(iif(iv.SystemCategoryId = 49, iv.Amount, 0.0)) [ARRetention],
								sum(iif(iv.SystemCategoryId = 107 , iv.Amount, 0.0)) - sum(iif(iv.SystemCategoryId = 55 and iv.isset = 1, iv.Amount, 0.0)) [InvoiceLine],
								sum(iif(iv.SystemCategoryId = 55 and iv.GeneralAccount = 221 and iv.isset = 1, iv.Amount, 0.0)) [Deposit_Credit],
								sum(iif(iv.SystemCategoryId = 55 and iv.GeneralAccount = 221 and iv.isset = 0, iv.Amount, 0.0)) [Deposit_Debit],
								sum(iif(iv.SystemCategoryId = 124, iv.Amount, 0.0)) [Discount]
							from InvoiceARLines iv
								where iv.InvoiceARId = rc.RefIVId and iv.SystemCategoryId in (49, 107, 55)
						) inv
				) dep
			) rep
		) rep_final

		union all 

		select 
			isnull(sum((ISNULL(rcl.TaxBase, 0) + isnull(rcl.SubtractDeposit, 0)) * r.DocCurrencyRate), 0) [Receipt]
		from ReceiptLines rcl
		LEFT JOIN dbo.Receipts r ON rcl.ReceiptId = r.Id
		where rcl.SystemCategoryId in (127, 128,177)
			and exists (
				select 1 from Receipts rc
				where rc.DocTypeId = 151
					and rc.DocStatus != -1
					and rc.LocationId = o.Id
					and rc.Id = rcl.ReceiptId
			)
			AND EXISTS (
				SELECT 1 FROM dbo.InterimPaymentLines ipl WHERE  SystemCategoryId != 55
				AND rcl.InterimPaymentLineId = ipl.Id
			)
		union all 
		-- ***** Receipt From Quotation/Invoice AR ***** ยอดใบเสร็จรับเงินจากใบเสนอราคา ไม่ผ่าน Interim
		select 
			isnull(sum((ISNULL(rcl.TaxBase, 0) + isnull(rcl.SubtractDeposit, 0)) * r.DocCurrencyRate), 0) [Receipt]
		from ReceiptLines rcl
		LEFT JOIN dbo.Receipts r ON rcl.ReceiptId = r.Id
		where rcl.SystemCategoryId in (99)
			and exists (
				select 1 from Receipts rc
				where rc.DocTypeId = 151
					and rc.DocStatus != -1
					and rc.LocationId = o.Id
					and rc.Id = rcl.ReceiptId
			)
		 union all
		 -- ***** Receipt From Quotation/OtherReceive ***** ยอดใบเสร็จรับเงินจากใบเสนอราคา ไม่ผ่าน Interim
		
		 Select		SUM(rl.ReceiptAmount)-SUM(orl.TaxAmount) [Receipt]
		 From		Receiptlines rl
		 LEFT JOIN	dbo.Receipts r ON rl.ReceiptId = r.Id
		 LEFT JOIN	(Select SUM(IIF(SystemCategoryId = 36,TaxAmount*-1,TaxAmount)) TaxAmount,OtherReceiveId From OtherReceivelines Where SystemCategoryId IN (36,123,129) Group By OtherReceiveId) orl ON orl.OtherReceiveId = r.TaxItemId AND r.DocTypeId IN (44)
		 Where		rl.SystemCategoryId IN (111) AND r.LocationId = o.Id AND r.DocStatus != -1
	) RC

) RC

	LEFT HASH JOIN (
	SELECT	 IV.LocationId
				,SUM(ISNULL(IV.ARNOVAT,0)) [ARNOVAT]
		FROM (	SELECT	 a.LocationId
						,a.Id InvoiceARId
						,SUM(ISNULL(gtt.Amount,0)+ISNULL(pen.Amount,0)-ISNULL(vat.TaxAmount,0)) *a.DocCurrencyRate [ARNOVAT]
				FROM	dbo.InvoiceARs	a
				LEFT JOIN ( SELECT InvoiceARId,Amount FROM dbo.InvoiceARLines WHERE SystemCategoryId IN (111))gtt ON gtt.InvoiceARId=a.Id
				LEFT JOIN ( SELECT InvoiceARId,TaxAmount FROM dbo.InvoiceARLines WHERE SystemCategoryId IN (123,131,129,199))vat ON vat.InvoiceARId=a.Id
				LEFT JOIN ( SELECT InvoiceARId,Amount FROM dbo.InvoiceARLines WHERE SystemCategoryId IN (148))pen ON pen.InvoiceARId=a.Id
				WHERE	a.DocStatus NOT IN (-1,-11)
				AND a.Date <= @Todate
				AND a.SystemCategoryId IN (128)
				GROUP BY a.LocationId,a.Id,a.DocCurrencyRate
		) IV
		GROUP BY IV.LocationId
	) inv ON inv.LocationId = o.Id
	outer apply (
		select 
			case ip.TaxMethod
				when 131 then SUM(ISNULL(rl.ReceiptAmount,0) + ISNULL(rl.SubtractRetention, 0) * rl.RefIVCurrencyRate)
				else sum((((isnull(rl.ReceiptAmount, 0) + Isnull(rl.SubtractRetention, 0)) * 100.00 ) / (100.00 + isnull(ip.TaxRate, 7))) * rl.RefIVCurrencyRate)
			end [Receipt]
		from ReceiptLines rl
		inner join Receipts r on r.Id = rl.ReceiptId
		inner join InterimPayments [ip] on ip.OrgId = rl.LocationId
		where rl.ReceiptId = r.Id 
			and r.DocStatus not in (-1, 11)
			and r.Date <= @ToDate
			and rl.LocationId = o.Id
		group by ip.TaxMethod
	) r
	LEFT hash JOIN (
			SELECT  SUM(ISNULL(cost.cAmount,0)) CommitAmount , o.Id
			FROM Organizations o
			LEFT loop join Budgets b on b.ProjectId = o.id 
			LEFT loop join WBS on wbs.BudgetId = b.Id
			LEFT hash join (select SUM(cm.Amount) cAmount,cm.WBSId 
							FROM CommittedCostLines  cm
							LEFT hash JOIN (select sum(amount)acamount ,CommittedCostLineId from AccountCostLines where date<=@Todate group by CommittedCostLineId )ac on ac.CommittedCostLineId =cm.id
							LEFT hash JOIN (select sum(amount)pamount ,CommittedCostLineId from PaidCostLines where date<=@Todate group by CommittedCostLineId )pd on pd.CommittedCostLineId =cm.id
							WHERE cm.date <= @Todate 
							AND (@exists = 0 OR EXISTS (select id from #temporg [test] WHERE test.Id = cm.OrgId ))
			GROUP by cm.wbsid
		)cost on cost.WBSId = wbs.id
		WHERE (@exists = 0 or EXISTS (select id from #temporg [test] WHERE test.Id = o.Id))
		GROUP BY o.Id
	) commitcost ON commitcost.Id = o.Id
	LEFT hash JOIN  (
		SELECT SUM(ISNULL(CompleteAmount,0)) Amount , rb.ProjectId
		FROM dbo.RevisedBudgetLines rbl
		INNER JOIN dbo.RevisedBudgets rb ON rbl.RevisedBudgetId = rb.Id 
		WHERE rb.RevisedBudgetType = 0
		GROUP BY rb.ProjectId
	) baseline ON baseline.ProjectId = budget.ProjectId
	where o.parent != 1
	AND o.OrgCategory IN (80,85,86,87,196,197)
    and (o.Id in (select id from #temporg) or (len(isnull(@projectCode,'')) = 0) AND isnull(@projectCode,'') = '')
	AND ((op.ContractDate BETWEEN @ToContractDate AND @EndContractDate) OR (@ToContractDate = '1900-01-01' AND @EndContractDate = '1900-01-01'))
	AND ((FinancialStatus IN (SELECT * FROM dbo.fn_listCode(@FinancialStatus))) OR @FinancialStatus IS NULL )
	AND ((ConstructionStatus IN (SELECT * FROM dbo.fn_listCode(@ConstructionStatus))) OR @ConstructionStatus IS NULL )
	AND ((ContractStatus IN (SELECT * FROM dbo.fn_listCode(@ProgressStatus))) OR @ProgressStatus IS NULL)
    AND ((exists (SELECT 1 FROM #TempRoleOrg rsd WHERE (rsd.AllOrg = 1 OR rsd.OrgId = @projectCode))) OR @isPowerUser = 1) --Add view report condition depends on User role for view org
	order by parent
option(recompile)

if(isnull( @projectCode,'')  != '' or isnull( @SearchprojectCode,'')  !='')
begin

	select 

	tb.*

	,tp.grouppercent
	,orgGroup.Code code2
	,orgGroup.name name2
    ,cd.[Description] ContractStatus
    ,p.Name [Project Manager]

	 from 
	 #tempGroup tg
	 outer apply
	 (
		 select 
		 tb.*
		 from #tempbudget tb
		 where tb.path like concat('%|' , tg.Id , '|%')
	 )tb
	 outer apply
	 (
		 select 
		 ((Sum([CurrenctContract])-Sum([CurrenctBudget])) / nullif(Sum([CurrenctContract]),0.00)) * 100.00 grouppercent
		 from #tempbudget tb
		 where tb.path like concat('%|' , tg.Id , '|%')
	 )tp
	 left join Organizations orgGroup on tg.Id = orgGroup.Id
     LEFT JOIN (Select OrgId,dbo.GROUP_CONCAT_D(Name,' ,') Name From Persons Group By OrgId) p ON tb.Id = p.OrgId
     LEFt JOIN Organizations_ProjectConstruction op ON tb.Id = op.Id
     LEFT JOIN CodeDescriptions cd ON op.ContractStatus = cd.[Value] WHERE cd.Name = 'ContractStatus'

	order by tb.Code--tb.path
	option(recompile)

end
else
begin

	select tb.*
	,t.grouppercent
	,h.Code code2
	,h.name name2
    ,cd.[Description] ContractStatus
    ,p.Name [Project Manager]
	 from #tempbudget tb
	left join 
	( select name1,code1,((Sum([CurrenctContract])-Sum([CurrenctBudget])) / nullif(Sum([CurrenctContract]),0))*100 grouppercent from  
		#tempbudget t 
		group by name1,code1
	)t on t.Name1 = tb.Name1 and t.Code1 = tb.Code1
	left join Organizations o on o.id = tb.id
	left join Organizations h on o.UnderTaxEntityId = h.id
     LEFT JOIN (Select OrgId,dbo.GROUP_CONCAT_D(Name,' ,') Name From Persons Group By OrgId) p ON tb.Id = p.OrgId
     LEFt JOIN Organizations_ProjectConstruction op ON tb.Id = op.Id
     LEFT JOIN CodeDescriptions cd ON op.ContractStatus = cd.[Value] WHERE cd.Name = 'ContractStatus'

	order by tb.Code--tb.path --tb.opa,tb.Parent,
	option(recompile)

end


select 
@ToDate Date,
@projectCode ProjectCode,
@SearchprojectCode SearchProjectCode

IF OBJECT_ID(N'tempdb..#temporg', N'U') IS NOT NULL
    BEGIN;
        DROP TABLE #temporg;
    END;
IF	OBJECT_ID('tempdb..#tempallo') IS NOT NULL
BEGIN													   
	DROP TABLE #tempallo

END

IF	OBJECT_ID('tempdb..#tempact') IS NOT NULL
BEGIN													   
	DROP TABLE #tempact

END
IF	OBJECT_ID('tempdb..#tempbudget') IS NOT NULL
BEGIN													   
	DROP TABLE #tempbudget

END

/*3-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT * FROM fn_CompanyInfoTable(@projectCode )