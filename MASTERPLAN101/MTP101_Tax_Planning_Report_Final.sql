
DECLARE @p0 DATE = '2025-01-01'
DECLARE @p1 DATE = '2025-12-31'
DECLARE @p2 NVARCHAR(MAX)  = '1' 
DECLARE @p3 DECIMAL(10,2) = 0.51 /*0.51*/
DECLARE @p4 DECIMAL(10,2)  = 0.49 /*0.80*/
/*มีการเขียน Script ใน Designer ว่าไม่ให้คำนวณ SubTotal ถ้า Detail เป็น 1.02 Vatขาย*/

DECLARE @startDate DATE = @p0
DECLARE @endDate DATE = @p1
DECLARE @ProjectId NVARCHAR(MAX) = @p2
DECLARE @SalaryRate DECIMAL(10,2) = @p3
DECLARE @FareRate DECIMAL(10,2)  = @p4

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




/******************** Temp #Revenue ประมาณการรายได้ ********************/

  IF OBJECT_ID(N'tempdb..#Revenue', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Revenue;
    END;

select	'รายได้' [รายได้]
		,'2' Sort
		,'ประมาณการรายได้' [GroupType]
		,CASE WHEN a.Description LIKE 'ประมาณการรายได้' THEN '1.01 ประมาณการรายได้' 
            WHEN a.Description LIKE 'Vatขาย' THEN '1.02 Vatขาย' 
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
					and rl.ItemMetaId in (2051,2052)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
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
					and rl.ItemMetaId in (2053,2054,2055,2056,2057,2058,2059,2060,2061,2062) /*ขึ้นตัวจริงต้องเช็คอีกที*/
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
					and rl.ItemMetaId in (2053,2054,2055,2056,2057,2058,2059,2060,2061,2062,2063,2064,2065,2066)  /*ขึ้นตัวจริงต้องเช็คอีกที*/
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
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		,((sum(a.DeAmount)  - sum(a.CreAmount))) [AmtSalaryRate]
Into #SalaryRate
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
				from JournalVouchers j
				left join JVLines jv on j.Id = jv.JournalVoucherId
				-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
				where jv.AccountCode = '61010001'/* coa.AnalysisCode1 = 'เงินเดือน ปันส่วน' */
						--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
						and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
						and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
						and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
						and j.DocStatus not in (-1)
						
				)a 
				group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #FareRate 2.07 ค่าเดินทาง+น้ำมัน ปันส่วน Vat********************/
  IF OBJECT_ID(N'tempdb..#FareRate', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #FareRate;
    END;

select	 'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		 ,'2' Sort
		 ,'Actual' [GroupType]	
		 ,'2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat' [Detail]
		 ,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		 ,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		 ,((sum(a.DeAmount)  - sum(a.CreAmount))) [AmtFareRate]
Into #FareRate
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0)[DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0)[CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
		from JournalVouchers j
		left join JVLines jv on j.Id = jv.JournalVoucherId
		-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
		where jv.AccountCode in ('61030001','61030002','61030003','61030004')/* coa.AnalysisCode1 = 'ค่าเดินทาง+น้ำมัน ปันส่วน' */
				--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
				and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
				and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
				and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
				and j.DocStatus not in (-1)		
				
				
		)a
		group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #OnSiteDepreciation 2.06 ค่าเสื่อมราคาหน้างาน********************/
  IF OBJECT_ID(N'tempdb..#OnSiteDepreciation', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #OnSiteDepreciation;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'2' Sort
		,'Actual' [GroupType]
		,'2.10 ค่าเสื่อมราคาหน้างาน' [Detail]
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		,((sum(a.DeAmount)  - sum(a.CreAmount))) [AmtOnSiteDepreciation]
Into #OnSiteDepreciation
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
					from JournalVouchers j
		left join JVLines jv on j.Id = jv.JournalVoucherId
		-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
		where jv.AccountCode in ('61110006')/* coa.AnalysisCode1 = 'ค่าเสื่อมราคาหน้างาน' */
				--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
				and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
				and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
				and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
				and j.DocStatus not in (-1)

		)a
		group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #ManagementWithOutVat 2.10 บริหารไม่มี Vat********************/
  IF OBJECT_ID(N'tempdb..#ManagementWithOutVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManagementWithOutVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]
		,'2.14 บริหารไม่มี Vat' [Detail]
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		,((sum(a.DeAmount)  - sum(a.CreAmount))) [AmtManagementWithOutVat]
Into #ManagementWithOutVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
	from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
				from JournalVouchers j
				left join JVLines jv on j.Id = jv.JournalVoucherId
				-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
				where jv.AccountCode = '61010001'/* coa.AnalysisCode1 = 'บริหารไม่มี Vat' */
						--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
						and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
						and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
						and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
						and j.DocStatus not in (-1)
				)a
			group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #ManageVat 2.09 บริหาร Vat********************/
  IF OBJECT_ID(N'tempdb..#ManageVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #ManageVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]	
		,'2.13 บริหาร Vat' [Detail]
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		,ISNULL((sum(a.DeAmount)  - sum(a.CreAmount)),0) [AmtManageVat]
Into #ManageVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
		from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
					from JournalVouchers j
					left join JVLines jv on j.Id = jv.JournalVoucherId
					-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
					where (jv.AccountCode between '60000000' and '61130006')
					AND jv.AccountCode NOT IN (/* '60030002','60030003', */'60000000','60010000','60010001','60010002','60010003','60010004','60010005','60010006','60010007','60010008','60010009','60010010','60010011','60010012','60010013','60010014','60010015','60010016','60010017','60010018','60010019','60010020','60010021','60010022','60010023','60020001','60020002','60030001','60030002','60030003','60030004','60030005','60030006','60030007','61010001','61030001','61030002','61030003','61110006')
					/* coa.AnalysisCode1 = 'บริหาร Vat' */
							--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
							and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
							and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
							and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
							and j.DocStatus not in (-1)
					)a
		group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #AdvertisingExpensesVat 2.08 ค่าโฆษณา Vat********************/
  IF OBJECT_ID(N'tempdb..#AdvertisingExpensesVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #AdvertisingExpensesVat;
    END;

select	'ค่าใช้จ่าย' [ค่าใช้จ่าย]
		,'3' Sort
		,'Actual' [GroupType]	
		,'2.12 ค่าโฆษณา Vat' [Detail]
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,sum(a.DeAmount) DeAmount,sum(a.CreAmount) CreAmount
		,ISNULL((sum(a.DeAmount)  - sum(a.CreAmount)),0) [AmtAdvertisingExpensesVat]
Into #AdvertisingExpensesVat
from
	(select a.OrgId
			,a.OrgCode
			,a.OrgName
			,a.MadeByDocCode
			,a.[Date]--FORMAT(a.Date ,'yyyyMM')  [Date]
			,a.AccountCode,a.AccountName
			,IIF(a.isDebit = 1 ,sum(DocAmount),0) [DeAmount]
			,IIF(a.isDebit = 0 ,sum(DocAmount),0) [CreAmount]
from(select j.OrgId
					,j.OrgCode
					,j.OrgName
					,j.MadeByDocCode
					,j.Date
					,jv.DocAmount
					,jv.AccountCode
					,jv.AccountName
					,jv.JournalVoucherId
					,jv.isDebit
			from JournalVouchers j
			left join JVLines jv on j.Id = jv.JournalVoucherId
			-- INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
			where jv.AccountCode in ('60020002','60030002','60030003','60030007','60010007')/* coa.AnalysisCode1 = 'ค่าโฆษณา' */
					--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
					and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
					and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
					and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
					and j.DocStatus not in (-1)
			)a
			group by a.OrgId
							,a.OrgCode
							,a.OrgName
							,a.Date
							,a.isDebit,a.MadeByDocCode,a.AccountCode,a.AccountName
)a 
group by a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName

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
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,isnull(sum(a.Amount),0) [AmtSubcontract]
Into #Subcontract
from(
select	IIF(jv.isDebit = 1,jv.Amount,jv.Amount * -1) Amount /* ดึงมาทั้ง dr cr เเล้วให้มัน Net กัน */
		,j.[Date]--FORMAT(j.Date ,'yyyyMM')  [Date]
		,j.OrgCode,j.MadeByDocCode,jv.AccountCode,jv.AccountName
		,Case when i.SystemCategoryId in (123,129) then 'Vat'
				else 'NoVat'
			end vat
from  JournalVouchers j
left join JVLines jv on j.Id = jv.JournalVoucherId
INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
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

where /* jv.AccountCode IN (51010002,51040005,51040007,51040008,51050102,51050103,51050104,51050105,51070102,51070302,51080002,51090206,51130101,51140002
						,51150101,51150201,51150302,51160001,51170003,51170201,51170202,51170203,51170204,51170303,51170403,51170404,51170405
						,51170406,51180001,51190101,51210101,51210102,51220001,51230002,51240001,51250002,51272001,51272002,52060001,52060021
						,52060022,52080001,52090104,52090205,52090206,52110002,52120004,52130002,52150002,52170002,52180003,52180004,55040402
						,55050203,55110001,55110002,55120001,55130004,55140001) */coa.AnalysisCode1 = 'แรง'
		and j.DocStatus in (4,5)
		-- and jv.isDebit = 1
		--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
		and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
		and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
)a group by a.Date,a.vat,a.MadeByDocCode,a.AccountCode,a.AccountName

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
		,a.Date,a.MadeByDocCode,a.AccountCode,a.AccountName
		,isnull(sum(a.Amount),0) [AmtMaterial]
Into #Material
from(
select IIF(jv.isDebit = 1,jv.Amount,jv.Amount * -1) Amount /* ดึงมาทั้ง dr cr เเล้วให้มัน Net กัน */
		,j.[Date]--FORMAT(j.Date ,'yyyyMM')  [Date]
		,j.OrgCode,j.MadeByDocCode,jv.AccountCode,jv.AccountName
		,Case when i.SystemCategoryId in (123,129) then 'Vat'
				else 'NoVat'
			end vat
from  JournalVouchers j
left join JVLines jv on j.Id = jv.JournalVoucherId
INNER JOIN ChartOfAccounts coa ON coa.Id = jv.AccountId
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
where /* AccountCode IN (51010001,51010005,51010006,51020002,51020003,51020007,51020010,51020011,51020012,51020014,51020016,51030001,51030002,51030003,51030004
						,51030005,51030006,51030007,51030009,51030010,51030011,51030012,51040001,51040002,51040004,51040006,51050101,51050202,51050203
						,51050204,51050206,51050207,51050208,51070101,51070301,51080001,51080003,51090101,51090203,51090204,51090301,51100001,51110001
						,51120101,51120201,51120202,51120204,51120206,51130202,51130205,51140001,51150301,51170001,51170002,51170101,51170103,51170104
						,51170301,51170401,51170402,51170503,51190003,51190004,51210001,51210002,51210003,51210004,51210104,51230001,51250001,51271001
						,52020001,52040001,52040002,52050003,52070001,52090101,52090102,52090201,52100001,52110001,52120003,52140203,52160001,52170001
						,52180001,54020101,54060001,55010001,55040401,55050201,55050202,55060001,55080001,52190001) */
						coa.AnalysisCode1 = 'ของ'
		and j.DocStatus in (4,5)
		-- and jv.isDebit = 1
		--and j.Date Between DateAdd("m",-12,@AsOfDate) And @AsOfDate
		and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี
		and (j.Date BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (jv.OrgId in (select Id from #temporg) or @ProjectId is NULL)
)a group by a.Date,a.vat,a.MadeByDocCode,a.AccountCode,a.AccountName

/******************** Temp #Accouctchart4Profit 1.01 ประมาณการรายได้********************/
  IF OBJECT_ID(N'tempdb..#Accouctchart4Profit', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Profit;
    END;

/*รายได้ผัง4 Vat*/
select	'รายได้' [รายได้]
		,'3' Sort
		,'Actual' [GroupType]	
		,/*Case when a.vat = 'Vat' then '1.01 ประมาณการรายได้'
				else '1.02 Vatขาย'--'รายได้ผัง4ไม่มี Vat'
			end*/'1.01 ประมาณการรายได้' [Detail]
		,a.Date,a.DocCode,a.AccountCode,a.AccountName
				,ISNULL(SUM(a.CreAmount),0) [CreAmount]
		,ISNULL(SUM(a.DeAmount),0) [DeAmount]
		,isnull(sum(a.Amount),0) [AmtMaterial]/* , a.AcctCode */
Into #Accouctchart4Profit
from(
select CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE ISNULL(s.Amount,jl.Amount)*-1 END [Amount]
				,CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE 0 END [CreAmount]
				,CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN 0 ELSE ISNULL(s.Amount,jl.Amount) END [DeAmount]
				,ISNULL(s.DocDate,j.[Date]) [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,ISNULL(s.DocType,j.MadeByType) [DocType]
				,ISNULL(s.DocCode,j.MadeByDocCode) [DocCode],ISNULL(s.AccountCode,jl.AccountCode) [AccountCode],ISNULL(s.AccountName,jl.AccountName) [AccountName]
FROM	    dbo.JVLines jl WITH (nolock)
			   INNER JOIN dbo.JournalVouchers j WITH (NOLOCK) ON jl.JournalVoucherId = j.Id AND ISNULL(j.DocStatus,0) <> -1	and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี								
			   LEFT JOIN dbo.GeneralAccountEntities ga WITH (NOLOCK) ON ga.EnumKey = jl.GeneralAccount
			   LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON IIF(ISNULL(jl.OrgId,0) IN (0,-1),j.OrgId,jl.OrgId) = o.Id
			   LEFT JOIN dbo.AcctElementSets s WITH (NOLOCK) ON s.JVLineId = jl.Id --AND jl.MadeByDocTypeId = 149
			   -- INNER JOIN ChartOfAccounts coa ON coa.Id = jl.AccountId
where jl.AccountCode LIKE '4%'/* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) *//* coa.AnalysisCode1 = 'Vatขาย' */
		-- and s.isDebit = 0
		and (CONVERT(DATE,ISNULL(NULLIF(s.DocDate,''),j.Date)) BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (ISNULL(s.OrgId,j.OrgId) in (select Id from #temporg) or @ProjectId is NULL) 
		-- AND s.DocType IS NOT NULL
		-- and i.SystemCategoryId not in (123,129)

)a group by a.Date,a.DocCode,a.AccountCode,a.AccountName

/******************** Temp #Accouctchart4Vat  1.02 Vatขาย********************/
  IF OBJECT_ID(N'tempdb..#Accouctchart4Vat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Vat;
    END;

/*รายได้ผัง4ไม่มี Vat*/
select	'รายได้' [รายได้]
		,'3' Sort
		,'Actual' [GroupType]	
		,/* Case when a.vat = 'Vat' then 'รายได้ผัง4 Vat'
				else '1.02 Vatขาย'
			end  */'1.02 Vatขาย'[Detail]
		,a.Date,a.DocCode,a.AccountCode,a.AccountName
		,ISNULL(SUM(a.CreAmount),0) [CreAmount]
		,ISNULL(SUM(a.DeAmount),0) [DeAmount]
		,isnull(sum(a.Amount),0) [AmtMaterial]/* , a.AcctCode */
Into #Accouctchart4Vat
from(
select CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE ISNULL(s.Amount,jl.Amount)*-1 END [Amount]
				,CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE 0 END [CreAmount]
				,CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN 0 ELSE ISNULL(s.Amount,jl.Amount)*-1 END [DeAmount]
				,ISNULL(s.DocDate,j.[Date]) [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				,s.DocType
				,s.DocCode,ISNULL(s.AccountCode,jl.AccountCode) [AccountCode],ISNULL(s.AccountName,jl.AccountName) [AccountName]
FROM	    dbo.JVLines jl WITH (nolock)
			   INNER JOIN dbo.JournalVouchers j WITH (NOLOCK) ON jl.JournalVoucherId = j.Id AND ISNULL(j.DocStatus,0) <> -1	and j.JournalId NOT IN (17,18) --ไม่รวม journal ปิดบัญชี								
			   LEFT JOIN dbo.GeneralAccountEntities ga WITH (NOLOCK) ON ga.EnumKey = jl.GeneralAccount
			   LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON IIF(ISNULL(jl.OrgId,0) IN (0,-1),j.OrgId,jl.OrgId) = o.Id
			   LEFT JOIN dbo.AcctElementSets s WITH (NOLOCK) ON s.JVLineId = jl.Id --AND jl.MadeByDocTypeId = 149
			   -- INNER JOIN ChartOfAccounts coa ON coa.Id = jl.AccountId
where jl.AccountCode LIKE '21250100'/* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) *//* coa.AnalysisCode1 = 'Vatขาย' */
		-- and s.isDebit = 0
		and (CONVERT(DATE,ISNULL(NULLIF(s.DocDate,''),j.Date)) BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (ISNULL(s.OrgId,j.OrgId) in (select Id from #temporg) or @ProjectId is NULL) 
		AND s.DocType IS NOT NULL
		-- and i.SystemCategoryId not in (123,129)
)a group by a.Date,a.DocCode,a.AccountCode,a.AccountName

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
		,ISNULL(IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL),0) [ประมาณการรายได้]
		-- ,NULL [ผลต่าง+-]
		,ISNULL(IIF(a.GroupType = 'ประมาณการต้นทุนที่ต้องใช้',a.Amount,NULL),0) [ประมาณการต้นทุนที่ต้องใช้]
		,ISNULL(IIF(a.GroupType = 'ประมาณการต้นทุนโครงการใหม่',a.Amount,NULL),0) [ประมาณการต้นทุนโครงการใหม่]
		,ISNULL(IIF(a.GroupType = 'ประมาณการSum',a.Amount,IIF(a.GroupType = 'ประมาณการรายได้',a.Amount,NULL)),0) [Total budget]
		,ISNULL(IIF(a.GroupType = 'Actual',a.Amount,NULL),0) [Actual]
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
			select [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,SUM(AmtMaterial) AmtMaterial from #Material group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,ISNULL(SUM(AmtSubcontract),0) AmtSubcontract from #Subcontract group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select [ค่าใช้จ่าย]
					,Sort
					,[GroupType]
					,[Detail]
					,Date
					,SUM([AmtSalaryRate])* Isnull(@SalaryRate,1) [AmtSalaryRate] from #SalaryRate group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,SUM(AmtOnSiteDepreciation) from #OnSiteDepreciation group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select [ค่าใช้จ่าย]
					,Sort
					,[GroupType]	
					,[Detail]
					,Date
					,SUM([AmtFareRate]) * Isnull(@FareRate,1) [AmtFareRate] from #FareRate group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,SUM(AmtAdvertisingExpensesVat) AmtAdvertisingExpensesVat from #AdvertisingExpensesVat group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all 
			select mv.ค่าใช้จ่าย,mv.Sort,mv.GroupType,mv.Detail
			,mv.Date
			,isnull(mv.AmtManageVat,0)  + (isnull(fr.AmtFareRate,0) * (1-ISNULL(@FareRate,0)))
				/*- (isnull(sr.AmtSalaryRate,0) 
				+ isnull(fr.AmtFareRate,0) 
				+ isnull(od.AmtOnSiteDepreciation,0)
				+ isnull(mov.AmtManagementWithOutVat,0) 
				+ isnull(ae.AmtAdvertisingExpensesVat,0)*/ [AmtManageVat]
			from (SELECT [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,SUM(AmtManageVat) AmtManageVat FROM #ManageVat GROUP BY [ค่าใช้จ่าย],Sort,GroupType,Detail,Date) mv
			left join (select [ค่าใช้จ่าย],Sort,[GroupType]	,[Detail],Date,SUM([AmtFareRate])[AmtFareRate] from #FareRate GROUP BY [ค่าใช้จ่าย],Sort,[GroupType],[Detail],Date) fr on mv.Date = fr.Date

			-- left join #OnSiteDepreciation od on sr.Date = od.Date
			-- left join #ManagementWithOutVat mov on sr.Date = mov.Date
			-- left join #ManageVat mv on sr.Date = mv.Date
			-- left join #AdvertisingExpensesVat ae on sr.Date = ae.Date
		union all 
			select [ค่าใช้จ่าย],Sort,GroupType,Detail,Date,SUM(AmtManagementWithOutVat)* (1-ISNULL(@SalaryRate,0)) AmtManagementWithOutVat from #ManagementWithOutVat group by [ค่าใช้จ่าย],Sort,GroupType,Detail,Date
		union all
			select [รายได้],Sort,GroupType,Detail,Date,SUM(AmtMaterial) AmtMaterial from #Accouctchart4Profit group by [รายได้],Sort,GroupType,Detail,Date
		union all
			select [รายได้],Sort,GroupType,Detail,Date,SUM(AmtMaterial) AmtMaterial from #Accouctchart4Vat group by [รายได้],Sort,GroupType,Detail,Date

	) a		
Group by a.รายได้,a.GroupType,a.Detail,a.Sort,a.[Date],a.Amount
) a

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

/******************** Temp #VAT ********************/
IF OBJECT_ID('tempDB..#VAT', 'U') IS NOT NULL
BEGIN
	DROP TABLE #VAT
END;
/* เพิ่ม query จากรายงาน Vat Sell Report รวมกับ Vat Buy Report เพื่อเอามาเเทนช่อง Actual ตารางล่าง */
SELECT vat.Detail,vat.yearMonth,vat.[Month],SUM(vat.TaxAmount) [TaxAmount]
INTO #VAT
FROM (
	/* VAT Buy */
		SELECT	
		'2.01 VAT BUY' [Detail],
		-- (t.Date) [TaxInvoiceDate] ,  ------------ ค.ศ.
		FORMAT(t.SendTaxDate, 'yyyy-MM','en') [yearMonth],
		FORMAT(t.SendTaxDate, 'MMMM','th') [Month],

		CASE WHEN ISNULL(t.AvgTaxRate,-1) = -1
			 THEN t.TaxBase * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 ELSE 1 END )
			 ELSE t.NormalTaxBase * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 ELSE 1 END )
		END	 [TaxBase] ,
		CASE WHEN ISNULL(t.AvgTaxRate,-1) = -1
			 THEN ROUND(t.TaxAmount, 2) * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 WHEN t.SetDocTypeId = 97 AND t.TaxBase < 0 THEN -1 ELSE 1 END)
			 ELSE ROUND(t.NormalTaxAmount, 2) * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 ELSE 1 END)
		END	 [TaxAmount] ,
        CASE WHEN ISNULL(t.AvgTaxRate,-1) = -1
			 THEN (t.TaxBase + ROUND(t.TaxAmount, 2)) * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 ELSE 1 END) 
			 ELSE (t.NormalTaxBase + ROUND(t.NormalTaxAmount, 2)) * (CASE WHEN t.SetDocType = 'CreditNoteAP' THEN -1 WHEN t.SetDocTypeId = 149 AND ac.isDebit = 0 THEN -1 ELSE 1 END) 
		END	 [TotalAmount] 
		--  ,CASE WHEN ISNULL(t.AvgTaxRate,-1) = -1
		-- 	 THEN t.TaxRate 
		-- 	 ELSE t.AvgTaxRate
		-- END	 [TaxRate] 


		FROM	dbo.TaxItems t
			outer apply	(	
							SELECT  iv.InvoiceId,iv.Id ,
								CASE WHEN iv.Description = '' THEN iv.ItemMetaName ELSE iv.Description END [Description]
							FROM    dbo.InvoiceLines iv
							WHERE   iv.LineNumber = 1 
							and
							(iv.InvoiceId = t.SetDocId AND t.SetDocTypeId = 37)
						) iv /*ON iv.InvoiceId = t.SetDocId AND t.SetDocTypeId = 37*/
			outer apply	(	
							SELECT  GeneralAccount,AdjustInvoiceId
							FROM    dbo.AdjustInvoiceLines CNAP
							inner join dbo.AdjustInvoices AJ39 on CNAP.AdjustInvoiceId = AJ39.Id
							WHERE 
							/*
							CNAP.AdjustInvoiceId IN ( SELECT Id FROM dbo.AdjustInvoices WHERE  DocTypeId = 39 )
							AND 
							*/
							CNAP.SystemCategoryId = 111 
							and 
							(CNAP.AdjustInvoiceId = t.SetDocId AND t.SetDocTypeId IN ( 39, 40 ))
						) CNAP /*ON CNAP.AdjustInvoiceId = t.SetDocId AND t.SetDocTypeId IN ( 39, 40 )*/
			outer apply	(	
							SELECT	j.MadeByDocCode,j.Code JVCode
									,MIN(jl.AccountCode) AccountCode
									,MIN(convert(nvarchar(2000),jl.AccountName)) AccountName 
							FROM	dbo.JournalVouchers j
									inner JOIN dbo.JVLines jl ON jl.JournalVoucherId = j.Id AND jl.isDebit = 0 and jl.GeneralAccount = 192
							WHERE	
							/*
							j.Id IN  (SELECT JournalVoucherId FROM dbo.JVLines WHERE GeneralAccount = 192)
							AND 
							*/
							/*j.MadeByDocCode = t.SetDocCode*/
							(t.SetDocTypeId = j.MadeByTypeId and t.SetDocId = j.MadeByDocId)
							GROUP BY j.MadeByDocCode,j.Code
						)jj /*ON jj.MadeByDocCode = t.SetDocCode*/
			LEFT JOIN dbo.AdjustInvoices ai	ON ai.id = t.SetDocId AND t.SetDocTypeId IN ( 39, 40 )
			LEFT JOIN dbo.AcctElementSets ac ON ac.TaxItemGuId = t.guid And t.SetDocTypeId = 149
			OUTER APPLY (
				SELECT s.Id [SetId],sr.Zero [Zero] FROM dbo.AcctElementSets s
				INNER JOIN dbo.AcctElementSets_RemainAcctElement sr ON s.Id	= sr.Id
				WHERE s.TaxItemId = t.Id 
				AND s.GeneralAccount = 192
				GROUP BY s.Id,sr.Zero
			) r
			outer apply (
						select sum(1) cnt from AcctElementSets s  with(forceseek)
						where s.TaxItemId = t.Id 
							and s.ReadyToUse = 1
							and isnull(t.TaxAmount, 0) != 0
			) s
			outer apply (
						select sum(1) cnt from JournalVouchers jv with(forceseek)
						where jv.MadeByTypeId = t.SetDocTypeId 
							and jv.MadeByDocId = t.SetDocId 
							and jv.DocStatus in (4, 5)
							and isnull(t.TaxAmount, 0) = 0
			) jv
			WHERE	t.TaxMetaCode = 'TH-01'
					AND ((NULLIF(@StartDate,'1900-01-01') IS NULL AND NULLIF(@EndDate,'1900-01-01') IS NULL)
							OR (CONVERT(NVARCHAR(10),t.SendTaxDate,120) BETWEEN @StartDate AND @EndDate) 
								)
					-- AND ((t.ExtOrgId = @ProjectId) OR @ProjectId IS NULL)
					
					
					AND t.Status <> -1
					
					
					-- AND ((NULLIF(@FromSendTaxDate,'1900-01-01') IS NULL) OR t.Status = 9)
					AND ((t.OrgId IN (SELECT Id FROM #temporg)) OR @ProjectId IS NULL)
					AND 
					(
							exists (select 1 from dbo.ProhibitedTaxItems pht 
							LEFT JOIN dbo.ProhibitedTaxes p ON pht.ProhibitedTaxId = p.Id
							WHERE p.DocStatus <> -1 AND  pht.GeneralAccount = 192 AND pht.TaxItemId = t.Id AND r.Zero = 0) 
							OR  
							(not exists (select 1 from dbo.ProhibitedTaxItems pht 
							LEFT JOIN dbo.ProhibitedTaxes p ON pht.ProhibitedTaxId = p.Id
							WHERE p.DocStatus <> -1 AND pht.GeneralAccount = 192 AND pht.TaxItemId = t.Id))
					)


		UNION ALL

		/* Vat Sell */
		SELECT    

							'VAT SELL' [Detail],
							-- ti.Date [TaxInvoiceDate] ,
							FORMAT(ti.Date, 'yyyy-MM','en') [yearMonth],
							FORMAT(ti.Date, 'MMMM','th') [Month],

							CASE WHEN ti.DocStatus = '-1' THEN 0 
									WHEN ti.Code = 'ExemptVat' THEN (ABS(ti.ExemptVatDocAmount))
									ELSE (CASE s.isDebit WHEN 1 THEN (ABS(ti.TaxBase) *-1)  ELSE ti.TaxBase END ) END [TaxBase] ,
							CASE ti.DocStatus WHEN -1 THEN 0 ELSE (CASE s.isDebit WHEN 1 THEN (ABS(ti.TaxAmount) *-1) ELSE ti.TaxAmount END ) END [TaxAmount] ,
							CASE ti.DocStatus WHEN -1 THEN 0 ELSE (CASE s.isDebit WHEN 1 THEN ((ABS(ti.TaxBase) + ABS(ti.TaxAmount))* -1) ELSE ti.TaxBase + ti.TaxAmount END) END [TotalAmount] 
							
							-- ,case when ti.SystemCategoryId = 207
							-- 	 THEN -1
							-- 	 ELSE ti.TaxRate--CONCAT(FORMAT(ti.TaxRate,'0.00'),'%') 
							-- END TaxRate

				FROM      dbo.TaxItems ti with(nolock)
				
							LEFT JOIN dbo.AcctElementSets s with(nolock) ON ti.id = s.TaxItemId AND s.GeneralAccount IN ( 192, 292 )
							outer apply (
									SELECT doc.id pivID,dbo.GROUP_CONCAT_D(doc.Code,' ,') pivCode
									,doc.LocationCode PivLocationCode,doc.LocationId PivLocationID
									,doc.LocationName PivLocationName,doc.Remarks,jv.Code JvCode 
									,CONCAT(sp1.SitePath,doc.id,'')SitePathProductInvoiceAR
									FROM dbo.ProductInvoiceARs doc  with(nolock,forceseek)
									LEFT JOIN dbo.JournalVouchers jv with(nolock) ON jv.MadeByTypeId = 438  AND jv.MadeByDocId = doc.Id
									LEFT JOIN dbo.SitePathList() sp1 ON sp1.DocTypeId = jv.MadeByTypeId
									where
									doc.id = ti.SetDocId and ti.SetDocTypeId = 438
									GROUP BY doc.id ,doc.LocationCode ,doc.LocationId 
											,doc.LocationName ,doc.Remarks,jv.Code  
											,CONCAT(sp1.SitePath,doc.id,'')
							) piv
							OUTER APPLY ( SELECT DISTINCT exts.DocId, exts.DocTypeId,IIF(exts.ExtOrgId = 0, exts.WorkerName, exts.ExtOrgName) ExtOrgName
										FROM dbo.AcctElementSets exts
										WHERE IIF(ISNULL(exts.ExtOrgId,0) = 0, ISNULL(exts.WorkerId,0), ISNULL(exts.ExtOrgId,0)) != 0
										AND ti.SetDocId = exts.DocId
										AND ti.SetDocTypeId = exts.DocTypeId
							) ext
							outer apply (SELECT doc.id ivID,dbo.GROUP_CONCAT_D(doc.Code,' ,') ivCode
											,doc.LocationCode IvLocationCode,doc.LocationId IvLocationID
											,doc.LocationName IvLocationName,doc.Remarks,jv.Code JvCode 
											,CONCAT(sp1.SitePath,doc.id,'')SitePathInvoiceAR
									FROM dbo.InvoiceARs doc  with(nolock,forceseek)
									LEFT JOIN dbo.JournalVouchers jv with(nolock) ON jv.MadeByTypeId = 38  AND jv.MadeByDocId = doc.Id
									LEFT JOIN dbo.SitePathList() sp1 ON sp1.DocTypeId = jv.MadeByTypeId
									where
									doc.id = ti.SetDocId and ti.SetDocTypeId = 38
											GROUP BY doc.id ,doc.LocationCode ,doc.LocationId 
														,doc.LocationName ,doc.Remarks,jv.Code  
														,CONCAT(sp1.SitePath,doc.id,'')
											) ivr /*ON ivr.ivID = ti.SetDocId */

							outer apply ( SELECT t.Id taxitemid,Jvt.code JVCode,Jvt.date JVDate,t.SendTaxDate ,t.SetDocTypeId,jvt.MadeByTypeId,jvt.id

										FROM taxitems t  with(nolock,forceseek)
										LEFT JOIN dbo.JournalVouchers jvt with(nolock)  ON jvt.MadeByDocCode = t.setdoccode 
						
										WHERE t.SystemCategoryId IN (146,151) AND jvt.DocStatus <> -1 AND jvt.MadeByTypeId = 52 /*ReceveVoucher*/
										and
										t.id = ti.id AND ti.SetDocTypeId = 151
									)jv /*on Jv.taxitemid = ti.id AND ti.SetDocTypeId = 151*/
		
			outer apply ( SELECT t.Id taxitemid,Jvt.code JVCode,Jvt.date JVDate,t.SendTaxDate ,t.SetDocTypeId,Jvt.MadeByTypeId,jvt.id

										FROM taxitems t  with(nolock,forceseek)
										LEFT JOIN dbo.JournalVouchers jvt with(nolock)  ON jvt.MadeByDocCode = t.setdoccode 
						
										WHERE t.SystemCategoryId IN (123,146,151) AND jvt.DocStatus <> -1 AND jvt.MadeByTypeId NOT IN (39,52) /*not ReceveVoucher AND CreditNoteAP*/
										and
										t.Id = ti.id AND ti.SetDocTypeId <> 151
									)jv2 /*on Jv2.taxitemid = ti.id AND ti.SetDocTypeId <> 151*/

							LEFT JOIN dbo.ExtOrganizations eo with(nolock) ON eo.id = ti.ExtOrgId
							LEFT JOIN dbo.ReceiveVoucherLines rvl with(nolock) ON ti.Id = rvl.TaxItemId AND ti.TaxAmount = 0  AND ti.TaxRate = 0
							LEFT JOIN dbo.ReceiveVouchers rv with(nolock) ON rv.Id = rvl.ReceiveVoucherId

					WHERE       ti.TaxRate = 7
									AND ti.TaxMetaCode = 'TH-03'
									AND ti.Status IN (1,9,-1)
									AND ((ti.OrgId IN (SELECT Id FROM #temporg)) OR @ProjectId IS NULL)
									AND isnull(rv.Docstatus,0) <> -1
									AND(	(CONVERT(NVARCHAR(10),ti.[Date], 120)BETWEEN @startDate AND  @endDate)
						OR (NULLIF(@startDate,'1900-01-01') IS NULL AND NULLIF(@endDate,'1900-01-01') IS NULL)
					)
) vat
GROUP BY vat.Detail,vat.[Month],vat.yearMonth
ORDER BY vat.yearMonth ASC
option(recompile)

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
		-- CASE WHEN a.type =
		a.[Total budget] [STotal Budget],
		/* a.Actual */0 [SActual]
	FROM #CombineTable a
	WHERE a.Detail IN ( '1.02 Vatขาย', '2.01 ค่าของมี Vat', '2.03 ค่าของโครงการใหม่ มี Vat', '2.05 ค่าแรงมี Vat', '2.07 ค่าแรงโครงการใหม่ มี Vat', '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat', '2.12 ค่าโฆษณา Vat', '2.13 บริหาร Vat')
	UNION ALL
		/* Union all กับ query VAT sell + Vat buy */
		SELECT 'ภาษีมูลค่าเพิ่ม' [No.]
		,b.Detail
		,b.yearMonth
		,b.[Month]
		,0 [STotal Budget]
		,b.TaxAmount [SActual]
		FROM #VAT b
	) a
		-- GROUP BY a.[No.], a.Detail, a.yearMonth, a.[Month], a.[STotal Budget], a.SActual

) v 
GROUP BY v.[No.], v.VATDetail, v.yearMonth, v.[Month]

/******************** Temp #TotalCol ********************/
DECLARE @profit DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'รายได้' AND c.[type] = 'ประมาณการรายได้')
-- DECLARE @ProductActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ')
-- DECLARE @WorkerActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง')
-- DECLARE @OtherActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง')
-- DECLARE @ManagementActual DEC(20, 2) = (SELECT SUM(c.Actual ) FROM #CombineTable c WHERE c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร')

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
		,c.[ผลต่าง+-]
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
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.01 ค่าของมี Vat') THEN CAST('0.2132' AS DEC(10, 4)) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.02 ค่าของไม่มี Vat') THEN CAST('0.0936' AS DEC(10, 4)) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.03 ค่าของโครงการใหม่ มี Vat') THEN CAST('0.2132' AS DEC(10, 4)) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.05 ค่าแรงมี Vat') THEN CAST('0.008' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.06 ค่าแรงไม่มี Vat') THEN CAST('0.064' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.07 ค่าแรงโครงการใหม่ มี Vat') THEN CAST('0.008' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.09 เงินเดือน ปันส่วน') THEN CAST('0' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.10 ค่าเสื่อมราคาหน้างาน') THEN CAST('0' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat') THEN CAST('0.17' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.12 ค่าโฆษณา Vat') THEN CAST('0.1' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.13 บริหาร Vat') THEN CAST('0.1' AS DEC(10, 4))
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.14 บริหารไม่มี Vat') THEN CAST('0' AS DEC(10, 4))
				ELSE NULL
			END [RD]
			,CASE WHEN (c.[No.] = 'รายได้' AND c.[type] = 'ประมาณการรายได้') THEN '1'
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.01 ค่าของมี Vat') THEN (SUM(c.Actual) / @profit) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.02 ค่าของไม่มี Vat') THEN (SUM(c.Actual) / @profit) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าของ' AND c.Detail = '2.03 ค่าของโครงการใหม่ มี Vat') THEN (SUM(c.Actual) / @profit) 
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.05 ค่าแรงมี Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.06 ค่าแรงไม่มี Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'ค่าแรง' AND c.Detail = '2.07 ค่าแรงโครงการใหม่ มี Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.09 เงินเดือน ปันส่วน') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.10 ค่าเสื่อมราคาหน้างาน') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'เงินเดือน ค่าเสื่อมราคาหน้างาน ค่าเดินทาง' AND c.Detail = '2.11 ค่าเดินทาง+น้ำมัน ปันส่วน Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.12 ค่าโฆษณา Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.13 บริหาร Vat') THEN (SUM(c.Actual) / @profit)
				WHEN (c.[No.] = 'ค่าใช้จ่าย' AND c.[type] = 'บริหาร' AND c.Detail = '2.14 บริหารไม่มี Vat') THEN (SUM(c.Actual) / @profit)
			ELSE NULL
			END [MTP]
			,SUM(c.[ประมาณการรายได้]) [ประมาณการรายได้]
			,SUM(c.[ผลต่าง+-]) [ผลต่าง+-]
			,SUM(c.[ประมาณการต้นทุนที่ต้องใช้]) [ประมาณการต้นทุนที่ต้องใช้]
			,SUM(c.[ประมาณการต้นทุนโครงการใหม่]) [ประมาณการต้นทุนโครงการใหม่]
			,SUM(c.[Total budget]) [Total budget]
			,SUM(c.Actual) [Actual]
			,SUM(c.Diff) [Diff]
	FROM (SELECT a.[No.],
				a.[type],
				a.SortType,
				a.GroupType,
				a.Detail,
				v.Detail [var_detail],
				a.yearMonth [Date],
				a.[Month],
				ISNULL(a.[ประมาณการรายได้],0) [ประมาณการรายได้],
				ISNULL(IIF(ROW_NUMBER() OVER (PARTITION BY a.Detail, a.Month ORDER BY a.yearMonth) = 1, v.d, NULL),0) [ผลต่าง+-], --เอาอันนี้รวมกับใน total budget
				ISNULL(a.[ประมาณการต้นทุนที่ต้องใช้],0) [ประมาณการต้นทุนที่ต้องใช้],
				ISNULL(a.[ประมาณการต้นทุนโครงการใหม่],0) [ประมาณการต้นทุนโครงการใหม่],
				ISNULL(a.[Total budget],0) [Total budget],
				ISNULL(a.Actual,0) [Actual],
				ISNULL(a.Diff,0) [Diff]
		FROM #CombineTable a 
		LEFT JOIN #Variant v ON v.Detail = a.Detail AND v.NextYearMonth = a.yearMonth AND v.NextMonth = a.[Month]) c
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
		SUM(IIF(c.Detail = '1.02 Vatขาย',0,c.[ผลต่าง+-])) [ผลต่าง+-],
		-- -- SUM(c.[ประมาณการรายได้]) AS Sum_ประมาณการรายได้,
        -- -- SUM(c.[ประมาณการต้นทุนที่ต้องใช้]) AS Sum_ประมาณการต้นทุนที่ต้องใช้,
        -- -- SUM(c.[ประมาณการต้นทุนโครงการใหม่]) AS Sum_ประมาณการต้นทุนโครงการใหม่,
        SUM(IIF(c.Detail = '1.02 Vatขาย',0,c.[Total budget])) AS Sum_Total_budget,
        SUM(IIF(c.Detail = '1.02 Vatขาย',0,c.[Actual])) AS Sum_Actual,
        SUM(IIF(c.Detail = '1.02 Vatขาย',0,c.[Diff])) AS Sum_Diff
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
				ISNULL(IIF(ROW_NUMBER() OVER (PARTITION BY a.Detail, a.Month ORDER BY a.yearMonth) = 1, v.d, NULL),0) [ผลต่าง+-],
				a.[Total budget],
				a.Actual,
				a.Diff
		FROM #CombineTable a
		LEFT JOIN #Variant v ON v.Detail = a.Detail AND v.NextYearMonth = a.yearMonth AND v.NextMonth = a.[Month]
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
				,t.[ผลต่าง+-]
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
-- select * from #Accouctchart4Profit
-- select * from #Accouctchart4Vat
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
		0.00 [RD (%)],
		0.00 [MTP (%)],
		0.00 [Diff (MTP - RD)],
		ISNULL(a.[ประมาณการรายได้],0) [ประมาณการรายได้],
		ISNULL(IIF(ROW_NUMBER() OVER (PARTITION BY a.Detail, a.Month ORDER BY a.yearMonth) = 1, v.d, NULL),0) [ผลต่าง+-], --เอาอันนี้รวมกับใน total budget
		ISNULL(a.[ประมาณการต้นทุนที่ต้องใช้],0) [ประมาณการต้นทุนที่ต้องใช้],
		ISNULL(a.[ประมาณการต้นทุนโครงการใหม่],0) [ประมาณการต้นทุนโครงการใหม่],
		ISNULL(a.[Total budget],0) [Total budget],
		ISNULL(a.Actual,0) [Actual],
		ISNULL(a.Diff,0) [Diff]
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
		,ISNULL(t.[ผลต่าง+-],0) [ผลต่าง+-]
		,ISNULL(t.[ประมาณการต้นทุนที่ต้องใช้],0) [ประมาณการต้นทุนที่ต้องใช้]
		,ISNULL(t.[ประมาณการต้นทุนโครงการใหม่],0) [ประมาณการต้นทุนโครงการใหม่]
		,ISNULL(t.[Total budget],0) + ISNULL(t.[ผลต่าง+-],0) [Total budget]
		,ISNULL(t.Actual,0) Actual
		,ISNULL(t.Diff,0) Diff
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
		0.00 [ประมาณการรายได้],
		ISNULL(IIF(a.GroupType = 'รวมรายได้', a.[ผลต่าง+-],0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.[ผลต่าง+-],0),0) [ผลต่าง+-],
		0.00 [ประมาณการต้นทุนที่ต้องใช้],
		0.00 [ประมาณการต้นทุนโครงการใหม่],
		ISNULL(IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.GroupType = 'รวมรายได้', a.Sum_Total_budget,0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.Sum_Total_budget,0)),NULL),0) + ISNULL(IIF(a.GroupType = 'รวมรายได้', a.[ผลต่าง+-],0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.[ผลต่าง+-],0),0) [Total budget],
		ISNULL(IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.GroupType = 'รวมรายได้', a.Sum_Actual,0) - IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.Sum_Actual,0)),NULL),0) [Actual],
		ISNULL(IIF(a.[No.] = 'กำไรก่อนปรับปรุง', (IIF(a.GroupType = 'รวมค่าใช้จ่าย', a.Sum_Diff,0) - IIF(a.GroupType = 'รวมรายได้', a.Sum_Diff,0)),NULL),0) Diff		
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

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#CombineTable2', 'U') IS NOT NULL
	BEGIN
		DROP TABLE #CombineTable2
    END;

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
), PayVat AS (
	SELECT a.[No.]
		,a.yearMonth
		,a.[Month]
		,'จ่ายภาษีมูลค่าเพิ่ม' [addDetail]
		,ISNULL(a.[Total Budget],0) - ISNULL(b.[Total Budget],0) [addTotal]
		,ISNULL(a.Actual,0) - ISNULL(b.Actual,0) [addActual]
FROM SellVat a
INNER JOIN (
	SELECT [No.]
		,yearMonth
		,[Month]
		,SUM([Total Budget]) [Total Budget]
		,SUM(Actual) Actual
	FROM BuyVat
	GROUP BY [No.],yearMonth,[Month]
) b
ON a.yearMonth = b.yearMonth
-- WHERE a.Detail = 'VAT ขาย' OR b.Detail IN ('VAT ซื้อ','Vat ซื้อ โครงการใหม่')
), VatTotal AS (
	SELECT va.[No.]
		,va.VATDetail [Detail]
		,va.yearMonth [Date]
		,va.[Month]
		,IIF(va.VATDetail = 'VAT ขาย',va.[Total Budget],va.[Total Budget] * 0.07) [Total Budget]
		,va.Actual
		,(ISNULL(va.Actual,0) - ISNULL(IIF(va.VATDetail = 'VAT ขาย',va.[Total Budget],va.[Total Budget] * 0.07),0)) Diff	
FROM #VATprice va
UNION ALL
SELECT v.[No.]
		,v.addDetail [Detail]
		,v.yearMonth [Date]
		,v.[Month]
		,v.addTotal [Total Budget]
		,v.addActual [Actual]
		,(ISNULL(v.addActual,0) - ISNULL(v.addTotal,0)) Diff
FROM PayVat v
)

-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #CombineTable2
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
		,0.00 [RD (%)]
		,0.00 [MTP (%)]
		,0.00 [Diff (MTP - RD)]
		,0.00 [ประมาณการรายได้]
		,0.00 [ผลต่าง+-]
		,0.00 [ประมาณการต้นทุนที่ต้องใช้]
		,0.00 [ประมาณการต้นทุนโครงการใหม่]
		,SUM(vt.[Total Budget]) [Total Budget]
		,SUM(vt.Actual) Actual
		,SUM(vt.Diff) Diff
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.[Total Budget]),SUM(vt.[Total Budget]) * 0.07) [Total Budget] 
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.Actual),SUM(vt.Actual) * 0.07) [Actual]
		-- ,IIF(vt.Detail = 'VAT ขาย', SUM(vt.Diff),SUM(vt.Diff) * 0.07) [Diff]
FROM VatTotal vt
GROUP BY vt.[No.], vt.Detail
) v

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#VarientCombineTable2', 'U') IS NOT NULL
BEGIN
	DROP TABLE #VarientCombineTable2
END;
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #VarientCombineTable2
FROM (
	SELECT [No.]
		,Detail
		,FORMAT(DATEADD(MONTH,1,CAST([Date] + '-01' AS DATE)), 'yyyy-MM','en') [NextYearMonth]
		,FORMAT(DATEADD(MONTH,1,CAST([Date] + '-01' AS DATE)),'MMMM','th') [NextMonth]
		,Diff
	FROM #CombineTable2
	WHERE Date <> '01'
	UNION ALL
	SELECT [No.]
		,Detail
		,'01' [NextYearMonth]
		,'Total' [NextMonth]
		,SUM(Diff) Diff
	from #CombineTable2
	WHERE Date <> '01' AND FORMAT(DATEADD(MONTH,1,CAST([Date] + '-01' AS DATE)), 'yyyy-MM','en') <= FORMAT(@EndDate, 'yyyy-MM','en')
	group by [No.],Detail
) var
/******************** VAT ********************************************/
SELECT ct2.[No.]
		,ct2.Total
		,ct2.GroupType
		,ct2.Sort
		,ct2.Detail
		,ct2.[Date]
		,ct2.[Month]
		,ct2.[RD (%)]
		,ct2.[MTP (%)]
		,ct2.[Diff (MTP - RD)]
		,ct2.[ประมาณการรายได้]
		,ISNULL(vct2.Diff,0) [ผลต่าง+-]
		,ct2.[ประมาณการต้นทุนที่ต้องใช้]
		,ct2.[ประมาณการต้นทุนโครงการใหม่]
		,ct2.[Total Budget]
		,ct2.Actual
		,ct2.Diff
FROM #CombineTable2 ct2
LEFT JOIN #VarientCombineTable2 vct2 ON ct2.[No.] = vct2.[No.] AND ct2.Detail = vct2.Detail AND ct2.[Date] = vct2.[NextYearMonth] AND ct2.[Month] = vct2.[NextMonth]

select * from #SalaryRate
select * from #FareRate
select * from #OnSiteDepreciation
select * from #ManagementWithOutVat
select * from #ManageVat
select * from #AdvertisingExpensesVat
select * from #Subcontract
select * from #Material
select * from #Accouctchart4Profit
select * from #Accouctchart4Vat
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

  IF OBJECT_ID(N'tempdb..#Accouctchart4Profit', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Profit;
    END;

  IF OBJECT_ID(N'tempdb..#Accouctchart4Vat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Vat;
    END;

IF OBJECT_ID(N'tempdb..#CombineTable', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #CombineTable;
    END;

IF OBJECT_ID(N'tempdb..#Variant', N'U') IS NOT NULL
BEGIN
	DROP TABLE #Variant;
END;

IF OBJECT_ID('tempDB..#VAT', 'U') IS NOT NULL
BEGIN
	DROP TABLE #VAT
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
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#CombineTable2', 'U') IS NOT NULL
	BEGIN
		DROP TABLE #CombineTable2
    END;
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#VarientCombineTable2', 'U') IS NOT NULL
BEGIN
	DROP TABLE #VarientCombineTable2
END;