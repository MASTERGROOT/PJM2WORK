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

--  DECLARE @p0 DATETIME = '2024-12-18'
--  declare @p1 nvarchar(500) = '4'--'1931'--'1107,1152' --''--
--  DECLARE @p2 BIT = 1
--  DECLARE @p3 DATETIME = ''
--  DECLARE @p4 DATETIME = ''

--  DECLARE @p5  nvarchar(500) = null
--  DECLARE @p6 nvarchar(500) = null
--  DECLARE @p7 nvarchar(500) = null
--  DECLARE @p8 nvarchar(100) = null

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

Declare @ga NVARCHAR(max) = ''

	Select @ga += CONCAT(GeneralAccount,',') From dbo.ChartOfAccounts  Where Path like '|224|%'

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

-- Declare @tmpProject NVARCHAR(MAX)

-- Select @tmpProject = dbo.GROUP_CONCAT(DISTINCT Id)
-- From #temporg

-- DECLARE @exists bit  = 0
-- IF EXISTS(Select 1 From #temporg)
-- BEGIN
-- 	SET @exists = 1
-- END 

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

/*##### ส่วนคิด Remaining #####*/

CREATE TABLE #tempallo (   LocationId INT, remainingallo decimal(21,6) )
CREATE TABLE #tempact (   OrgId INT, remain decimal(21,6) )

/*##### Doc Commit Detail #####*/
insert Into #tempallo
EXEC	[dbo].[sp_ManeeSystemCoreRemainingCommitBudgetRptManyProject] 
		@Todate = @Todate,
		@OrgId = @tmpProject;

/*##### Doc Account Detail #####*/
insert Into #tempact
EXEC	[dbo].[sp_ManeeSystemCoreRemainingAccountBudgetRptManyProject]
		@Todate = @Todate,
		@OrgId = @tmpProject

IF OBJECT_ID('tempdb..#cte_JV') IS NOT NULL
    BEGIN
        DROP TABLE #cte_JV;
END;

Select	j.Id JVId,s.JVLineId,j.Code JVCode,s.DocId,s.DocCode,s.DocDate,s.DocTypeId,s.OrgId ,s.OrgCode, s.OrgName,s.ExtOrgCode,s.ExtOrgName
		,s.Amount,IIF(j.CreateBy = 'Pojjaman2 API','Zip Event',j.CreateBy) CreateBy,j.DocStatus
Into #cte_JV
From AcctElementSets s
Left Join	JournalVouchers j ON s.DocId = j.MadeByDocId AND s.DocTypeId = j.MadeByTypeId 
Where	(s.GeneralAccount IN (Select ncode From dbo.fn_listCode(@ga)))
		AND j.DocStatus != -1 AND s.OrgId IN (Select Id From #temporg)

IF  OBJECT_ID(N'tempdb..#RECEIPT') IS NOT NULL	
    BEGIN
            DROP TABLE #RECEIPT
    END
			
			Select	x.OrgId ,x.OrgCode, x.OrgName
					, SUM(x.SetAmount) Revenue, SUM(x.Amount) Receipt
					, SUM(x.RemainAmount) RemainAmount
					, SUM(IIF(x.ClearAmount > x.Amount AND x.SetAmount !=0,x.Amount,x.ClearAmount)) ClearAmount
			Into	#RECEIPT		
			From (
			Select   
					j.DocCode, j.DocDate, o.Code OrgCode, o.Id OrgId ,o.Name OrgName, j.ExtOrgCode, j.ExtOrgName,j.CreateBy
					, dc.DocTypeCode DocType,j.DocStatus
					, SUM(j.Amount) Amount, 'รายได้' [Group], 1 SortNumber, vl.DocId,vl.DocTypeId,vl.SpecialDiscount,vl.DepositAmt,vl.RetentionAmt
					, IIF(vl.SetAmount = 0,j.Amount,vl.SetAmount) SetAmount,vl.RemainAmount
					, SUM(IIF(vl.SetAmount = 0 AND vl.ClearAmount = 0,j.Amount,vl.ClearAmount)) ClearAmount
			
			From    #cte_JV j
					Left hash Join dbo.DocTypeCodeList() dc ON dc.DocTypeId = j.DocTypeId
					Left hash Join dbo.Organizations o ON o.id = j.OrgId
					INNER hash join (
									  Select  jv.DocId,jv.DocTypeId,jv.JVLineId 
											 ,IIF(jv.DocStatus = -1,0,ISNULL(ds.Amount,0)) SpecialDiscount
											  ,IIF(jv.DocStatus = -1,0,ISNULL(de.DepositAmt,0))  DepositAmt
											  ,IIF(jv.DocStatus = -1,0,ISNULL(rt.Amount,0))  RetentionAmt
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.SetARAmount - vat.SetVATAmount,0)) SetAmount
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.ARRemain - vat.VATRemain,0)) RemainAmount
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.ClearARAmount - vat.ClearVATAmount,0)) ClearAmount
									  From	   #cte_JV jv  WITH (NOLOCK)
											   LEFT JOIN dbo.InvoiceARs i on jv.DocId = i.Id and jv.DocTypeId = 38 /* เปลี่ยน inner join --> left join */
											   LEFT JOIN dbo.InvoiceARLines ds WITH (NOLOCK) on ds.InvoiceARId = i.Id and ds.SystemCategoryId = 124
											   Outer Apply (
															Select	il.InvoiceARId,SUM(il.TaxBase)Depositamt
															From	dbo.InvoiceARLines il WITH (NOLOCK)
															Where   il.SystemCategoryId = 55
																	AND ISNULL(il.DocQty,0) = 0
																	AND il.InvoiceARId = i.Id
																	Group By il.InvoiceARId
																	) de
											   left  join dbo.InvoiceARLines rt WITH (NOLOCK) on rt.InvoiceARId = i.Id and rt.SystemCategoryId = 49
                                               Outer Apply (
                                                            Select aes.Amount SetARAmount, aesr.RemainAmount ARRemain, aec.Amount ClearARAmount
                                                            From AcctElementSets aes 
                                                            INNER JOIN AcctElementSets_RemainAcctElement aesr ON aes.Id = aesr.Id
                                                            LEFT JOIN AcctElementClears aec ON aesr.Id = aec.SetId
                                                            Where aes.GeneralAccount = 111 AND aes.DocId = jv.DocId AND aes.DocTypeId = jv.DocTypeId
                                               ) ar /* เพิ่ม set amount, remain amount, clear amount ของบรรทัดใบเเจ้งหนี้ที่ GA เป็น AR*/
                                               Outer Apply (
                                                            Select aes.Amount SetVATAmount, aesr.RemainAmount VATRemain, aec.Amount ClearVATAmount
                                                            From AcctElementSets aes 
                                                            INNER JOIN AcctElementSets_RemainAcctElement aesr ON aes.Id = aesr.Id
                                                            LEFT JOIN AcctElementClears aec ON aesr.Id = aec.SetId
                                                            Where aes.GeneralAccount = 293 AND aes.DocId = jv.DocId AND aes.DocTypeId = jv.DocTypeId
                                               ) vat /* เพิ่ม set amount, remain amount, clear amount ของบรรทัดใบเเจ้งหนี้ที่ GA เป็น VAT*/
									) vl ON vl.DocId = j.DocId AND vl.DocTypeId = j.DocTypeId AND vl.JVLineId = j.JVLineId
					Left hash Join dbo.SitePathList() sp on j.DocTypeId = sp.DocTypeId
					Group By	j.DocCode, j.DocDate, o.Id , o.Code ,o.Name, j.ExtOrgCode, j.ExtOrgName,j.CreateBy
								, dc.DocTypeCode ,j.DocStatus
								, vl.DocId,vl.DocTypeId,vl.SpecialDiscount,vl.DepositAmt,vl.RetentionAmt
								, IIF(vl.SetAmount = 0,j.Amount,vl.SetAmount),vl.RemainAmount
					
					) x 
					Where		x.OrgId IN (Select Id From #temporg)
					Group By	x.OrgId, x.OrgCode, x.OrgName

	/*##### Show Data #####*/
	Select  o.id,
			o.level-4 level,
			o.name,
			o.Code,
			o.Parent,
			iif(o.level >= 4 ,o.parent,oparent.parent) opa 
			,iif(o.level >= 4 ,o.code,oparent.code) oparentcode
			,o.path path
			,IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1)) * 100 / 107),ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1)) ContractAmount
			,IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)) * 100 / 107),ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)) CurrenctContract
			,budget.baseline BaselineBudget2
			,ISNULL(cost.CommitAmt,0)  + ISNULL(ta.remainingallo,0) CommittedCost 
			,ISNULL(ActualAmt,0) + IIF(@checkRemainAllocate = 1,ISNULL(tact.remain,0),0) ActualCost
			,ISNULL(PaidAmt,0) + IIF(@checkRemainAllocate = 1,ISNULL(tact.remain,0),0) PaidCost
			,iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,ISNULL(budget.ReviseBudget,0))  - (ISNULL(cost.CommitAmt,0)  + ISNULL(ta.remainingallo,0)) Forecast
			,iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,ISNULL(budget.ReviseBudget,0)) CurrenctBudget
			,CASE (ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + ISNULL(pvo.SUMVO,0))
				WHEN 0 THEN 0
				ELSE ((ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + ISNULL(pvo.SUMVO,0) - iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,ISNULL(budget.ReviseBudget,0)) ) /  (ISNULL(op.ContractAmount,0) * ISNULL(op.CurrencyRate,0) + ISNULL(pvo.SUMVO,0))) * 100
			 END [CurrencyProfit]
			,ISNULL(pp.WorkProgress,0) ActualProgress

			,ISNULL(ISS.Completion,0) * op.CurrencyRate		[Completion] /*MS-28644*/
			,ISNULL(IVAR.Invoice,0) * op.CurrencyRate InvoicrAROnly
			,IIF((ISNULL(RC.Receipt,0) * op.CurrencyRate)<(ISNULL(IVAR.Invoice,0) * op.CurrencyRate),ISNULL(IVAR.Invoice,0) * op.CurrencyRate,ISNULL(RC.Receipt,0) * op.CurrencyRate)[Invoice]

			,ISNULL(RC.Receipt,0) * op.CurrencyRate			[Receipt] /*MS-28644*/

			,(IIF((ISNULL(RC.Receipt,0) * op.CurrencyRate)<(ISNULL(IVAR.Invoice,0) * op.CurrencyRate),ISNULL(IVAR.Invoice,0) * op.CurrencyRate,ISNULL(RC.Receipt,0) * op.CurrencyRate))-(ISNULL(ActualAmt,0) + IIF(@checkRemainAllocate = 1,ISNULL(tact.remain,0),0)) GassProfit
			,IIF((ISNULL(IVAR.Invoice,0) * op.CurrencyRate) = 0,0,
			((IIF((ISNULL(RC.Receipt,0) * op.CurrencyRate)<(ISNULL(IVAR.Invoice,0) * op.CurrencyRate),ISNULL(IVAR.Invoice,0) * op.CurrencyRate,ISNULL(RC.Receipt,0) * op.CurrencyRate)-(ISNULL(ActualAmt,0) + IIF(@checkRemainAllocate = 1,ISNULL(tact.remain,0),0)))*100)
			/(IIF((ISNULL(RC.Receipt,0) * op.CurrencyRate)<(ISNULL(IVAR.Invoice,0) * op.CurrencyRate),ISNULL(IVAR.Invoice,0) * op.CurrencyRate,ISNULL(RC.Receipt,0) * op.CurrencyRate))
			) [%GassProfit]
			,IIF((IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)) * 100 / 107),ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0))) = 0,0,
			((IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)) * 100 / 107),ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0))-iif(budget.ReviseCount = 0 ,ISNULL(baseline.Amount,0) ,ISNULL(budget.ReviseBudget,0)))*100)
			/(IIF(coalesce(ir.TaxMethod, op.TaxType ) = 129,((ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)) * 100 / 107),ISNULL(op.ContractAmount,0)*ISNULL(op.CurrencyRate,1) + ISNULL(pvo.SUMVO,0)))
			) [%ExpectedGassProfit]
			,oparent.Name Name1
			,oparent.Code Code1
			,CONCAT(oparent.Code,' : ',oparent.Name) ParentCode
			,CONCAT(g.Code,' : ',g.Name) GroupProject
			--,Format(Convert(date,Right(oparent.Name,4),103),'yyyy') ProjectYear
			,Format(ISNULL(CONVERT(datetime,py.DataValues,105),op.StartDate),'yyyy') ProjectYear
			,ISNULL(commitcost.CommitAmount,0) + IIF(@checkRemainAllocate = 1,ISNULL(ta.remainingallo,0),0) CommittedCost2
			,ISNULL(baseline.Amount,0) [BaselineBudget]
			,cns.Description ConstructionStatus
			,cts.Description ContractStatus
			,fs.Description FinancialStatus
			,p.Name PMName
			,CONCAT(o.Code,' : ',o.Name) ProjectCodeandName
			,ext.Id ExtOrgId,ext.Code ExtOrgCode,ext.Name ExtOrgName
			
	Into #tempbudget
	From Organizations o 
	inner join Organizations_ProjectConstruction op on o.id= op.id
	Left Join CustomNoteLines py ON py.DocGuid = o.guid AND py.KeyName = 'p.EventDate'
	Left Join ExtOrganizations ext ON ext.Id = op.ExtOrgId
	Left Join CodeDescriptions cns ON cns.Name = 'ConstructionStatus' AND cns.Value = op.ConstructionStatus
	Left Join CodeDescriptions cts ON cts.Name = 'ContractStatus' AND cts.Value = op.ContractStatus
	Left Join CodeDescriptions fs ON fs.Name = 'FinancialStatus' AND fs.Value = op.FinancialStatus
	----------PM Manager--------------
	Left Join (		Select	--min(PersonId) PersonId,
							dbo.GROUP_CONCAT_D(DISTINCT Name,',') Name,
							--Username,
							OrgId 
					From Persons 
					Where SystemCode ='PersonInChange'
					Group By OrgId
				) [p] ON [p].OrgId = o.Id
    Outer Apply (
        Select TaxMethod ,TaxRate From InterimPayments
        Where OrgId = o.Id
        Group By OrgId,TaxMethod ,TaxRate
    ) ir
	left join Organizations oparent on o.parent = oparent.id 
	left join Organizations g ON g.Id = oparent.Parent
	left join #tempallo ta on ta.LocationId = o.Id
	left join #tempact tact on tact.OrgId =o.id 
	Left hash Join ( 
				Select 
						b.ProjectId
						,SUM(ISNULL(bl.amount,0)) Baseline
						,SUM(ISNULL(revise.CompleteAmount,0)) ReviseBudget
						,count(revise.id) ReviseCount
				 From Budgets b
				left join BudgetLines bl on bl.BudgetId = b.Id
				Left hash Join (	Select revise.* From (
											Select  rb.RunNumber,
													rb.id,
													ISNULL(rbl.CompleteAmount, 0) CompleteAmount,
													rb.ProjectId,
													rb.BudgetId,
													rbl.BudgetLineId
											From 
											(
												Select projectid, MAX(RunNumber) runnumber
												From RevisedBudgets 
												Where RevisedBudgets.Date <= @Todate
												Group By ProjectId
											) b 
											INNER loop JOIN RevisedBudgets rb ON rb.ProjectId = b.ProjectId AND rb.RunNumber = b.runnumber
											left loop join RevisedBudgetLines rbl on rbl.RevisedBudgetId = rb.Id
											)revise
										 )revise on revise.BudgetLineId = bl.Id

				Group By b.ProjectId

				)budget on budget.ProjectId = o.Id
	Left hash Join (	Select SUM(ISNULL(ContractAmount,0)) SUMVO,
						max(ContractDate) contractdate,
						pv.ProjectConstructionId 
						From ProjectVOes pv
						Where ContractDate <= @Todate
						Group By pv.ProjectConstructionId
						)pvo on pvo.ProjectConstructionId = o.id
	Left hash Join (Select	SUM(c.amount) CommitAmt,
								
								c.OrgId [OrgId],
								SUM(acl.AcctAmt) ActualAmt,
								SUM(pcl.PaidAmt) PaidAmt

						From CommittedCostLines c
						
						left join (Select CommittedCostLineId
										  ,ISNULL(SUM(amount),0) AcctAmt 
									From AccountCostLines 
									Where Date <= @Todate
									Group By CommittedCostLineId )acl on acl.CommittedCostLineId = c.Id							
						left join (Select CommittedCostLineId
										  ,ISNULL(SUM(amount),0) PaidAmt 
									From PaidCostLines 
									Where Date <= @Todate
									Group By CommittedCostLineId )pcl on pcl.CommittedCostLineId = c.Id
						
						Where c.OrgId IN (Select Id From #temporg)

						AND c.Date <= @Todate
						
						Group By c.OrgId
					)cost on cost.OrgId = o.id
	Left hash Join (Select ProjectId,
					MAX(PlanValuePercent) WorkProgress
					From dbo.ProjectScheduleProgresses
					Where EffectiveDate <= @Todate
					 Group By ProjectId)pp on pp.ProjectId = o.id


Outer Apply /*MS-28644*/
(


	Select ISNULL(SUM (ISS.[Completion]),0)  [Completion]
	From
	(
		Select 
		--ISNULL(SUM (
			case
				when ir.TaxMethod in (131, 199, 207) then ISNULL(issl.CostAmount, 0)
				when ir.TaxMethod = 129 then (ISNULL(issl.LineAmount, 0) * 100.00) / (100.00 + issl.TaxRate)
				else 
				ISNULL(issl.LineAmount, 0)
			end 
			* 
			iss.DocCurrencyRate
		--),0) 
		[Completion]
		From InspectionSheetLines issl 
		LEFT JOIN dbo.InspectionSheets iss ON iss.Id = issl.InspectionSheetId
		Where exists (
			Select 1 From InspectionSheets ssd Where ssd.OrgId = o.Id and ssd.Id = issl.InspectionSheetId and ssd.DocStatus != -1
		) and issl.SystemCategoryId = 128
	) ISS

)	ISS
Left hash Join (Select OrgId,OrgCode,OrgName,Receipt From #RECEIPT) RC ON RC.OrgId = o.Id

Outer Apply
(	Select SUM([Invoice]) [Invoice]
	From (
	Select
	SUM(ISNULL(IVARL.CostAmount, 0)) [Invoice]
	From InvoiceARLines IVARL
	Inner Join InvoiceARs IVAR ON IVAR.id = IVARL.InvoiceARId
	Where exists (
		Select 1 From InvoiceARs IVAR Where IVAR.LocationId = o.Id AND IVAR.Id = IVARL.InvoiceARId AND IVAR.DocStatus != -1
	) and IVARL.SystemCategoryId IN (99,128,177)
	UNION ALL
	Select SUM(ISNULL(ISNULL(ORARL.TaxBase,ORAL.Amount), 0)) [Invoice]
	From OtherReceiveLines ORARL
	Inner Join OtherReceives ORAR ON ORAR.Id = ORARL.OtherReceiveId
	Left Join OtherReceiveLines ORAL ON ORAL.OtherReceiveId = ORAR.Id AND ORAL.SystemCategoryId IN (107)
	Where Exists (
		Select 1 From OtherReceives IVOR Where IVOR.LocationId = o.Id and IVOR.Id = ORARL.OtherReceiveId and IVOR.DocStatus != -1
	) AND (ORARL.OtherReceiveId IN  (Select OtherReceiveId From OtherReceiveLines Where SystemCategoryId IN (44) AND isSet = 1 Group By OtherReceiveId))
	AND ORARL.SystemCategoryId IN (123,129,131)
	------------------ Adjust Invoice AR ---------------------
	UNION ALL
	--Select ISNULL(SUM(ISNULL(adjl.AdjustTaxBase, 0)),0)*-1 [Invoice]
	--From AdjustInvoiceARLines adjl
	--Left Join AdjustInvoiceARs adj ON adj.Id = adjl.AdjustInvoiceARId
	--Where adjl.SystemCategoryId IN (152) AND adjl.AdjustInvoiceARId = 1 AND adj.DocStatus != -1 AND adjl.OrgId = o.Id
	Select SUM(ISNULL(adjl.AdjustTaxBase, 0)*-1) [Invoice]
	From AdjustInvoiceARLines adjl
	Inner Join AdjustInvoiceARs adj ON adj.Id = adjl.AdjustInvoiceARId
	Where adjl.SystemCategoryId IN (152,153) AND adj.DocStatus != -1 AND adjl.OrgId = o.Id
	) IV
) IVAR 
Left hash Join (
	Select	 IV.LocationId
				,SUM(ISNULL(IV.ARNOVAT,0)) [ARNOVAT]
		From (	Select	 a.LocationId
						,a.Id InvoiceARId
						,SUM(ISNULL(gtt.Amount,0)+ISNULL(pen.Amount,0)-ISNULL(vat.TaxAmount,0)) *a.DocCurrencyRate [ARNOVAT]
				From	dbo.InvoiceARs	a
				LEFT JOIN ( Select InvoiceARId,Amount From dbo.InvoiceARLines Where SystemCategoryId IN (111))gtt ON gtt.InvoiceARId=a.Id
				LEFT JOIN ( Select InvoiceARId,TaxAmount From dbo.InvoiceARLines Where SystemCategoryId IN (123,131,129,199))vat ON vat.InvoiceARId=a.Id
				LEFT JOIN ( Select InvoiceARId,Amount From dbo.InvoiceARLines Where SystemCategoryId IN (148))pen ON pen.InvoiceARId=a.Id
				Where	a.DocStatus NOT IN (-1,-11)
				AND a.Date <= @Todate
				AND a.SystemCategoryId IN (128)
				Group By a.LocationId,a.Id,a.DocCurrencyRate
		) IV
		Group By IV.LocationId
	) inv ON inv.LocationId = o.Id
	Outer Apply (
		Select 
			case ip.TaxMethod
				when 131 then SUM(ISNULL(rl.ReceiptAmount,0) + ISNULL(rl.SubtractRetention, 0) * rl.RefIVCurrencyRate)
				else SUM((((ISNULL(rl.ReceiptAmount, 0) + ISNULL(rl.SubtractRetention, 0)) * 100.00 ) / (100.00 + ISNULL(ip.TaxRate, 7))) * rl.RefIVCurrencyRate)
			end [Receipt]
		From ReceiptLines rl
		inner join Receipts r on r.Id = rl.ReceiptId
		inner join InterimPayments [ip] on ip.OrgId = rl.LocationId
		Where rl.ReceiptId = r.Id 
			and r.DocStatus not in (-1, 11)
			and r.Date <= @ToDate
			and rl.LocationId = o.Id
		Group By ip.TaxMethod
	) r
	Left hash Join (
			Select  SUM(ISNULL(cost.cAmount,0)) CommitAmount , o.Id
			From Organizations o
			LEFT loop join Budgets b on b.ProjectId = o.id 
			LEFT loop join WBS on wbs.BudgetId = b.Id
			Left hash Join (Select SUM(cm.Amount) cAmount,cm.WBSId 
							From CommittedCostLines  cm
							Left hash Join (Select SUM(amount)acamount ,CommittedCostLineId From AccountCostLines Where date<=@Todate Group By CommittedCostLineId )ac on ac.CommittedCostLineId =cm.id
							Left hash Join (Select SUM(amount)pamount ,CommittedCostLineId From PaidCostLines Where date<=@Todate Group By CommittedCostLineId )pd on pd.CommittedCostLineId =cm.id
							Where cm.date <= @Todate 
							AND (@exists = 0 OR EXISTS (Select id From #temporg [test] Where test.Id = cm.OrgId ))
			Group By cm.wbsid
		)cost on cost.WBSId = wbs.id
		Where (@exists = 0 or EXISTS (Select id From #temporg [test] Where test.Id = o.Id))
		Group By o.Id
	) commitcost ON commitcost.Id = o.Id
	Left hash Join  (
		Select SUM(ISNULL(CompleteAmount,0)) Amount , rb.ProjectId
		From dbo.RevisedBudgetLines rbl
		INNER JOIN dbo.RevisedBudgets rb ON rbl.RevisedBudgetId = rb.Id 
		Where rb.RevisedBudgetType = 0
		Group By rb.ProjectId
	) baseline ON baseline.ProjectId = budget.ProjectId
	Where	o.Id IN (Select Id From #temporg)
	Order By parent



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