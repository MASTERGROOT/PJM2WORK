/*==> Ref:d:\programmanee\prototype-thsd\notpublish\customprinting\reportcommands\mtp101_tax_planning_report.sql ==>*/
 

DECLARE @p0 DATE = '2024-03-01'
DECLARE @p1 DATE = '2024-04-30'
DECLARE @p2 int  = '1'
DECLARE @p3 NVARCHAR(10) = '0.51' /*0.51*/
DECLARE @p4 NVARCHAR(10)  = '0.80' /*0.80*/


DECLARE @startDate DATE = @p0
DECLARE @endDate DATE = @p1
DECLARE @ProjectId int = @p2
DECLARE @SalaryRate NVARCHAR(10) = @p3
DECLARE @FareRate NVARCHAR(10)  = @p4

/******************** Temp Project ********************/

 IF OBJECT_ID(N'tempdb..#temporg', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #temporg;
    END;
	 
		 Select o.Id,o.Code,o.Name
		 Into #temporg
		 From 
		 Organizations org 
		 left join Organizations o ON o.Path like org.Path + '%'
		 Where  isnull( @ProjectId,'')  =''  or org.Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId)) 



--select * from #temporg --test #temporg

/******************** Temp #Revenue ประมาณการรายได้ ********************/

  IF OBJECT_ID(N'tempdb..#Revenue', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Revenue;
    END;

select	'รายได้' [รายได้]
		,'2' Sort
		,'ประมาณการรายได้' [GroupType]
		,a.Description [Detail]
		,a.Date
		,a.Amount
Into #Revenue
from
	(select a.LocationId
			,a.LocationCode
			,a.LocationName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.Description
			,a.Amount
		from(select r.LocationId
					,r.LocationCode
					,r.LocationName
					,r.Date
					,rl.Description
					,rl.Amount
					,rl.SystemCategoryId
			from Requests r
			left join RequestLines rl on r.Id = rl.RequestId
			where r.SubDocTypeId = '645'  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2026,2027)
				)a 
		)a 

/******************** Temp #Estimatedcostsrequired ประมาณการต้นทุนที่ต้องใช้ ********************/
  IF OBJECT_ID(N'tempdb..#Estimatedcostsrequired', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Estimatedcostsrequired;
    END;


select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'ประมาณการต้นทุนที่ต้องใช้' [GroupType]
		,a.Description [Detail]
		,a.Date
		,a.Amount
Into #Estimatedcostsrequired
from
	(select a.LocationId
			,a.LocationCode
			,a.LocationName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.Description
			,a.Amount
		from(select r.LocationId
					,r.LocationCode
					,r.LocationName
					,r.Date
					,rl.Description
					,rl.Amount
					,rl.SystemCategoryId
			from Requests r
			left join RequestLines rl on r.Id = rl.RequestId
			where r.SubDocTypeId in (646,647)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2028,2029,2030,2031,2032,2033,2034,2035,2036,2037)
				)a 
		)a 

/******************** Temp #Estimatenewprojectcosts ประมาณการต้นทุนโครงการใหม่ ********************/
  IF OBJECT_ID(N'tempdb..#Estimatenewprojectcosts', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Estimatenewprojectcosts;
    END;


select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'ประมาณการต้นทุนโครงการใหม่' [GroupType]
		,a.Description [Detail]
		,a.Date
		,a.Amount
Into #Estimatenewprojectcosts
from
	(select a.LocationId
			,a.LocationCode
			,a.LocationName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.Description
			,a.Amount
		from(select r.LocationId
					,r.LocationCode
					,r.LocationName
					,r.Date
					,rl.Description
					,rl.Amount
					,rl.SystemCategoryId
			from Requests r
			left join RequestLines rl on r.Id = rl.RequestId
			where r.SubDocTypeId in (648,649)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2028,2029,2030,2031,2032,2033,2034,2035,2036,2037)
				)a 
		)a 

/******************** Temp #SalaryRate 2.05 เงินเดือน ปันส่วน ********************/
  IF OBJECT_ID(N'tempdb..#SalaryRate', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #SalaryRate;
    END;


select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'2' Sort
		,'Actual' [GroupType]
		,'2.05 เงินเดือน ปันส่วน' [Detail]
		,a.Date
		,((sum(a.DeAmount)  - sum(a.CreAmount)) * Isnull(@SalaryRate,1)) [AmtSalaryRate]
Into #SalaryRate
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.Date
					,jv.DocAmount
					,jv.JournalVoucherId
					,jv.isDebit
				from JournalVouchers j
				left join JVLines jv on j.Id = jv.JournalVoucherId
				where jv.AccountCode = '61010001'
						--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
						and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
						and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
						and j.DocStatus not in (-1)
						
				)a 
				group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit
)a 
group by a.Date

/******************** Temp #FareRate 2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat********************/
  IF OBJECT_ID(N'tempdb..#FareRate', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #FareRate;
    END;

select	 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		 ,'2' Sort
		 ,'Actual' [GroupType]	
		 ,'2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' [Detail]
		 ,a.Date
		 ,((sum(a.DeAmount)  - sum(a.CreAmount)) * Isnull(@FareRate,1)) [AmtFareRate]
Into #FareRate
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0)[DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0)[CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.Date
					,jv.DocAmount
					,jv.JournalVoucherId
					,jv.isDebit
		from JournalVouchers j
		left join JVLines jv on j.Id = jv.JournalVoucherId
		where jv.AccountCode in ('61030001','61030002','61030003','61030004')
				--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
				and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
				and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
				and j.DocStatus not in (-1)		
				
				
		)a
		group by a.OrgId
				,a.OrgCode
				,a.OrgName
				,a.Date
				,a.isDebit
)a
group by a.Date

/******************** Temp #OnSiteDepreciation 2.06 ค่าเสื่อมราคาหน้างาน********************/
  IF OBJECT_ID(N'tempdb..#OnSiteDepreciation', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #OnSiteDepreciation;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'2' Sort
		,'Actual' [GroupType]
		,'2.06 ค่าเสื่อมราคาหน้างาน' [Detail]
		,a.Date
		,((sum(a.DeAmount)  - sum(a.CreAmount))) [AmtOnSiteDepreciation]
Into #OnSiteDepreciation
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.Date
					,jv.DocAmount
					,jv.JournalVoucherId
					,jv.isDebit
					from JournalVouchers j
		left join JVLines jv on j.Id = jv.JournalVoucherId
		where jv.AccountCode in ('61110006')
				--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
				and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
				and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
				and j.DocStatus not in (-1)

		)a
		group by a.OrgId
				,a.OrgCode
				,a.OrgName
				,a.Date
				,a.isDebit
)a
group by a.Date

/******************** Temp #ManagementWithOutVat 2.10 บริหารไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#ManagementWithOutVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManagementWithOutVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]
		,'2.10 บริหารไม่มี Vat' [Detail]
		,a.Date
		,((sum(a.DeAmount)  - sum(a.CreAmount)) * 0.49) [AmtManagementWithOutVat]
Into #ManagementWithOutVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
	from(select j.OrgId
				,j.OrgCode
				,j.OrgName
				,j.Date
				,jv.DocAmount
				,jv.JournalVoucherId
				,jv.isDebit
				from JournalVouchers j
				left join JVLines jv on j.Id = jv.JournalVoucherId
				where jv.AccountCode = '61010001'
						--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
						and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
						and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
						and j.DocStatus not in (-1)
				)a
			group by a.OrgId
					,a.OrgCode
					,a.OrgName
					,a.Date
					,a.isDebit
)a
group by a.Date

/******************** Temp #ManageVat 2.09 บริหาร Vat********************/
  IF OBJECT_ID(N'tempdb..#ManageVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManageVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]	
		,'2.09 บริหาร Vat' [Detail]
		,a.Date
		,ISNULL((sum(a.DeAmount)  - sum(a.CreAmount)),0) [AmtManageVat]
Into #ManageVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.Date
					,jv.DocAmount
					,jv.JournalVoucherId
					,jv.isDebit
					from JournalVouchers j
					left join JVLines jv on j.Id = jv.JournalVoucherId
					where (jv.AccountCode between '60000000' and '61130006')
							--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
							and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
							and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
							and j.DocStatus not in (-1)
					)a
		group by a.OrgId
				,a.OrgCode
				,a.OrgName
				,a.Date
				,a.isDebit
)a
group by a.Date

/******************** Temp #AdvertisingExpensesVat 2.08 ค่าโฆษณา Vat********************/
  IF OBJECT_ID(N'tempdb..#AdvertisingExpensesVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #AdvertisingExpensesVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]	
		,'2.08 ค่าโฆษณา Vat' [Detail]
		,a.Date
		,ISNULL((sum(a.DeAmount)  - sum(a.CreAmount)),0) [AmtAdvertisingExpensesVat]
Into #AdvertisingExpensesVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
from(select j.OrgId
			,j.OrgCode
			,j.OrgName
			,j.Date
			,jv.DocAmount
			,jv.JournalVoucherId
			,jv.isDebit
			from JournalVouchers j
			left join JVLines jv on j.Id = jv.JournalVoucherId
			where jv.AccountCode in ('60020002','60030002','60030003','60030007')
					--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
					and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
					and j.DocStatus not in (-1)
			)a
			group by a.OrgId
					,a.OrgCode
					,a.OrgName
					,a.Date
					,a.isDebit
)a
group by a.Date
/******************** Temp #Subcontract 2.03 ค่าแรงมี Vat / 2.04 ค่าแรงไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#Subcontract', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Subcontract;
    END;

/*ค่าแรง*/
select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]
		,Case when a.vat = 'Vat' then '2.03 ค่าแรงมี Vat'
				else '2.04 ค่าแรงไม่มี Vat'
			end [Detail]
		,a.Date
		,isnull(sum(a.Amount),0) [AmtSubcontract]
Into #Subcontract
from(
select	jv.Amount
		,j.[Date]--FORMAT(j.Date ,'yyyyMM')  [Date]
		,j.OrgCode
		,Case when i.SystemCategoryId in (123,129) then 'Vat'
				else 'NoVat'
			end vat
from  JournalVouchers j
left join JVLines jv on j.Id = jv.JournalVoucherId
left join (select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from Invoices i
			left join InvoiceLines il on i.Id = il.InvoiceId
			where il.SystemCategoryId in (123,129,131)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherPayments i
			left join OtherPaymentLines il on i.Id = il.OtherPaymentId
			where il.SystemCategoryId in (123,129,131)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from WorkerExpenses i
			left join WorkerExpenseLines il on i.Id = il.WorkerExpenseId
			where il.SystemCategoryId in (123,129,131)

			) i on  j.MadeByDocCode = i.Code

where AccountCode IN (51010002,51040005,51040007,51040008,51050102,51050103,51050104,51050105,51070102,51070302,51080002,51090206,51130101,51140002
						,51150101,51150201,51150302,51160001,51170003,51170201,51170202,51170203,51170204,51170303,51170403,51170404,51170405
						,51170406,51180001,51190101,51210101,51210102,51220001,51230002,51240001,51250002,51272001,51272002,52060001,52060021
						,52060022,52080001,52090104,52090205,52090206,52110002,52120004,52130002,52150002,52170002,52180003,52180004,55040402
						,55050203,55110001,55110002,55120001,55130004,55140001)
		and j.DocStatus in (4,5)
		and jv.isDebit = 1
		--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
		and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
)a group by a.Date,a.vat

/******************** Temp #Material 2.01 ค่าของมี Vat / 2.02 ค่าของไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#Material', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Material;
    END;

/*ค่าของ*/
select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]	
		,Case when a.vat = 'Vat' then '2.01 ค่าของมี Vat'
				else '2.02 ค่าของไม่มี Vat'
			end [Detail]
		,a.Date
		,isnull(sum(a.Amount),0) [AmtMaterial]
Into #Material
from(
select jv.Amount
		,j.[Date]--FORMAT(j.Date ,'yyyyMM')  [Date]
		,j.OrgCode
		,Case when i.SystemCategoryId in (123,129) then 'Vat'
				else 'NoVat'
			end vat
		,j.MadeByType
		,j.MadeByDocCode
from  JournalVouchers j
left join JVLines jv on j.Id = jv.JournalVoucherId
left join (select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from Invoices i
			left join InvoiceLines il on i.Id = il.InvoiceId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherPayments i
			left join OtherPaymentLines il on i.Id = il.OtherPaymentId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from WorkerExpenses i
			left join WorkerExpenseLines il on i.Id = il.WorkerExpenseId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1) 
			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherReceives i
			left join OtherReceiveLines il on i.Id = il.OtherReceiveId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)
			) i on  j.MadeByDocCode = i.Code
where AccountCode IN (51010001,51010005,51010006,51020002,51020003,51020007,51020010,51020011,51020012,51020014,51020016,51030001,51030002,51030003,51030004
						,51030005,51030006,51030007,51030009,51030010,51030011,51030012,51040001,51040002,51040004,51040006,51050101,51050202,51050203
						,51050204,51050206,51050207,51050208,51070101,51070301,51080001,51080003,51090101,51090203,51090204,51090301,51100001,51110001
						,51120101,51120201,51120202,51120204,51120206,51130202,51130205,51140001,51150301,51170001,51170002,51170101,51170103,51170104
						,51170301,51170401,51170402,51170503,51190003,51190004,51210001,51210002,51210003,51210004,51210104,51230001,51250001,51271001
						,52020001,52040001,52040002,52050003,52070001,52090101,52090102,52090201,52100001,52110001,52120003,52140203,52160001,52170001
						,52180001,54020101,54060001,55010001,55040401,55050201,55050202,55060001,55080001,52190001)
		and j.DocStatus in (4,5)
		and jv.isDebit = 1
		--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
		and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
)a group by a.Date,a.vat

/******************** Temp #Accouctchart4Vat รายได้ผัง4 Vat / รายได้ผัง4ไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#Accouctchart4Vat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Vat;
    END;

/*รายได้ผัง4 Vat*/
select	'รายได้' [รายได้]
		,'3' Sort
		,'Actual' [GroupType]	
		,Case when a.vat = 'Vat' then '1.01 ประมาณการรายได้'
				else 'รายได้ผัง4ไม่มี Vat'
			end [Detail]
		,a.Date
		,isnull(sum(a.Amount),0) [AmtMaterial]
Into #Accouctchart4Vat
from(
select DISTINCT s.Amount
				,s.DocDate [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,Case when i.SystemCategoryId in (123,129) then 'Vat'
						else 'NoVat'
					end vat
				,s.DocType
				,s.DocCode
from AcctElementSets s
inner join (select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from InvoiceARs i
			inner join InvoiceARLines il on i.Id = il.InvoiceARId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherPayments i
			inner join OtherPaymentLines il on i.Id = il.OtherPaymentId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from AssetWriteOffs i
			inner join AssetWriteOffLines il on i.Id = il.AssetWriteOffId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1) 
			
			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherReceives i
			inner join OtherReceiveLines il on i.Id = il.OtherReceiveId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,131 [SystemCategoryId]

			from JournalVouchers i
			inner join JVLines il on i.Id = il.JournalVoucherId
			where  i.DocStatus not in (-1) 

			union all

			select DISTINCT i.Id,i.Code,iv.SystemCategoryId
			from Payments i
			inner join PaymentLines il on i.Id = il.PaymentId
			inner join (select i.Id,i.Code,il.SystemCategoryId
						from Invoices i
						inner join InvoiceLines il on i.Id = il.InvoiceId
						where il.SystemCategoryId in (123,129,131)
								and i.DocStatus not in (-1)

						union all

						select i.Id,i.Code,v.SystemCategoryId
						from BillingAPs i
						inner join BillingAPLines il on i.Id = il.BillingAPId
						inner join(select i.Id,i.Code,il.SystemCategoryId
									from Invoices i
									inner join InvoiceLines il on i.Id = il.InvoiceId
									where il.SystemCategoryId in (123,129,131)
											and i.DocStatus not in (-1)
									) v on il.DocCode = v.Code
						where v.SystemCategoryId in (123,129,131)
								and i.DocStatus not in (-1)
						) iv on il.DocCode = iv.Code
			where  i.DocStatus not in (-1) 
			) i on  s.DocCode = i.Code
where s.AccountCode IN (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
		and s.isDebit = 0
		and (s.DocDate BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (s.OrgId in (select Id from #temporg) or @ProjectId is NULL)
		and i.SystemCategoryId in (123,129)
)a group by a.Date,a.vat

/******************** Temp #Accouctchart4NoVat  รายได้ผัง4ไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#Accouctchart4NoVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4NoVat;
    END;

/*รายได้ผัง4ไม่มี Vat*/
select	'รายได้' [รายได้]
		,'3' Sort
		,'Actual' [GroupType]	
		,Case when a.vat = 'Vat' then 'รายได้ผัง4 Vat'
				else '1.02 Vatขาย'
			end [Detail]
		,a.Date
		,isnull(sum(a.Amount),0) [AmtMaterial]
Into #Accouctchart4NoVat
from(
select DISTINCT s.Amount
				,s.DocDate [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,Case when i.SystemCategoryId in (123,129) then 'Vat'
						else 'NoVat'
					end vat
				,s.DocType
				,s.DocCode
from AcctElementSets s
inner join (select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from InvoiceARs i
			inner join InvoiceARLines il on i.Id = il.InvoiceARId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherPayments i
			inner join OtherPaymentLines il on i.Id = il.OtherPaymentId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from AssetWriteOffs i
			inner join AssetWriteOffLines il on i.Id = il.AssetWriteOffId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1) 
			
			union all

			select DISTINCT i.Id,i.Code,il.SystemCategoryId
			from OtherReceives i
			inner join OtherReceiveLines il on i.Id = il.OtherReceiveId
			where il.SystemCategoryId in (123,129,131)
					and i.DocStatus not in (-1)

			union all

			select DISTINCT i.Id,i.Code,131 [SystemCategoryId]

			from JournalVouchers i
			inner join JVLines il on i.Id = il.JournalVoucherId
			where  i.DocStatus not in (-1) 

			union all

			select DISTINCT i.Id,i.Code,iv.SystemCategoryId
			from Payments i
			inner join PaymentLines il on i.Id = il.PaymentId
			inner join (select i.Id,i.Code,il.SystemCategoryId
						from Invoices i
						inner join InvoiceLines il on i.Id = il.InvoiceId
						where il.SystemCategoryId in (123,129,131)
								and i.DocStatus not in (-1)

						union all

						select i.Id,i.Code,v.SystemCategoryId
						from BillingAPs i
						inner join BillingAPLines il on i.Id = il.BillingAPId
						inner join(select i.Id,i.Code,il.SystemCategoryId
									from Invoices i
									inner join InvoiceLines il on i.Id = il.InvoiceId
									where il.SystemCategoryId in (123,129,131)
											and i.DocStatus not in (-1)
									) v on il.DocCode = v.Code
						where v.SystemCategoryId in (123,129,131)
								and i.DocStatus not in (-1)
						) iv on il.DocCode = iv.Code
			where  i.DocStatus not in (-1) 
			) i on  s.DocCode = i.Code
where s.AccountCode IN (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
		and s.isDebit = 0
		and (s.DocDate BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (s.OrgId in (select Id from #temporg) or @ProjectId is NULL)
		and i.SystemCategoryId not in (123,129)
)a group by a.Date,a.vat

/*********************************************************************/
/********************Combine Temp****************************************/
  IF OBJECT_ID(N'tempdb..#CombineTable', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #CombineTable;
    END;
SELECT *
INTO #CombineTable
FROM 
(
	select  --IIF(a.รายได้ in ('รายได้'),1,0) [Sort1]
		a.รายได้ [No.]
		-- ,a.Sort [Sort2]
		,a.GroupType
		,a.Detail
		,FORMAT(a.[Date], 'yyyy-MM-dd','en') [DateDetail]
		,CAST(YEAR(a.[Date]) AS nvarchar) + '0' + CAST(MONTH(a.[Date]) AS nvarchar) [yearMonth]
		,FORMAT(a.[Date],'MMMM','th') [Month]
		-- ,case when a.Date like '%01' then 'มกราคม'
		-- 		when a.Date like '%02' then 'กุมภาพันธ์'
		-- 		when a.Date like '%03' then 'มีนาคม'
		-- 		when a.Date like '%04' then 'เมษายน'
		-- 		when a.Date like '%05' then 'พฤษภาคม'
		-- 		when a.Date like '%06' then 'มิถุนายน'
		-- 		when a.Date like '%07' then 'กรกฏาคม'
		-- 		when a.Date like '%08' then 'สิงหาคม'
		-- 		when a.Date like '%09' then 'กันยายน'
		-- 		when a.Date like '%10' then 'ตุลาคม'
		-- 		when a.Date like '%11' then 'พฤษจิกายน'
		-- 		when a.Date like '%12' then 'ธันวาคม'
		-- 		end [Month]
		
		-- ,NULL [RD] --IIF(a.[รายได้] = 'รายได้',100,NULL)
		-- ,NULL [MTP] --IIF(a.[รายได้] = 'รายได้',100,NULL)
		-- ,NULL [Diff.1]
		,IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL) [ประมาณการรายได้]
		-- ,NULL [ผลต่าง+-]
		,IIF(a.GroupType = 'ประมาณการต้นทุนที่ต้องใช้',a.Amount,NULL) [ประมาณการต้นทุนที่ต้องใช้]
		,IIF(a.GroupType = 'ประมาณการต้นทุนโครงการใหม่',a.Amount,NULL) [ประมาณการต้นทุนโครงการใหม่]
		,IIF(a.GroupType = 'ประมาณการSum',a.Amount,IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL)) [Total budget]
		,IIF(a.GroupType = 'Actual',a.Amount,NULL) [Actual]
		,IIF(a.GroupType = 'Diff',a.Amount,NULL)   [Diff]
		
		
		

from(
			select * from #Revenue
		union all 
			select * from #Estimatedcostsrequired
		union all 
			select * from #Estimatenewprojectcosts
		union all
			select 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
					,'3' Sort
					,'ประมาณการSum' [GroupType]
					,isnull(er.Detail,ec.Detail) [Detail]
					,isnull(er.Date,ec.Date) [Date]
					,(isnull(er.Amount,0) + isnull(ec.Amount,0)) [Amount]
			from #Estimatedcostsrequired er
			full join #Estimatenewprojectcosts ec on  er.Detail = ec.Detail and er.Date = ec.Date
		union all		
			select * from #Material
		union all 
			select * from #Subcontract
		union all 
			select * from #SalaryRate
		union all 
			select * from #OnSiteDepreciation
		union all 
			select * from #FareRate
		union all 
			select * from #AdvertisingExpensesVat
		union all 
			select mv.ค่าใช้จ่าย,mv.Sort,mv.GroupType,mv.Detail
			,mv.Date
			,isnull(mv.AmtManageVat,0) 
				- (isnull(sr.AmtSalaryRate,0) 
				+ isnull(fr.AmtFareRate,0) 
				+ isnull(od.AmtOnSiteDepreciation,0) 
				+ isnull(mov.AmtManagementWithOutVat,0) 
				+ isnull(ae.AmtAdvertisingExpensesVat,0)) [AmtManageVat]
			from #SalaryRate sr
			left join #FareRate fr on sr.Date = fr.Date
			left join #OnSiteDepreciation od on sr.Date = od.Date
			left join #ManagementWithOutVat mov on sr.Date = mov.Date
			left join #ManageVat mv on sr.Date = mv.Date
			left join #AdvertisingExpensesVat ae on sr.Date = ae.Date
		union all 
			select * from #ManagementWithOutVat
		union all
			select * from #Accouctchart4Vat
		union all
			select * from #Accouctchart4NoVat
		union all
			select  'รายได้' [รายได้]
					,'3' Sort
					,'Diff' [GroupType]	
					,r.Detail
					,r.Date
					,case when r.Detail = '1.01 ประมาณการรายได้' then isnull(r.Amount,0) - isnull(v.AmtMaterial,0) --[AmtMaterial]
						  when r.Detail = '1.02 Vatขาย' then isnull(r.Amount,0) - isnull(nv.AmtMaterial,0)
					 end [AmtMaterial]
			from #Revenue r
			left join #Accouctchart4Vat v on r.Detail = v.Detail and r.Date = v.Date
			left join #Accouctchart4NoVat nv on r.Detail = nv.Detail and r.Date = nv.Date

			union all 

			select 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
					,'3' Sort
					,'Diff' [GroupType]
					,isnull(er.Detail,ec.Detail) [Detail]
					,isnull(er.Date,ec.Date) [Date]
					,case when er.Detail = '2.01 ค่าของมี Vat' or ec.Detail = '2.01 ค่าของมี Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(m.AmtMaterial,0) 
						  when er.Detail = '2.02 ค่าของไม่มี Vat' or ec.Detail = '2.02 ค่าของไม่มี Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(m.AmtMaterial,0)
						  when er.Detail = '2.03 ค่าแรงมี Vat' or ec.Detail = '2.03 ค่าแรงมี Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(s.AmtSubcontract,0)
						  when er.Detail = '2.04 ค่าแรงไม่มี Vat' or ec.Detail = '2.04 ค่าแรงไม่มี Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(s.AmtSubcontract,0)
						  when er.Detail = '2.05 เงินเดือน ปันส่วน' or ec.Detail = '2.05 เงินเดือน ปันส่วน' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(sr.AmtSalaryRate,0)
						  when er.Detail = '2.06 ค่าเสื่อมราคาหน้างาน' or ec.Detail = '2.06 ค่าเสื่อมราคาหน้างาน' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(od.AmtOnSiteDepreciation,0)
						  when er.Detail = '2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' or ec.Detail = '2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(fr.AmtFareRate,0)
						  when er.Detail = '2.08 ค่าโฆษณา Vat' or ec.Detail = '2.08 ค่าโฆษณา Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(av.AmtAdvertisingExpensesVat,0)
						  when er.Detail = '2.09 บริหาร Vat' or ec.Detail = '2.09 บริหาร Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(mt.AmtManageVat,0)
						  when er.Detail = '2.10 บริหารไม่มี Vat' or ec.Detail = '2.10 บริหารไม่มี Vat' then (isnull(er.Amount,0) + isnull(ec.Amount,0)) - isnull(mn.AmtManagementWithOutVat,0)
					 end [Amount]
			from #Estimatedcostsrequired er
			full join #Estimatenewprojectcosts ec on  er.Detail = ec.Detail and er.Date = ec.Date
			left join #Material m on er.Detail = m.Detail 
			left join #Subcontract s on er.Detail = s.Detail 
			left join #SalaryRate sr on er.Detail = sr.Detail
			left join #OnSiteDepreciation od on er.Detail = od.Detail
			left join #FareRate fr on er.Detail = fr.Detail
			left join #AdvertisingExpensesVat av on er.Detail = av.Detail
			left join (select mv.ค่าใช้จ่าย,mv.Sort,mv.GroupType,mv.Detail
						,mv.Date
						,isnull(mv.AmtManageVat,0) 
							- (isnull(sr.AmtSalaryRate,0) 
							+ isnull(fr.AmtFareRate,0) 
							+ isnull(od.AmtOnSiteDepreciation,0) 
							+ isnull(mov.AmtManagementWithOutVat,0) 
							+ isnull(ae.AmtAdvertisingExpensesVat,0)) [AmtManageVat]
						from #SalaryRate sr
						left join #FareRate fr on sr.Date = fr.Date
						left join #OnSiteDepreciation od on sr.Date = od.Date
						left join #ManagementWithOutVat mov on sr.Date = mov.Date
						left join #ManageVat mv on sr.Date = mv.Date
						left join #AdvertisingExpensesVat ae on sr.Date = ae.Date
						) mt on er.Detail = mt.Detail
			left join #ManagementWithOutVat mn on er.Detail = mn.Detail

) a		
Group by a.รายได้,a.GroupType,a.Detail,a.Sort,a.[Date],a.Amount
) a

/******************** Temp #NetProfit********************/
--   IF OBJECT_ID(N'tempdb..#NetProfit', N'U') IS NOT NULL
--     BEGIN
--         DROP TABLE #NetProfit;
--     END;

-- SELECT *
-- INTO #NetProfit
-- FROM (
	
-- 	SELECT	'กำไรก่อนปรับปรุง' [No.],
-- 		CASE WHEN c.[No.] LIKE 'ค่าใช้จ่าย' THEN 'รวมค่าใช้จ่าย'
-- 			WHEN c.[No.] LIKE 'รายได้' THEN 'รวมรายได้'
-- 		END [Total],
-- 		c.[DateDetail],
-- 		c.yearMonth,
-- 		c.Month,
-- 		-- SUM(c.[ประมาณการรายได้]) AS Sum_ประมาณการรายได้,
--         -- SUM(c.[ประมาณการต้นทุนที่ต้องใช้]) AS Sum_ประมาณการต้นทุนที่ต้องใช้,
--         -- SUM(c.[ประมาณการต้นทุนโครงการใหม่]) AS Sum_ประมาณการต้นทุนโครงการใหม่,
--         SUM(c.[Total budget]) AS Sum_Total_budget,
--         SUM(c.[Actual]) AS Sum_Actual
--         -- SUM(c.[Diff]) AS Sum_Diff
-- 	FROM #CombineTable c
-- 	GROUP BY c.[No.],c.yearMonth, c.Month, c.[DateDetail]
-- ) c

/******************** Temp #Variant ********************/
--   IF OBJECT_ID(N'tempdb..#Variant', N'U') IS NOT NULL
--     BEGIN
--         DROP TABLE #Variant;
--     END;
-- SELECT *
-- INTO #Variant
-- FROM (
-- 	SELECT 
-- 		c.[No.]
-- 		,c.GroupType
-- 		,c.Detail
-- 		,FORMAT(DATEADD(MONTH,1,c.[DateDetail]),'yyyy-MM-dd','en') [NextDate]
-- 		,CAST(YEAR(DATEADD(MONTH,1,c.[DateDetail])) AS nvarchar) + '0' + CAST(MONTH(DATEADD(MONTH,1,c.[DateDetail])) AS nvarchar)  [NextYearMonth]--FORMAT(DATEADD(MONTH,1,[Date]),'yyyy-MM-dd','en')
-- 		,FORMAT(DATEADD(MONTH,1,c.[DateDetail]),'MMMM','th') [NextMonth]
-- 		,IIF(c.GroupType = 'Diff',c.Diff,NULL) [ผลต่าง+-]
-- 	FROM #CombineTable c

-- ) c
-- SELECT * FROM #Variant
-- SELECT [No.], GroupType, Detail, [Date], yearMonth, [Month], Diff FROM #CombineTable
-- /*********************************************************************/
/********************Test Temp****************************************/
-- select * from #Revenue
-- select * from #Estimatedcostsrequired
-- select * from #Estimatenewprojectcosts
-- select * from #SalaryRate 
-- select * from #FareRate
-- select * from #OnSiteDepreciation
-- select * from #ManagementWithOutVat
-- select * from #ManageVat
-- select * from #AdvertisingExpensesVat
-- select * from #Subcontract
-- select * from #Material
-- select * from #Accouctchart4Vat
-- select * from #Accouctchart4NoVat
/********************CORE ********************************************/

SELECT a.[No.],
		NULL Total,
		a.GroupType,
		a.Detail,
		-- a.[Date],
		a.yearMonth [Date],
		a.[Month],
		a.[ประมาณการรายได้],
		NULL [ผลต่าง+-],
		a.[ประมาณการต้นทุนที่ต้องใช้],
		a.[ประมาณการต้นทุนโครงการใหม่],
		a.[Total budget],
		a.Actual,
		(ISNULL(a.Actual,0) - ISNULL(a.[Total budget],0)) AS [Diff]
FROM #CombineTable a
-- LEFT JOIN #Variant v ON v.[No.] = a.[No.] AND v.GroupType = a.GroupType AND v.Detail = a.Detail AND v.NextDate = a.[DateDetail]
-- WHERE a.GroupType = 'Diff'
-- UNION ALL 
-- SELECT a.[No.],
-- 		a.Total,
-- 		NULL GroupType,
-- 		NULL Detail,
-- 		-- a.[Date],
-- 		a.[yearMonth],
-- 		a.[Month],
-- 		NULL [ประมาณการรายได้],
-- 		NULL [ผลต่าง+-],
-- 		NULL [ประมาณการต้นทุนที่ต้องใช้],
-- 		NULL [ประมาณการต้นทุนโครงการใหม่],
-- 		IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.Total = 'รวมรายได้', a.Sum_Total_budget,0) - IIF(a.Total = 'รวมค่าใช้จ่าย', a.Sum_Total_budget,0)),NULL) [Total budget],
-- 		IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.Total = 'รวมรายได้', a.Sum_Actual,0) - IIF(a.Total = 'รวมค่าใช้จ่าย', a.Sum_Actual,0)),NULL) Actual,
-- 		NULL Diff		
-- FROM #NetProfit a





-- Union All

-- select  IIF(a.รายได้ in ('รายได้','ค่าใช้จ่าย'),1,NULL) [Sort1]
-- 		,a.รายได้ [No.]
-- 		,NULL Sort2
-- 		,a.GroupType
-- 		,a.Detail	
-- 		,'Total' Date
-- 		,'Total' [Month]
-- 		-- ,NULL [RD]
-- 		-- ,NULL [MTP]
-- 		-- ,NULL [Diff.1]
-- 		,IIF(a.GroupType = 'ประมาณการรายได้',sum(a.Amount),NULL) [ประมาณการรายได้]
-- 		,0.00 [ผลต่าง+-]
-- 		,IIF(a.GroupType = 'ประมาณการต้นทุนที่ต้องใช้',sum(a.Amount),NULL) [ประมาณการต้นทุนที่ต้องใช้]
-- 		,IIF(a.GroupType = 'ประมาณการต้นทุนโครงการใหม่',sum(a.Amount),NULL) [ประมาณการต้นทุนโครงการใหม่]
-- 		,IIF(a.GroupType = 'ประมาณการSum',sum(a.Amount),IIF(a.GroupType = 'ประมาณการรายได้',sum(a.Amount),NULL)) [Total budget]
-- 		,IIF(a.GroupType = 'Actual',sum(a.Amount),NULL) [Actual]
-- 		,IIF(a.GroupType = 'Diff',sum(a.Amount),NULL)   [Diff]
-- from(
-- 			select * from #Revenue
-- 		union all 
-- 			select * from #Estimatedcostsrequired
-- 		union all 
-- 			select * from #Estimatenewprojectcosts
-- 		union all
-- 			select 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
-- 					,'3' Sort
-- 					,'ประมาณการSum' [GroupType]
-- 					,isnull(er.Detail,ec.Detail) [Detail]
-- 					,isnull(er.Date,ec.Date) [Date]
-- 					,(isnull(er.Amount,0) + isnull(ec.Amount,0)) [Amount]
-- 			from #Estimatedcostsrequired er
-- 			full join #Estimatenewprojectcosts ec on  er.Detail = ec.Detail and er.Date = ec.Date
-- 		union all 
-- 			select * from #Material
-- 		union all 
-- 			select * from #Subcontract
-- 		union all 
-- 			select * from #SalaryRate
-- 		union all 
-- 			select * from #OnSiteDepreciation
-- 		union all 
-- 			select * from #FareRate
-- 		union all 
-- 			select * from #AdvertisingExpensesVat
-- 		union all 
-- 			select mv.ค่าใช้จ่าย,mv.Sort,mv.GroupType,mv.Detail
-- 			,mv.Date
-- 			,isnull(mv.AmtManageVat,0) 
-- 				- (isnull(sr.AmtSalaryRate,0) 
-- 				+ isnull(fr.AmtFareRate,0) 
-- 				+ isnull(od.AmtOnSiteDepreciation,0) 
-- 				+ isnull(mov.AmtManagementWithOutVat,0) 
-- 				+ isnull(ae.AmtAdvertisingExpensesVat,0)) [AmtManageVat]
-- 			from #SalaryRate sr
-- 			left join #FareRate fr on sr.Date = fr.Date
-- 			left join #OnSiteDepreciation od on sr.Date = od.Date
-- 			left join #ManagementWithOutVat mov on sr.Date = mov.Date
-- 			left join #ManageVat mv on sr.Date = mv.Date
-- 			left join #AdvertisingExpensesVat ae on sr.Date = ae.Date
-- 		union all 
-- 			select * from #ManagementWithOutVat
-- 		union all
-- 			select * from #Accouctchart4Vat
-- 		union all
-- 			select * from #Accouctchart4NoVat
-- 		union all
-- 			select  'รายได้' [รายได้]
-- 					,'3' Sort
-- 					,'Diff' [GroupType]	
-- 					,r.Detail
-- 					,r.Date
-- 					,case when r.Detail = '1.01 ประมาณการรายได้' then isnull(sum(r.Amount),0) - isnull(sum(v.AmtMaterial),0) --[AmtMaterial]
-- 						  when r.Detail = '1.02 Vatขาย' then isnull(sum(r.Amount),0) - isnull(sum(nv.AmtMaterial),0)
-- 					 end [AmtMaterial]
-- 			from #Revenue r
-- 			left join #Accouctchart4Vat v on r.Detail = v.Detail and r.Date = v.Date
-- 			left join #Accouctchart4NoVat nv on r.Detail = nv.Detail and r.Date = nv.Date
-- 			group by r.Detail,r.Date
-- 			union all 

-- 			select 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
-- 					,'3' Sort
-- 					,'Diff' [GroupType]
-- 					,isnull(er.Detail,ec.Detail) [Detail]
-- 					,isnull(er.Date,ec.Date) [Date]
-- 					,case when er.Detail = '2.01 ค่าของมี Vat' or ec.Detail = '2.01 ค่าของมี Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(m.AmtMaterial),0) 
-- 						  when er.Detail = '2.02 ค่าของไม่มี Vat' or ec.Detail = '2.02 ค่าของไม่มี Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(m.AmtMaterial),0)
-- 						  when er.Detail = '2.03 ค่าแรงมี Vat' or ec.Detail = '2.03 ค่าแรงมี Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(s.AmtSubcontract),0)
-- 						  when er.Detail = '2.04 ค่าแรงไม่มี Vat' or ec.Detail = '2.04 ค่าแรงไม่มี Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(s.AmtSubcontract),0)
-- 						  when er.Detail = '2.05 เงินเดือน ปันส่วน' or ec.Detail = '2.05 เงินเดือน ปันส่วน' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(sr.AmtSalaryRate),0)
-- 						  when er.Detail = '2.06 ค่าเสื่อมราคาหน้างาน' or ec.Detail = '2.06 ค่าเสื่อมราคาหน้างาน' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(od.AmtOnSiteDepreciation),0)
-- 						  when er.Detail = '2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' or ec.Detail = '2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(fr.AmtFareRate),0)
-- 						  when er.Detail = '2.08 ค่าโฆษณา Vat' or ec.Detail = '2.08 ค่าโฆษณา Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(av.AmtAdvertisingExpensesVat),0)
-- 						  when er.Detail = '2.09 บริหาร Vat' or ec.Detail = '2.09 บริหาร Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(mt.AmtManageVat),0)
-- 						  when er.Detail = '2.10 บริหารไม่มี Vat' or ec.Detail = '2.10 บริหารไม่มี Vat' then (isnull(sum(er.Amount),0) + isnull(sum(ec.Amount),0)) - isnull(sum(mn.AmtManagementWithOutVat),0)
-- 					 end [Amount]
-- 			from #Estimatedcostsrequired er
-- 			full join #Estimatenewprojectcosts ec on  er.Detail = ec.Detail and er.Date = ec.Date
-- 			left join #Material m on er.Detail = m.Detail 
-- 			left join #Subcontract s on er.Detail = s.Detail 
-- 			left join #SalaryRate sr on er.Detail = sr.Detail
-- 			left join #OnSiteDepreciation od on er.Detail = od.Detail
-- 			left join #FareRate fr on er.Detail = fr.Detail
-- 			left join #AdvertisingExpensesVat av on er.Detail = av.Detail
-- 			left join (select mv.ค่าใช้จ่าย,mv.Sort,mv.GroupType,mv.Detail
-- 						,mv.Date
-- 						,isnull(mv.AmtManageVat,0) 
-- 							- (isnull(sr.AmtSalaryRate,0) 
-- 							+ isnull(fr.AmtFareRate,0) 
-- 							+ isnull(od.AmtOnSiteDepreciation,0) 
-- 							+ isnull(mov.AmtManagementWithOutVat,0) 
-- 							+ isnull(ae.AmtAdvertisingExpensesVat,0)) [AmtManageVat]
-- 						from #SalaryRate sr
-- 						left join #FareRate fr on sr.Date = fr.Date
-- 						left join #OnSiteDepreciation od on sr.Date = od.Date
-- 						left join #ManagementWithOutVat mov on sr.Date = mov.Date
-- 						left join #ManageVat mv on sr.Date = mv.Date
-- 						left join #AdvertisingExpensesVat ae on sr.Date = ae.Date
-- 						) mt on er.Detail = mt.Detail
-- 			left join #ManagementWithOutVat mn on er.Detail = mn.Detail
-- 			group by er.Detail,er.Date,ec.Detail,ec.Date
-- ) a


/************************************************************************************************************************************************************************/

/*2-Filter*/
select  CONCAT('Date : ', FORMAT(@startDate, 'dd/MM/yyyy'), ' To ', FORMAT(@endDate, 'dd/MM/yyyy')) Date
		,(SELECT dbo.GROUP_CONCAT(Name)  FROM dbo.Organizations WHERE Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) Project
		,@SalaryRate [SalaryRate]
		,@FareRate [FareRate]
--/************************************************************************************************************************************************************************/

/*3-Company*/
select * from fn_CompanyInfoTable(@ProjectId)


/*Drop Temp*/
 IF OBJECT_ID(N'tempdb..#temporg', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #temporg;
    END;

 IF OBJECT_ID(N'tempdb..#Revenue', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Revenue;
    END;

 IF OBJECT_ID(N'tempdb..#Estimatedcostsrequired', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Estimatedcostsrequired;
    END;

 IF OBJECT_ID(N'tempdb..#Estimatenewprojectcosts', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Estimatenewprojectcosts;
    END;

  IF OBJECT_ID(N'tempdb..#SalaryRate', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #SalaryRate;
    END;


 IF OBJECT_ID(N'tempdb..#FareRate', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #FareRate;
    END;

 IF OBJECT_ID(N'tempdb..#OnSiteDepreciation', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #OnSiteDepreciation;
    END;

 IF OBJECT_ID(N'tempdb..#ManagementWithOutVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManagementWithOutVat;
    END;

 IF OBJECT_ID(N'tempdb..#ManageVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManageVat;
    END;

 IF OBJECT_ID(N'tempdb..#AdvertisingExpensesVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #AdvertisingExpensesVat;
    END;

 IF OBJECT_ID(N'tempdb..#Subcontract', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Subcontract;
    END;

 IF OBJECT_ID(N'tempdb..#Material', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Material;
    END;

  IF OBJECT_ID(N'tempdb..#Accouctchart4Vat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Vat;
    END;

  IF OBJECT_ID(N'tempdb..#Accouctchart4NoVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4NoVat;
    END;
