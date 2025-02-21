/*==> Ref:d:\programmanee\prototype-thsd\notpublish\customprinting\reportcommands\mtp101_tax_planning_report.sql ==>*/
 

DECLARE @p0 DATE = '2024-01-01'
DECLARE @p1 DATE = '2024-12-31'
DECLARE @p2 NVARCHAR(MAX)  = '1' 
DECLARE @p3 NVARCHAR(10) = '1' /*0.51*/
DECLARE @p4 NVARCHAR(10)  = '1' /*0.80*/


DECLARE @startDate DATE = @p0
DECLARE @endDate DATE = @p1
DECLARE @ProjectId NVARCHAR(MAX) = @p2
DECLARE @SalaryRate NVARCHAR(10) = @p3
DECLARE @FareRate NVARCHAR(10)  = @p4

SET ANSI_WARNINGS OFF
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
		,CASE WHEN a.Description LIKE 'ประมาณการรายได้' THEN '1.01 ประมาณการรายได้' 
            WHEN a.Description LIKE 'Vat' THEN '1.02 Vatขาย' 
            -- WHEN a.Description LIKE 'ค่าของมี Vat' THEN '2.01 ค่าของมี Vat' 
            -- WHEN a.Description LIKE 'ค่าของไม่มี Vat' THEN '2.02 ค่าของไม่มี Vat' 
            -- WHEN a.Description LIKE 'ค่าของโครงการใหม่ มี Vat' THEN '2.03 ค่าของโครงการใหม่ มี Vat' 
            -- WHEN a.Description LIKE 'ค่าของโครงการใหม่ ไม่มี Vat' THEN '2.04 ค่าของโครงการใหม่ ไม่มี Vat' 
            -- WHEN a.Description LIKE 'ค่าแรงมี Vat' THEN '2.05 ค่าแรงมี Vat' 
            -- WHEN a.Description LIKE 'ค่าแรงไม่มี Vat' THEN '2.06 ค่าแรงไม่มี Vat' 
            -- WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ มี Vat' THEN '2.07 ค่าแรงโครงการใหม่ มี Vat' 
            -- WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ ไม่มี Vat' THEN '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat' 
            -- WHEN a.Description LIKE 'เงินเดือน ปันส่วน' THEN '2.09 เงินเดือน ปันส่วน' 
            -- WHEN a.Description LIKE 'ค่าเสื่อมราคาหน้างาน' THEN '2.10 ค่าเสื่อมราคาหน้างาน' 
            -- WHEN a.Description LIKE 'ค่าเดินทาง+น้ำมัน ปันส่วน Vat' THEN '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' 
            -- WHEN a.Description LIKE 'ค่าโฆษณา Vat' THEN '2.12 ค่าโฆษณา Vat' 
            -- WHEN a.Description LIKE 'บริหาร Vat' THEN '2.13 บริหาร Vat' 
            -- WHEN a.Description LIKE 'บริหารไม่มี Vat' THEN '2.14 บริหารไม่มี Vat' 
        END [Detail]
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
			where r.SubDocTypeId = '646'  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2051)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
			UNION ALL
			select r.LocationId
					,r.LocationCode
					,r.LocationName
					,r.Date
					,rl.Description
					,rl.Amount
					,rl.SystemCategoryId
			from Requests r
			left join RequestLines rl on r.Id = rl.RequestId
			where r.SubDocTypeId = '646'  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 123
					
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
		,CASE WHEN a.Description LIKE 'ประมาณการรายได้' THEN '1.01 ประมาณการรายได้' 
            WHEN a.Description LIKE 'Vatขาย' THEN '1.02 Vatขาย' 
            WHEN a.Description LIKE 'ค่าของมี Vat' THEN '2.01 ค่าของมี Vat' 
            WHEN a.Description LIKE 'ค่าของไม่มี Vat' THEN '2.02 ค่าของไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าของโครงการใหม่ มี Vat' THEN '2.03 ค่าของโครงการใหม่ มี Vat' 
            WHEN a.Description LIKE 'ค่าของโครงการใหม่ ไม่มี Vat' THEN '2.04 ค่าของโครงการใหม่ ไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงมี Vat' THEN '2.05 ค่าแรงมี Vat' 
            WHEN a.Description LIKE 'ค่าแรงไม่มี Vat' THEN '2.06 ค่าแรงไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ มี Vat' THEN '2.07 ค่าแรงโครงการใหม่ มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ ไม่มี Vat' THEN '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat' 
            WHEN a.Description LIKE 'เงินเดือน ปันส่วน' THEN '2.09 เงินเดือน ปันส่วน' 
            WHEN a.Description LIKE 'ค่าเสื่อมราคาหน้างาน' THEN '2.10 ค่าเสื่อมราคาหน้างาน' 
            WHEN a.Description LIKE 'ค่าเดินทาง+น้ำมัน ปันส่วน Vat' THEN '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' 
            WHEN a.Description LIKE 'ค่าโฆษณา Vat' THEN '2.12 ค่าโฆษณา Vat' 
            WHEN a.Description LIKE 'บริหาร Vat' THEN '2.13 บริหาร Vat' 
            WHEN a.Description LIKE 'บริหารไม่มี Vat' THEN '2.14 บริหารไม่มี Vat' 
        END [Detail]
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
			where r.SubDocTypeId in (647)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2052,2053,2054,2055,2056,20557,2058,2059,2060,2061,2062) /*ขึ้นตัวจริงต้องเช็คอีกที*/
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
		,CASE WHEN a.Description LIKE 'ประมาณการรายได้' THEN '1.01 ประมาณการรายได้' 
            WHEN a.Description LIKE 'Vatขาย' THEN '1.02 Vatขาย' 
            WHEN a.Description LIKE 'ค่าของมี Vat' THEN '2.01 ค่าของมี Vat' 
            WHEN a.Description LIKE 'ค่าของไม่มี Vat' THEN '2.02 ค่าของไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าของโครงการใหม่ มี Vat' THEN '2.03 ค่าของโครงการใหม่ มี Vat' 
            WHEN a.Description LIKE 'ค่าของโครงการใหม่ ไม่มี Vat' THEN '2.04 ค่าของโครงการใหม่ ไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงมี Vat' THEN '2.05 ค่าแรงมี Vat' 
            WHEN a.Description LIKE 'ค่าแรงไม่มี Vat' THEN '2.06 ค่าแรงไม่มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ มี Vat' THEN '2.07 ค่าแรงโครงการใหม่ มี Vat' 
            WHEN a.Description LIKE 'ค่าแรงโครงการใหม่ ไม่มี Vat' THEN '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat' 
            WHEN a.Description LIKE 'เงินเดือน ปันส่วน' THEN '2.09 เงินเดือน ปันส่วน' 
            WHEN a.Description LIKE 'ค่าเสื่อมราคาหน้างาน' THEN '2.10 ค่าเสื่อมราคาหน้างาน' 
            WHEN a.Description LIKE 'ค่าเดินทาง+น้ำมัน ปันส่วน Vat' THEN '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' 
            WHEN a.Description LIKE 'ค่าโฆษณา Vat' THEN '2.12 ค่าโฆษณา Vat' 
            WHEN a.Description LIKE 'บริหาร Vat' THEN '2.13 บริหาร Vat' 
            WHEN a.Description LIKE 'บริหารไม่มี Vat' THEN '2.14 บริหารไม่มี Vat' 
        END [Detail]
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
			where r.SubDocTypeId in (648)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
					and (r.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (r.LocationId in (select Id from #temporg) or @ProjectId is NULL)
					and r.DocStatus not in (-1)
					and rl.SystemCategoryId = 99
					and rl.ItemMetaId in (2052,2053,2054,2055,2056,20557,2058,2059,2060,2061,2062,2063,2064,2065,2066)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
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
		,'2.09 เงินเดือน ปันส่วน' [Detail]
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
		 ,'2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' [Detail]
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
		,'2.10 ค่าเสื่อมราคาหน้างาน' [Detail]
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
		,'2.14 บริหารไม่มี Vat' [Detail]
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
		,'2.13 บริหาร Vat' [Detail]
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
		,'2.12 ค่าโฆษณา Vat' [Detail]
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
		,Case when a.vat = 'Vat' then '2.05 ค่าแรงมี Vat'
				else '2.06 ค่าแรงไม่มี Vat'
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


select	jv.Amount
		,j.[Date]--FORMAT(j.Date ,'yyyyMM')  [Date]
		,j.OrgCode
		,Case when i.SystemCategoryId in (123,129) then 'Vat'
				else 'NoVat'
			end vat
		,j.MadeByDocCode
		,jv.AccountCode
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
		,/*Case when a.vat = 'Vat' then '1.01 ประมาณการรายได้'
				else '1.02 Vatขาย'--'รายได้ผัง4ไม่มี Vat'
			end*/'1.01 ประมาณการรายได้' [Detail]
		,a.Date
		,SUM(CASE WHEN a.isDebit = 0 THEN a.Amount ELSE 0 END) - SUM(CASE WHEN a.isDebit = 1 THEN a.Amount ELSE 0 END) [AmtMaterial]
		-- ,a.AccountCode 
Into #Accouctchart4Vat
from(
select DISTINCT s.Amount
				,s.DocDate [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,s.DocType
				,s.DocCode,s.isDebit,s.AccountCode
from AcctElementSets s
where s.AccountCode LIKE '4%'/*IN (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708)*/
		-- and s.isDebit = 0
		and (s.DocDate BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (s.OrgId in (select Id from #temporg) or @ProjectId is NULL)
		--and i.SystemCategoryId in (123,129)
)a group by a.Date,a.isDebit/* ,a.AccountCode */

/******************** Temp #Accouctchart4NoVat  รายได้ผัง4ไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#Accouctchart4NoVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4NoVat;
    END;

/*รายได้ผัง4ไม่มี Vat*/
select	'รายได้' [รายได้]
		,'3' Sort
		,'Actual' [GroupType]	
		,/* Case when a.vat = 'Vat' then 'รายได้ผัง4 Vat'
				else '1.02 Vatขาย'
			end  */'1.02 Vatขาย'[Detail]
		,a.Date
		,isnull(sum(a.Amount),0) [AmtMaterial]/* , a.AcctCode */
Into #Accouctchart4NoVat
from(
select CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE ISNULL(s.Amount,jl.Amount)*-1 END [Amount]
				,ISNULL(s.DocDate,j.[Date]) [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,s.DocType
				,s.DocCode,ISNULL(s.AccountCode,jl.AccountCode) [AcctCode]
FROM	    dbo.JVLines jl WITH (nolock)
			   INNER JOIN dbo.JournalVouchers j WITH (NOLOCK) ON jl.JournalVoucherId = j.Id AND ISNULL(j.DocStatus,0) <> -1									
			   LEFT JOIN dbo.GeneralAccountEntities ga WITH (NOLOCK) ON ga.EnumKey = jl.GeneralAccount
			   LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON IIF(ISNULL(jl.OrgId,0) IN (0,-1),j.OrgId,jl.OrgId) = o.Id
			   LEFT JOIN dbo.AcctElementSets s WITH (NOLOCK) ON s.JVLineId = jl.Id --AND jl.MadeByDocTypeId = 149
where jl.AccountCode LIKE '21250100'/* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) */
		-- and s.isDebit = 0
		and (CONVERT(DATE,ISNULL(NULLIF(s.DocDate,''),j.Date)) BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (ISNULL(s.OrgId,j.OrgId) in (select Id from #temporg) or @ProjectId is NULL) 
		AND s.DocType IS NOT NULL
		-- and i.SystemCategoryId not in (123,129)
)a group by a.Date/* ,a.AcctCode */

/*********************************************************************/
/********************Combine Temp****************************************/
  IF OBJECT_ID(N'tempdb..#CombineTable', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #CombineTable;
    END;
SELECT *
		-- ,CAST(YEAR(a.NextDate) AS nvarchar) + '-0' + CAST(MONTH(a.NextDate) AS nvarchar) [NextYearMonth]
		-- ,FORMAT(a.NextDate,'MMMM','th') [NextMonth]
		,(ISNULL(a.Actual,0) - ISNULL(a.[Total budget],0)) AS [Diff]
		
INTO #CombineTable
FROM 
(
	select  --IIF(a.รายได้ in ('รายได้'),1,0) [Sort1]
		a.รายได้ [No.]
		-- ,a.Sort [Sort2]
		,CASE WHEN a.Detail IN ('2.01 ค่าของมี Vat', '2.02 ค่าของไม่มี Vat', '2.03 ค่าของโครงการใหม่ มี Vat', '2.04 ค่าของโครงการใหม่ ไม่มี Vat') THEN 'ค่าของ'
		WHEN a.Detail IN ('2.05 ค่าแรงมี Vat', '2.06 ค่าแรงไม่มี Vat', '2.07 ค่าแรงโครงการใหม่ มี Vat', '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat') THEN 'ค่าแรง'
		WHEN a.Detail IN ('2.09 เงินเดือน ปันส่วน', '2.10 ค่าเสื่อมราคาหน้างาน', '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat') THEN 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง'
		WHEN a.Detail IN ('2.12 ค่าโฆษณา Vat', '2.13 บริหาร Vat', '2.14 บริหารไม่มี Vat') THEN 'บริหาร'
		ELSE RIGHT(a.Detail,LEN(a.Detail) - 5)
		END [type]
		,CASE 
  		WHEN a.Detail IN ('1.01 ประมาณการรายได้') THEN 0
		WHEN a.Detail IN ('1.02 Vatขาย') THEN 0.5
  		WHEN a.Detail IN ('2.01 ค่าของมี Vat', '2.02 ค่าของไม่มี Vat', '2.03 ค่าของโครงการใหม่ มี Vat', '2.04 ค่าของโครงการใหม่ ไม่มี Vat') THEN 1
		WHEN a.Detail IN ('2.05 ค่าแรงมี Vat', '2.06 ค่าแรงไม่มี Vat', '2.07 ค่าแรงโครงการใหม่ มี Vat', '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat') THEN 2
		WHEN a.Detail IN ('2.09 เงินเดือน ปันส่วน', '2.10 ค่าเสื่อมราคาหน้างาน', '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat') THEN 3
		WHEN a.Detail IN ('2.12 ค่าโฆษณา Vat', '2.13 บริหาร Vat', '2.14 บริหารไม่มี Vat') THEN 4
		ELSE 0
		END [SortType]
		,a.GroupType
		,a.Detail
		,FORMAT(a.[Date], 'yyyy-MM-dd','en') [DateDetail]
		,FORMAT(a.[Date], 'yyyy-MM','en') [yearMonth]
		,FORMAT(a.[Date],'MMMM','th') [Month]
		-- ,NULL [Diff.1]
		,IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL) [ประมาณการรายได้]
		-- ,NULL [ผลต่าง+-]
		,IIF(a.GroupType = 'ประมาณการต้นทุนที่ต้องใช้',a.Amount,NULL) [ประมาณการต้นทุนที่ต้องใช้]
		,IIF(a.GroupType = 'ประมาณการต้นทุนโครงการใหม่',a.Amount,NULL) [ประมาณการต้นทุนโครงการใหม่]
		,IIF(a.GroupType = 'ประมาณการSum',a.Amount,IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL)) [Total budget]
		,IIF(a.GroupType = 'Actual',a.Amount,NULL) [Actual]
		,DATEADD(MONTH,1,FORMAT(a.[Date], 'yyyy-MM-dd','en')) [NextDate]
		-- ,CAST(YEAR(DATEADD(MONTH,1,c.[DateDetail])) AS nvarchar) + '-0' + CAST(MONTH(DATEADD(MONTH,1,c.[DateDetail])) AS nvarchar)  [NextYearMonth]--FORMAT(DATEADD(MONTH,1,[Date]),'yyyy-MM-dd','en')
		-- ,FORMAT(DATEADD(MONTH,1,c.[DateDetail]),'MMMM','th') [NextMonth]
		-- ,IIF(a.GroupType = 'Diff',a.Amount,NULL)   [Diff]
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

	) a		
Group by a.รายได้,a.GroupType,a.Detail,a.Sort,a.[Date],a.Amount
) a
-- SELECT * FROM #CombineTable
/******************** Temp #Variant ********************/
  IF OBJECT_ID(N'tempdb..#Variant', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Variant;
    END;
SELECT c.Detail, c.NextYearMonth, c.NextMonth, SUM(c.tb) tb, SUM(c.a) a, SUM(c.d) d
INTO #Variant
FROM (
	SELECT 
		c.Detail
		-- ,FORMAT(DATEADD(MONTH,1,c.[DateDetail]),'yyyy-MM-dd','en') [NextDate]
		,FORMAT(DATEADD(MONTH,1,c.[DateDetail]), 'yyyy-MM','en') [NextYearMonth]--FORMAT(DATEADD(MONTH,1,[Date]),'yyyy-MM-dd','en')
		,FORMAT(DATEADD(MONTH,1,c.[DateDetail]),'MMMM','th') [NextMonth]
		,SUM(c.[Total budget]) tb
		,SUM(c.Actual) a
		,SUM(c.Diff) d
	FROM #CombineTable c
	GROUP BY  c.Detail, c.yearMonth , c.[Month], c.DateDetail
) c 
GROUP BY  c.Detail, c.NextYearMonth , c.NextMonth
-- SELECT * FROM #Variant
/******************** Temp #VATprice ********************/
  IF OBJECT_ID(N'tempdb..#VATprice', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #VATprice;
    END;

SELECT v.[No.]
		,v.VATDetail
		,v.yearMonth
		,v.[Month]
		,SUM(v.[STotal Budget]) [Total Budget] 
		,SUM(v.SActual) [Actual] 
INTO #VATprice
FROM (
	SELECT 	a.[No.]
			,IIF(LEFT(a.Detail, 4) IN ('2.01','2.05','2.09','2.10','2.11','2.12','2.13'), 'VAT ซื้อ', IIF(LEFT(a.Detail, 4) IN ('2.03', '2.07'), 'Vat ซื้อ โครงการใหม่', 'VAT ขาย')) [VATDetail]
			,a.yearMonth
			,a.[Month]
			,a.[STotal Budget]
			,a.SActual
	FROM (
		SELECT 'ภาษีมูลค่าเพิ่ม' [No.],
		a.Detail,
		a.[yearMonth],
		a.[Month],
		a.[Total budget] [STotal Budget],
		a.Actual [SActual]
	FROM #CombineTable a
	WHERE a.Detail IN ( '1.02 Vatขาย', '2.01 ค่าของมี Vat', '2.03 ค่าของโครงการใหม่ มี Vat', '2.05 ค่าแรงมี Vat', '2.07 ค่าแรงโครงการใหม่ มี Vat', '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat', '2.12 ค่าโฆษณา Vat', '2.13 บริหาร Vat')
	) a
		-- GROUP BY a.[No.], a.Detail, a.yearMonth, a.[Month], a.[STotal Budget], a.SActual

) v 
GROUP BY v.[No.], v.VATDetail, v.yearMonth, v.[Month]

/******************** Temp #TotalCol ********************/
DECLARE @profit DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'รายได้' AND c.[type] = 'ประมาณการรายได้')
DECLARE @ProductActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ')
DECLARE @WorkerActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง')
DECLARE @OtherActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง')
DECLARE @ManagementActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร')

  IF OBJECT_ID(N'tempdb..#TotalCol', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #TotalCol;
    END;
SELECT c.[No.]
		,c.[type]
        ,c.SortType
		,c.Detail
		,c.TotalDate
		,c.TotalMonth
		,c.RD
		,c.MTP
		,ISNULL(c.MTP - c.RD, NULL) [Diff (MTP - RD)]
		,c.[ประมาณการรายได้]
		,c.[ประมาณการต้นทุนที่ต้องใช้]
		,c.[ประมาณการต้นทุนโครงการใหม่]
		,c.[Total budget]
		,c.Actual
		,c.Diff
INTO #TotalCol
FROM (
	SELECT c.[No.]
			,c.[type]
            ,c.SortType
			,c.Detail
			-- ,c.DateDetail
			,'01' [TotalDate]
			,'Total' [TotalMonth]
			,CASE WHEN (c.[No.] = 'รายได้' AND c.[type] = 'ประมาณการรายได้') THEN CAST('1' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.01 ค่าของมี Vat') THEN CAST('0.5' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.03 ค่าแรงมี Vat') THEN CAST('0.34' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.05 เงินเดือน ปันส่วน') THEN CAST('0.055' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.08 ค่าโฆษณา Vat') THEN CAST('0.075' AS DEC(10, 4))
				ELSE NULL
			END [RD]
			,CASE WHEN (c.[No.] = 'รายได้' AND c.[type] = 'ประมาณการรายได้') THEN '1'
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.01 ค่าของมี Vat') THEN (@ProductActual * 0.01 / @profit) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.03 ค่าแรงมี Vat') THEN (@WorkerActual * 0.01 / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.05 เงินเดือน ปันส่วน') THEN (@OtherActual * 0.01 / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.08 ค่าโฆษณา Vat') THEN (@ManagementActual * 0.01 / @profit)
			ELSE NULL
			END [MTP]
			,SUM(c.[ประมาณการรายได้]) [ประมาณการรายได้]
			,SUM(c.[ประมาณการต้นทุนที่ต้องใช้]) [ประมาณการต้นทุนที่ต้องใช้]
			,SUM(c.[ประมาณการต้นทุนโครงการใหม่]) [ประมาณการต้นทุนโครงการใหม่]
			,SUM(c.[Total budget]) [Total budget]
			,SUM(c.Actual) [Actual]
			,SUM(c.Diff) [Diff]
	FROM #CombineTable c
	GROUP BY c.[No.], c.Detail, c.[type],c.SortType--, c.yearMonth, c.DateDetail
) c


/******************** Temp #NetProfit********************/
  IF OBJECT_ID(N'tempdb..#NetProfit', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #NetProfit;
    END;

SELECT *
INTO #NetProfit
FROM (
	
	SELECT	'กำไรก่อนปรับปรุง' [No.],
		CASE WHEN c.[No.] LIKE 'ค่าใช้จ่าย' THEN 'รวมค่าใช้จ่าย'
			WHEN c.[No.] LIKE 'รายได้' THEN 'รวมรายได้'
		END [GroupType],
		c.[Date],
		c.Month,
		1 - IIF(c.[No.] = 'ค่าใช้จ่าย', SUM(c.RD), NULL) [SumRD],
		1 - IIF(c.[No.] = 'ค่าใช้จ่าย', SUM(c.MTP), NULL) [SumMTP],
		IIF(c.[No.] = 'ค่าใช้จ่าย',SUM(c.[Diff (MTP - RD)]),NULL) [Sum MTP - RD],
		-- -- SUM(c.[ประมาณการรายได้]) AS Sum_ประมาณการรายได้,
        -- -- SUM(c.[ประมาณการต้นทุนที่ต้องใช้]) AS Sum_ประมาณการต้นทุนที่ต้องใช้,
        -- -- SUM(c.[ประมาณการต้นทุนโครงการใหม่]) AS Sum_ประมาณการต้นทุนโครงการใหม่,
        SUM(c.[Total budget]) AS Sum_Total_budget,
        SUM(c.[Actual]) AS Sum_Actual
        -- -- SUM(c.[Diff]) AS Sum_Diff
	FROM (
				SELECT a.[No.],
				a.[type] [Total],
				a.GroupType,
				a.Detail,
				a.yearMonth [Date],
				a.[Month],
				NULL [RD],
				NULL [MTP],
				NULL [Diff (MTP - RD)],
				a.[Total budget],
				a.Actual,
				a.Diff
		FROM #CombineTable a
		UNION ALL 
		SELECT t.[No.]
				,t.[type] [Total]
				,'Total' [GroupType]
				,t.Detail
				,t.TotalDate [Date]
				,t.TotalMonth [Month]
				,t.RD
				,t.MTP
				,t.[Diff (MTP - RD)]
				,t.[Total budget]
				,t.Actual
				,t.Diff
		FROM #TotalCol t
	) c
	GROUP BY c.[No.],c.[Date], c.Month
) c
-- SELECT * FROM #NetProfit
/*********************************************************************/
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
SELECT  a.[No.],
		a.[Total],
		a.SortType,
		a.GroupType,
		a.Detail,
		a.[var_detail],
		a.[Date],
		a.[Month],
		a.[RD (%)],
		a.[MTP (%)],
		a.[Diff (MTP - RD)],
		a.[ประมาณการรายได้],
		a.[ผลต่าง+-], 
		a.[ประมาณการต้นทุนที่ต้องใช้],
		a.[ประมาณการต้นทุนโครงการใหม่],
		ISNULL(a.[Total budget],0) + ISNULL(a.[ผลต่าง+-],0) [Total budget], --เอาอันนี้รวมกับใน total budget
		a.Actual,
		a.Diff
FROM (SELECT a.[No.],
		a.[type] [Total],
		a.SortType,
		a.GroupType,
		a.Detail,
		v.Detail [var_detail],
		a.yearMonth [Date],
		a.[Month],
		NULL [RD (%)],
		NULL [MTP (%)],
		NULL [Diff (MTP - RD)],
		a.[ประมาณการรายได้],
		IIF(ROW_NUMBER() OVER (PARTITION BY a.Detail, a.Month ORDER BY a.yearMonth) = 1, v.d, NULL) [ผลต่าง+-], --เอาอันนี้รวมกับใน total budget
		a.[ประมาณการต้นทุนที่ต้องใช้],
		a.[ประมาณการต้นทุนโครงการใหม่],
		a.[Total budget],
		a.Actual,
		a.Diff
FROM #CombineTable a 
LEFT JOIN #Variant v ON v.Detail = a.Detail AND v.NextYearMonth = a.yearMonth AND v.NextMonth = a.[Month]) a
UNION ALL 
SELECT t.[No.]
		,t.[type] [Total]
        ,t.SortType
		,'Total' [GroupType]
		,t.Detail
		,NULL [var_detail]
		,t.TotalDate [Date]
		,t.TotalMonth [Month]
		,t.RD [RD (%)]
		,t.MTP [MTP (%)]
		,t.[Diff (MTP - RD)] [Diff (MTP - RD)]
		,t.[ประมาณการรายได้]
		,NULL [ผลต่าง+-]
		,t.[ประมาณการต้นทุนที่ต้องใช้] 
		,t.[ประมาณการต้นทุนโครงการใหม่]
		,t.[Total budget]
		,t.Actual
		,t.Diff
FROM #TotalCol t
UNION ALL 
SELECT a.[No.],
		NULL Total,
        99 SortType,
		a.GroupType,
		NULL Detail,
		NULL [var_detail],
		a.[Date],
		a.[Month],
		a.SumRD [RD (%)],
		a.SumMTP [MTP (%)],
		a.[Sum MTP - RD] [Diff (MTP - RD)],
		NULL [ประมาณการรายได้],
		NULL [ผลต่าง+-],
		NULL [ประมาณการต้นทุนที่ต้องใช้],
		NULL [ประมาณการต้นทุนโครงการใหม่],
		IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.GroupType = 'รวมรายได้', a.Sum_Total_budget,0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.Sum_Total_budget,0)),NULL) [Total budget],
		IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.GroupType = 'รวมรายได้', a.Sum_Actual,0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.Sum_Actual,0)),NULL) [Actual],
		NULL Diff		
FROM #NetProfit a


/************************************************************************************************************************************************************************/

/*2-Filter*/
select  CONCAT('Date : ', FORMAT(@startDate, 'dd/MM/yyyy'), ' To ', FORMAT(@endDate, 'dd/MM/yyyy')) Date
		,(SELECT dbo.GROUP_CONCAT(Name)  FROM dbo.Organizations WHERE Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) Project
		,@SalaryRate [SalaryRate]
		,@FareRate [FareRate]
--/************************************************************************************************************************************************************************/

/*3-Company*/
select * from fn_CompanyInfoTable(@ProjectId);

/*VAT*/
WITH SellVat AS (
	SELECT va.[No.]
		,va.VATDetail [Detail]
		,va.yearMonth
		,va.[Month]
		,va.[Total Budget]
		,va.Actual
	FROM #VATprice va
	WHERE va.VATDetail = 'VAT ขาย'
), BuyVat AS (
	SELECT va.[No.]
		,va.VATDetail [Detail]
		,va.yearMonth
		,va.[Month]
		,IIF(va.VATDetail = 'VAT ขาย',va.[Total Budget],va.[Total Budget] * 0.07) [Total Budget]
		,va.Actual [Actual]
	FROM #VATprice va
	WHERE va.VATDetail IN ('VAT ซื้อ', 'Vat ซื้อ โครงการใหม่')
), PreVat AS (
	SELECT a.[No.]
		,a.yearMonth
		,a.[Month]
		,'จ่ายภาษีมูลค่าเพิ่ม' [addDetail]
		,ISNULL(a.[Total Budget],0) - ISNULL(b.[Total Budget],0) [addTotal]
		,ISNULL(a.Actual,0) - ISNULL(b.Actual,0) [addActual]
FROM SellVat a
INNER JOIN BuyVat b
ON a.yearMonth = b.yearMonth
WHERE a.Detail = 'VAT ขาย' OR b.Detail = 'VAT ซื้อ'
), VatTotal AS (
	SELECT va.[No.]
		,va.VATDetail [Detail]
		,va.yearMonth [Date]
		,va.[Month]
		,IIF(va.VATDetail = 'VAT ขาย',va.[Total Budget],va.[Total Budget] * 0.07) [Total Budget]
		,va.Actual
		,(ISNULL(va.[Total budget],0) - ISNULL(va.Actual,0)) Diff	
FROM #VATprice va
UNION ALL
SELECT v.[No.]
		,v.addDetail [Detail]
		,v.yearMonth [Date]
		,v.[Month]
		,v.addTotal [Total Budget]
		,v.addActual [Actual]
		,(ISNULL(v.addTotal,0) - ISNULL(v.addActual,0)) Diff
FROM PreVat v
)

SELECT *
FROM (
	SELECT vt.[No.]
		,NULL Total
		,NULL GroupType
		,CASE WHEN vt.Detail LIKE 'VAT ซื้อ' THEN 1
				WHEN vt.Detail LIKE 'VAT ขาย' THEN 2
				WHEN vt.Detail LIKE 'จ่ายภาษีมูลค่าเพิ่ม' THEN 3
				WHEN vt.Detail LIKE 'VAT ซื้อ โครงการใหม่' THEN 4
		END Sort
		,vt.Detail
		,vt.[Date]
		,vt.[Month]
		,NULL [RD (%)]
		,NULL [MTP (%)]
		,NULL [Diff (MTP - RD)]
		,NULL [ประมาณการรายได้]
		,NULL [ผลต่าง+-]
		,NULL [ประมาณการต้นทุนที่ต้องใช้]
		,NULL [ประมาณการต้นทุนโครงการใหม่]
		,vt.[Total Budget]
		,vt.Actual
		,vt.Diff
		-- ,IIF(vt.Detail = 'VAT ขาย', vt.[Total Budget],vt.[Total Budget] * 0.07) [Total Budget]
		-- ,IIF(vt.Detail = 'VAT ขาย', vt.Actual,vt.Actual * 0.07) [Actual]
		-- ,IIF(vt.Detail = 'VAT ขาย', vt.Diff,vt.Diff * 0.07) [Diff]
FROM VatTotal vt
UNION ALL
SELECT vt.[No.]
		,NULL Total
		,NULL GroupType
		,CASE WHEN vt.Detail LIKE 'VAT ซื้อ' THEN 1
				WHEN vt.Detail LIKE 'VAT ขาย' THEN 2
				WHEN vt.Detail LIKE 'จ่ายภาษีมูลค่าเพิ่ม' THEN 3
				WHEN vt.Detail LIKE 'VAT ซื้อ โครงการใหม่' THEN 4
		END Sort
		,vt.Detail
		,'01' [Date]
		,'Total' [Month]
		,NULL [RD (%)]
		,NULL [MTP (%)]
		,NULL [Diff (MTP - RD)]
		,NULL [ประมาณการรายได้]
		,NULL [ผลต่าง+-]
		,NULL [ประมาณการต้นทุนที่ต้องใช้]
		,NULL [ประมาณการต้นทุนโครงการใหม่]
		,SUM(vt.[Total Budget]) [Total Budget]
		,SUM(vt.Actual) Actual
		,SUM(vt.Diff) Diff
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.[Total Budget]),SUM(vt.[Total Budget]) * 0.07) [Total Budget] 
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.Actual),SUM(vt.Actual) * 0.07) [Actual]
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.Diff),SUM(vt.Diff) * 0.07) [Diff]
FROM VatTotal vt
GROUP BY vt.[No.], vt.Detail
) VAT 
ORDER BY Sort

-- SELECT 'ภาษีมูลค่าเพิ่ม' [No.],
-- 		'Vat ซื้อ โครงการใหม่' Detail,
-- 		a.[yearMonth],
-- 		a.[Month],
-- 		SUM(a.[Total budget]) [Total budget],
-- 		SUM(a.Actual) [Actual]
-- 	FROM #CombineTable a
-- 	WHERE a.Detail IN ( '2.03 ค่าของโครงการใหม่ มี Vat', '2.04 ค่าของโครงการใหม่ ไม่มี Vat', '2.07 ค่าแรงโครงการใหม่ มี Vat', '2.08 ค่าแรงโครงการใหม่ ไม่มี Vat')
-- 	GROUP BY a.yearMonth, a.[Month]


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

IF OBJECT_ID(N'tempdb..#CombineTable', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #CombineTable;
    END;

IF OBJECT_ID(N'tempdb..#Variant', N'U') IS NOT NULL
BEGIN
	DROP TABLE #Variant;
END;

IF OBJECT_ID(N'tempdb..#VATprice', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #VATprice;
    END;

IF OBJECT_ID(N'tempdb..#TotalCol', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #TotalCol;
    END;

IF OBJECT_ID(N'tempdb..#NetProfit', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #NetProfit;
    END;