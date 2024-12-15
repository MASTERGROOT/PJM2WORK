/*==> Ref:d:\site\erppro\notpublish\customprinting\reportcommands\mp101_quotationandvo_report.sql ==>*/
 
DECLARE @p0 DATE = '2009-09-30'; --'1900-01-01'; 
DECLARE @p1 DATE = '2024-09-30'; --'1900-01-01'; 
DECLARE @p2 NVARCHAR(MAX) = 200
DECLARE @p3 BIT = 0;  --เพิ่ม Include 
DECLARE @p4 NVARCHAR(MAX) = NULL;
DECLARE @p5 INT = NULL;
DECLARE @p6 NVARCHAR(100) = 'QuotationDate'; /*QuotationDate,QuotationCode*/
DECLARE @p7 NVARCHAR(100) = NULL--'QTVOCA0036606-'; --เพิ่ม Filter like @QuotationCode
DECLARE @p8 NVARCHAR(100) = NULL;
DECLARE @p9 NVARCHAR(100) = null; --เพิ่ม Filter like CreateBy
DECLARE @p10 BIT = 0;
DECLARE @p11 DATE = '1900-01-01'; 
DECLARE @p12 DATE = '1900-01-01'; 
DECLARE @p13 BIT = 0	/*เพิ่ม Filter @Approve*/
DECLARE @p14 BIT = 0	/*เพิ่ม Filter @NotApprove*/
DECLARE @p15 NVARCHAR(20) = 'Not Equal To 0'; /*เพิ่ม Filter @BudgetAmount*/ /* ALL, Equal To 0, Not Equal To 0 */

DECLARE @FromDate DATE  = @p0
DECLARE @Todate DATE  = @p1
DECLARE @ProjectId  NVARCHAR(MAX)  = @p2
DECLARE @incChild BIT =  @p3
DECLARE @CustomerId NVARCHAR(MAX)  = @p4
DECLARE	@QuotationStatus INT	= @p5;
DECLARE	@SortBy		NVARCHAR(100)	= @p6;
DECLARE @QuotationCode NVARCHAR(100)  = nullif(@p7,''); --เพิ่ม Filter like @QuotationCode
DECLARE	@DocStatus	NVARCHAR(MAX)	= @p8;
DECLARE @CreateBy NVARCHAR(100) = @p9; --เพิ่ม Filter like CreateBy
DECLARE @Expend BIT =  @p10
DECLARE @ApproveFromDate DATE  = @p11	--'1900-01-01'; 
DECLARE @ApproveTodate DATE  = @p12		--'1900-01-01'; 
DECLARE @Approve BIT = @p13 			/*เพิ่ม Filter @Approve*/
DECLARE @NotApprove BIT = @p14			/*เพิ่ม Filter @NotApprove*/
DECLARE @BudgetAmount NVARCHAR(20) = @p15; /*เพิ่ม Filter @BudgetAmount*/
/******************************************************************Include child******************************************************************************************/
DECLARE @OrgId TABLE (Id int not null);

INSERT INTO @OrgId(Id)     /*Save More OrgId Or Single OrgId Not Include Child to Temp.*/
            
            SELECT   distinct orgD.ChildrenId       
            FROM   dbo.fn_organizationDepends() orgD
			where (@incChild = 1 and orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)))
			or (isnull(@incChild,0) = 0 and  orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)) and orgD.OrgId = orgD.ChildrenId)
            

/************************************************************************************************************************************************************************/


IF OBJECT_ID(N'tempdb..#tempBudget', N'U') IS NOT NULL
BEGIN;
    DROP TABLE #tempBudget;
END;

/*#tempBudget*/
create  TABLE #tempBudget
		(
		Id				int,
		Code			nvarchar(300),
		BudgetId		int,
		RevisedBudgetId	int,
		BudgetLineId	int,
		CompleteAmount	decimal(21,6),
		VoRemark		nvarchar(MAX)
		)
insert into #tempBudget 
		(
		Id
		,Code
		,BudgetId
		,RevisedBudgetId
		,BudgetLineId
		,CompleteAmount
		,VoRemark
		)		
select id,Code,BudgetId,RevisedBudgetId,BudgetLineId,CompleteAmount,VoRemark
from (
	  select rbl.Id
			,rb.Code
			,rb.BudgetId
			,rbl.RevisedBudgetId
			,rbl.BudgetLineId
			,rbl.CompleteAmount
			,substring(rbl.Remarks,0, charindex('|',rbl.Remarks)) [VORemark]
				 from RevisedBudgetLines rbl
				 left join RevisedBudgets rb on rb.Id = rbl.RevisedBudgetId
) rb
where rb.VORemark != '' 

/*************************************************************PRECore***********************************************************************/

DECLARE @Status TABLE (name nvarchar(50),Description nvarchar(50),value int )

INSERT INTO  @Status (name ,Description ,value )
SELECT name ,Description ,value

FROM codedescriptions 
where Name in ('ConstructionStatus','ContractStatus','FinancialStatus','ProgressStatus')



IF OBJECT_ID(N'tempdb..#Core', N'U') IS NOT NULL
BEGIN;
    DROP TABLE #Core;
END;
SELECT * 
INTO #Core
FROM (
	select			dense_rank ( )  OVER ( ORDER BY 
				CASE	WHEN @SortBy LIKE 'QuotationDate' THEN (CONVERT(NVARCHAR(10), qt.Date, 120))
						WHEN @SortBy LIKE 'QuotationCode' THEN (CONVERT(NVARCHAR(MAX), qt.Code))
				END, qt.Code )  GroupRow
				,dbo.ThaiMY(qt.Date) GroupMMYY
				,FORMAT(qt.Date ,'yyyy/MM') GroupMMYYNum
				,qt.Id [QuotationId]
				,qt.Code [QuotationCode]
				,[dbo].[ThaiDateMN](qt.Date) [QuotationDate]
				,qt.QuotationStatus
				,qt.OriginalQuotationId
				,qt.CreateBy
				,qt.DocStatus
				,ds.DocStatusName
				,qt.ExtOrgId
				,qt.ExtOrgCode
				,qt.ExtOrgName
				,qt.Remarks [QuotationRemark]
				,org.Id [OrgId]
				,case when left(org.Code,1) = 'C' then 'ก่อสร้าง'
					  when left(org.Code,1) = 'I' then 'ตกแต่ง'
					  when left(org.Code,1) = 'L' then 'งานสวน'
					  when left(org.Code,1) = 'D' then 'ออกแบบ'
					  else 'ซุปเปอร์'
					  end Jobtype
				,org.Code [OrgCode]
				,org.Name [OrgName]
				,IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) TaxBase
				,ql.TaxAmount
				,ql.GrandTotal
				,vo.Id [VoId]
				,vo.Code [VoCode]
				,ISNULL(vo.Name,qt.Remarks) [VoName] /*2023-09-05 : กรณียังไม่ผูก VO จะใช้ Remark QT*/
				,vo.Remarks [RemarkVO]
				,[dbo].[ThaiDateMN](CONVERT(date,cnl.นำเสนอราคา,103)) [นำเสนอราคา]
				,[dbo].[ThaiDateMN](CONVERT(date,cnl.อนุมัติจากลูกค้า,103)) [อนุมัติจากลูกค้า]
				,cnl.อนุมัติจากลูกค้า2
				,ISNULL(cnl.Approve,0) Approve 
				,ISNULL(cnl.NotApprove,1) NotApprove 
				,[dbo].[ThaiDateMN](CONVERT(date,cnl.รอแบบ,103)) [รอแบบ]
				,[dbo].[ThaiDateMN](CONVERT(date,cnl.Loss,103)) [Loss]
				,cc.ConstructionStatus [VOConstructionStatus]
				,cc.ContractStatus	[VOContractStatus]
				,tb.BudgetId
				,tb.RevisedBudgetId
				,tb.VoRemark
				,cnl.QuotationCost [QuotationCost]
				,ISNULL(tbm.BeforeCompleteAmount,0) [BeforeCompleteAmount]
				,ISNULL(tbm.AfterCompleteAmount,0) [AfterCompleteAmount]

				--,case  when (ISNULL(tbm.BeforeCompleteAmount,0) > ISNULL(tbm.AfterCompleteAmount,0)) 
				--		then (ISNULL(tbm.AfterCompleteAmount,0) - ISNULL(tbm.BeforeCompleteAmount,0)) 
				--		else abs(ISNULL(tbm.BeforeCompleteAmount,0) - ISNULL(tbm.AfterCompleteAmount,0)) 
				--		end [DifferenceAmount]
				--,case when IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0)) > ISNULL(tbm.AfterCompleteAmount,0)
				--		then ISNULL(tbm.AfterCompleteAmount,0) - IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0))
				--		else abs(IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0))) - ISNULL(tbm.AfterCompleteAmount,0)
				--		end [DifferenceAmount]
				--,IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0)) - ISNULL(tbm.AfterCompleteAmount,0) [test]
				--,IIF(ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) [tax]
				,case when cnl.QuotationCost is not null
						then ISNULL(cnl.QuotationCost,0)

					  when ISNULL(tbm.BeforeCompleteAmount,0) > ISNULL(tbm.AfterCompleteAmount,0)
					    then (ISNULL(tbm.AfterCompleteAmount,0) - ISNULL(tbm.BeforeCompleteAmount,0)) 

					  else abs(ISNULL(tbm.BeforeCompleteAmount,0) - ISNULL(tbm.AfterCompleteAmount,0)) 
						end [DifferenceAmount]

				--,case when (ISNULL(tbm.BeforeCompleteAmount,0) > ISNULL(tbm.AfterCompleteAmount,0)) 
				--		then IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) -(ISNULL(tbm.AfterCompleteAmount,0) - ISNULL(tbm.BeforeCompleteAmount,0))
				--		else IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - abs((ISNULL(tbm.BeforeCompleteAmount,0) - ISNULL(tbm.AfterCompleteAmount,0)))
				--		end [DifferenceAmount2]
				--,case when IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0)) > ISNULL(tbm.AfterCompleteAmount,0) 
				--		then IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - ABS(ISNULL(tbm.AfterCompleteAmount,0) - IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0)))
				--		else IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - (IIF(cnl.QuotationCost is null,ISNULL(tbm.BeforeCompleteAmount,0),ISNULL(cnl.QuotationCost,0)) - ISNULL(tbm.AfterCompleteAmount,0))
				--		end [DifferenceAmount2]

				,case when (cnl.QuotationCost is not null) and (IIF(ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) >= ISNULL(cnl.QuotationCost,0))
						then IIF(ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - ISNULL(cnl.QuotationCost,0) 

					  when (cnl.QuotationCost is not null) and (IIF(ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) < ISNULL(cnl.QuotationCost,0))
						then ISNULL(cnl.QuotationCost,0) - IIF(ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) 

					  when (ISNULL(tbm.BeforeCompleteAmount,0) > ISNULL(tbm.AfterCompleteAmount,0)) 
						then IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - (ISNULL(tbm.AfterCompleteAmount,0) - ISNULL(tbm.BeforeCompleteAmount,0))

					  else IIF (ql.TaxBase = 0 ,ql.Subtotal,ql.TaxBase) - abs((ISNULL(tbm.BeforeCompleteAmount,0) - ISNULL(tbm.AfterCompleteAmount,0)))
						end [DifferenceAmount2]

				,ir.Id [InterimPaymentId]
				,ir.Code [InterimPaymentCode]
				,[dbo].[ThaiDateMN](ir.Date) [InterimPaymentDate]
				,ir.ContractNO [InterimPaymentContractNo]
				,ir.InspectionSheetId [InspectionSheetId]
				,ir.InspectionSheetCode [InspectionSheetCode]
				,ir.InspectionSheetdate [InspectionSheetDate]
				,ir.InspectionSheetContractNO [InspectionSheetContractNo]
				,ir.InvoiceARId [InvoiceARId]
				,ir.InvoiceARCode [InvoiceARCode]
				,ir.InvoiceARdate [InvoiceARDate]
				,ir.InvoiceARRefDocCode [InvoiceARRefDocCode]
				,ir.ReceiveVoucherId [ReceiveVoucherId]
				,ir.ReceiveVoucherCode [ReceiveVoucherCode]
				,ir.ReceiveVoucherdate [ReceiveVoucherDate]
				,ir.ReceiveVoucherRefARCodeList [RefARCodeList]
				,dbo.SitePath(84,org.Id) [LinKOrg]
				,dbo.SitePath(73,qt.Id) [LinKVOQuotation]
				,CONCAT ((SELECT Value FROM CompanyConfigs WHERE ConfigName = 'HostUrl'),'CostControl/Projectconstruction/',org.Id,'/Vo/',vo.Id) [LinKVO]
from Organizations org
left join Quotations qt on org.Id = qt.LocationId  /*ใช้ inner เนื่องจากไม่ได้อยาก ได้ โครงการที่ไม่เกี่ยวข้อง*/
left join ProjectVOes vo on qt.Id = vo.QuotationId /*ใช้ inner เนื่องจากไม่ได้อยาก ได้ โครงการที่ไม่เกี่ยวข้อง*/
left join Organizations_ProjectConstruction orgP on org.Id = orgP.Id
left join (select q.Id,q.LocationId	
				  ,sum(IIF(ql.SystemCategoryId in (107),ql.Amount,0))[Subtotal]
				  ,sum(IIF(ql.SystemCategoryId in (123,129),ql.TaxBase,0))[TaxBase]
				  ,sum(IIF(ql.SystemCategoryId in (123,129),ql.TaxAmount,0))[TaxAmount]
				  ,sum(IIF(ql.SystemCategoryId in (111),ql.Amount,0))[GrandTotal]
			from Quotations q
			left join QuotationLines ql on q.Id = ql.QuotationId
			group by q.Id,q.LocationId
			) ql on qt.Id = ql.Id
					--vo.QuotationId = ql.Id
LEFT JOIN (select cnl.DocGuid
							,cnl.นำเสนอราคา
							,cnl.อนุมัติจากลูกค้า
							,Convert(date,cnl.อนุมัติจากลูกค้า,103) [อนุมัติจากลูกค้า2]
							,cnl.รอแบบ
							,cnl.Loss
							,IIF(cnl.อนุมัติจากลูกค้า is null,0,1) [Approve]
							,IIF(cnl.อนุมัติจากลูกค้า is null,1,0) [NotApprove]
							,cnl.QuotationCost
					from( /*2024-01-16 : ทำ sub query เพื่อ Convert Date */
						SELECT cnl.DocGuid
							,MAX(IIF(cnl.KeyName = 'QT.Status1',cnl.DataValues,NULL ))[นำเสนอราคา]
							,MAX(IIF(cnl.KeyName = 'QT.Status2',cnl.DataValues,NULL ))[อนุมัติจากลูกค้า]
							,MAX(IIF(cnl.KeyName = 'QT.Status.4',cnl.DataValues,NULL ))[รอแบบ]
							,MAX(IIF(cnl.KeyName = 'Qt.Status.5',cnl.DataValues,NULL ))[Loss]	
							,MAX(IIF(cnl.KeyName = 'QuotationCost',cnl.DataValues,NULL ))[QuotationCost]	
							FROM dbo.CustomNoteLines cnl
							left join quotations q on cnl.DocGuid = q.Guid
							WHERE keyname IN ('QT.Status1','QT.Status2','QT.Status.4','Qt.Status.5','QuotationCost')
							GROUP BY cnl.DocGuid
						) cnl
				) cnl ON cnl.DocGuid = qt.Guid
OUTER APPLY(SELECT vo.ProjectConstructionId
				,MAX(IIF(cd.Name = 'ConstructionStatus',cd.description,NULL) )ConstructionStatus
				,MAX(IIF(cd.Name = 'ConstructionStatus',cd.value,NULL) )ConstructionStatusid
				,MAX(IIF(cd.Name = 'ContractStatus',cd.description,NULL) )ContractStatus
				,MAX(IIF(cd.Name = 'ContractStatus',cd.value,NULL) )ContractStatusid
				,MAX(IIF(cd.Name = 'FinancialStatus',cd.description,NULL) )FinancialStatus
				,MAX(IIF(cd.Name = 'FinancialStatus',cd.value,NULL) )FinancialStatusid
				,MAX(IIF(cd.Name = 'ProgressStatus',cd.description,NULL) )ProgressStatus
				,MAX(IIF(cd.Name = 'ProgressStatus',cd.value,NULL) )ProgressStatusid

			FROM
			@Status cd
			where ( (cd.value = vo.ConstructionStatus and cd.name = 'ConstructionStatus')
				  or (cd.value = vo.ContractStatus and cd.name = 'ContractStatus')
				  or (cd.value = vo.FinancialStatus and cd.name = 'FinancialStatus')
				  or (cd.value = vo.ProgressStatus and cd.name = 'ProgressStatus')

					)
			) cc
-- outer apply(select MAX(BudgetId) [BudgetId]
-- 					,MAX(RevisedBudgetId) [RevisedBudgetId]
-- 						,MAX(VoRemark) [VoRemark]
-- 					from #tempBudget
-- 					where vo.Code = VoRemark
-- 					) tb
outer apply(Select BudgetId, MIN(RevisedBudgetId)[RevisedBudgetId],VoRemark
			From #tempBudget
			Where CompleteAmount != 0
					AND vo.Code = VoRemark
			Group By BudgetId,VoRemark
			) tb
outer apply(select tb1.Date
					,SUM(tb1.BudgetForwardAmount) BeforeCompleteAmount
					,SUM(tb1.CompleteAmount) AfterCompleteAmount
					,tb1.VoRemark
			from (select rl.BudgetLineId
						,rl.Date
						,rl.BudgetForwardAmount
						,rl.CompleteAmount	
						,substring(rl.Remarks,0, charindex('|',rl.Remarks)) [VORemark]
					from RevisedBudgetLines rl WHERE rl.RevisedBudgetId = (select MIN(rt.RevisedBudgetId) from RevisedBudgetLines rt where rt.BudgetLineId = rl.BudgetLineId AND vo.Code = rt.Remarks)
					)tb1
			where tb1.VoRemark = tb.VoRemark
			Group by tb1.Date
					,tb1.VoRemark
					) tbm 
outer apply(select ir.id,ir.Code,ir.Date,ir.ContractNO
					,dbo.GROUP_CONCAT(ir.InspectionSheetId) [InspectionSheetId]
					,dbo.GROUP_CONCAT(ir.InspectionSheetCode) [InspectionSheetCode]
					,dbo.GROUP_CONCAT(ir.InspectionSheetdate) [InspectionSheetdate]
					,dbo.GROUP_CONCAT(ir.InspectionSheetContractNO) [InspectionSheetContractNO]
					,dbo.GROUP_CONCAT(ir.InvoiceARId) [InvoiceARId]
					,dbo.GROUP_CONCAT(ir.InvoiceARCode) [InvoiceARCode]
					,dbo.GROUP_CONCAT(ir.InvoiceARdate) [InvoiceARdate]
					,dbo.GROUP_CONCAT(ir.InvoiceARRefDocCode) [InvoiceARRefDocCode]
					,dbo.GROUP_CONCAT(ir.ReceiveVoucherId) [ReceiveVoucherId]
					,dbo.GROUP_CONCAT(ir.ReceiveVoucherCode) [ReceiveVoucherCode]
					,dbo.GROUP_CONCAT(ir.ReceiveVoucherdate) [ReceiveVoucherdate]
					,dbo.GROUP_CONCAT(ir.ReceiveVoucherRefARCodeList) [ReceiveVoucherRefARCodeList]
			from (select distinct ir.Id,ir.Code,ir.Date,irl.ContractNO
						,iss.InspectionSheetId,iss.InspectionSheetCode,iss.InspectionSheetdate,iss.InspectionSheetContractNO
						,i.InvoiceARId,i.InvoiceARCode,i.InvoiceARdate,i.InvoiceARRefDocCode
						,r.ReceiveVoucherId,r.ReceiveVoucherCode,r.ReceiveVoucherdate,r.ReceiveVoucherRefARCodeList
					from InterimPaymentLines irl 
					left join InterimPayments ir on irl.InterimPaymentId = ir.Id
					outer apply(select distinct iss.Id [InspectionSheetId],iss.Code [InspectionSheetCode]
									,[dbo].[ThaiDateMN](iss.Date) [InspectionSheetdate]
									,issl.ContractNO [InspectionSheetContractNO]
								from InspectionSheetLines issl
								left join InspectionSheets iss on issl.InspectionSheetId = iss.Id and iss.DocStatus not in (-1)
								where issl.ContractNO = irl.ContractNO
								)iss
					outer apply(select distinct i.Id [InvoiceARId],i.Code [InvoiceARCode]
									,[dbo].[ThaiDateMN](i.Date) [InvoiceARdate]
									,il.RefDocCode [InvoiceARRefDocCode]
								from InvoiceARLines il
								left join InvoiceARs i on il.InvoiceARId = i.Id and i.DocStatus not in (-1)
								where il.RefDocCode = iss.InspectionSheetCode
								)i
					outer apply(select distinct r.Id [ReceiveVoucherId],r.Code [ReceiveVoucherCode]
									,[dbo].[ThaiDateMN](r.Date) [ReceiveVoucherdate]
									,rl.RefARCodeList [ReceiveVoucherRefARCodeList]
								from ReceiveVoucherLines rl
								left join ReceiveVouchers r on rl.ReceiveVoucherId = r.Id and r.DocStatus not in (-1)
								where rl.RefARCodeList = i.InvoiceARCode
								)r
					) ir
			where ir.ContractNO = tb.VoRemark
			group by ir.id,ir.Code,ir.Date,ir.ContractNO
			) ir


LEFT JOIN dbo.NameDocStatusList() ds ON qt.DocStatus = ds.DocStatusId
where --CONVERT(DATE, qt.Date) BETWEEN @FromDate AND @Todate
		((CONVERT(DATETIME,CONVERT(NVARCHAR(10),qt.Date, 120)) BETWEEN @FromDate AND @Todate)
					OR (NULLIF(@FromDate, '1900-01-01') IS NULL AND NULLIF(@Todate,'1900-01-01') IS NULL)) /*2024-01-16 : Document Date เป็นค่าว่างได้*/
		AND (exists (select 1 from @OrgId a where org.Id = a.Id) or @ProjectId is null)
		AND ((qt.ExtOrgId IN (SELECT ncode FROM dbo.fn_listCode(@CustomerId))) OR @CustomerId IS NULL)
		AND((qt.QuotationStatus = @QuotationStatus and @QuotationStatus <> -2) OR (@QuotationStatus IS NULL) OR (@QuotationStatus = -2 AND qt.OriginalQuotationId IS NOT NULL ))
		AND ((qt.Code LIKE '%' + @QuotationCode + '%') OR @QuotationCode IS NULL)
		AND (qt.DocStatus IN (SELECT ncode FROM fn_listCode(@DocStatus)) OR @DocStatus IS NULL )
		AND (qt.CreateBy like '%'+@CreateBy+'%' Or @CreateBy is null)
		AND ((CONVERT(DATETIME,CONVERT(NVARCHAR(10),cnl.อนุมัติจากลูกค้า2, 120)) BETWEEN @ApproveFromDate AND @ApproveTodate)
					OR (NULLIF(@ApproveFromDate, '1900-01-01') IS NULL AND NULLIF(@ApproveTodate,'1900-01-01') IS NULL)) /*2024-01-16 : Approve Date เป็นค่าว่างได้*/
		AND qt.Code is not NULL  /*2024-01-16 : QuotationCode ต้องไม่เท่ากับ NULL*/
		AND ((@Approve = 1 AND isnull(cnl.Approve,0)  = 1) OR @Approve = 0)
		AND ((@NotApprove= 1 AND isnull(cnl.NotApprove,1)  = 1) OR @NotApprove = 0)
		AND ((@BudgetAmount = 'Equal To 0' AND ISNULL(cnl.QuotationCost,0) = 0) 
			OR (@BudgetAmount = 'Not Equal To 0' AND ISNULL(cnl.QuotationCost,0) != 0) 
			OR (@BudgetAmount = 'ALL' AND @BudgetAmount IS NOT NULL)) /* 30/09/2024 เปลี่ยนจากกรอง AfterCompleteAmount เป็น QuotationCost */
) a
/*************************************************************1-Core***********************************************************************/
--select * from #temp where ProjectId = 116
--select * from #tempBudget 
SELECT * FROM #Core
-- WHERE ((@BudgetAmount = 'Equal To 0' AND DifferenceAmount = 0) 
-- 			OR (@BudgetAmount = 'Not Equal To 0' AND DifferenceAmount != 0) 
-- 			OR (@BudgetAmount = 'ALL' AND @BudgetAmount IS NOT NULL) ) /* 04/09/2024 : เพิ่ม filter กรอง AfterCompleteAmount */
			


/**2-Filter**/
SELECT CONCAT('Date : ', FORMAT(@FromDate, 'dd/MM/yyyy'), ' To ', FORMAT(@Todate, 'dd/MM/yyyy')) Date
	   ,(SELECT dbo.GROUP_CONCAT(Name) FROM dbo.Organizations WHERE Id IN (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) [ProjectName]
       ,@incChild incChild
	   ,(SELECT dbo.GROUP_CONCAT(Name) FROM dbo.ExtOrganizations WHERE Id IN (SELECT ncode FROM dbo.fn_listCode(@CustomerId))) [Customer] 
	   ,CASE	WHEN @QuotationStatus IS NULL THEN 'All'
				WHEN @QuotationStatus IS NOT NULL THEN (SELECT Description FROM CodeDescriptions WHERE name = 'QuotationStatus' AND Value = @QuotationStatus)
		 END   [Status]
	   ,@QuotationCode DocCode
	   ,@CreateBy CreateBy
	   ,@SortBy	Orderby
	   ,@Expend Expend
	   ,CASE	WHEN @BudgetAmount IS NULL THEN 'All'
	   			WHEN @BudgetAmount IS NOT NULL THEN @BudgetAmount
				END BudgetAmount
/************************************************************************************************************************************************************************/
/*3-Company*/
SELECT * FROM fn_CompanyInfoTable (@ProjectId)
/************************************************************************************************************************************************************************/



IF OBJECT_ID(N'tempdb..#tempBudget', N'U') IS NOT NULL
BEGIN;
    DROP TABLE #tempBudget;
END;
IF OBJECT_ID(N'tempdb..#Core', N'U') IS NOT NULL
BEGIN;
    DROP TABLE #Core;
END;