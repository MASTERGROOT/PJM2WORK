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
where jl.AccountCode LIKE '2%'/* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) */
		-- and s.isDebit = 0
		and (CONVERT(DATE,ISNULL(NULLIF(s.DocDate,''),j.Date)) BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (ISNULL(s.OrgId,j.OrgId) in (select Id from #temporg) or @ProjectId is NULL)
		-- and i.SystemCategoryId not in (123,129)
)a group by a.Date/* ,a.AcctCode */
SELECT * from #Accouctchart4NoVat
SELECT * from #Accouctchart4Vat
-- select [Month], SUM([หมวด 2]) [หมวด 2]
-- from (SELECT MONTH([Date]) [Month], SUM(AmtMaterial) [หมวด 2] from #Accouctchart4NoVat GROUP by [Date]) a
-- group by Month

-- select [Month], SUM([หมวด 2]) [หมวด 2], AcctCode
-- from (SELECT MONTH([Date]) [Month], SUM(AmtMaterial) [หมวด 2],AcctCode from #Accouctchart4NoVat GROUP by [Date],AcctCode) a
-- -- WHERE [Month] = 6
-- group by Month,AcctCode

-- select CASE WHEN ISNULL(s.isDebit,jl.isDebit) <> ga.minusWhenDebit THEN ISNULL(s.Amount,jl.Amount) ELSE ISNULL(s.Amount,jl.Amount)*-1 END [Amount]
-- 				,ISNULL(s.DocDate,j.[Date]) [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
-- 				,s.OrgCode
-- 				,s.DocType
-- 				,s.DocCode
-- FROM	    dbo.JVLines jl WITH (nolock)
-- 			   INNER JOIN dbo.JournalVouchers j WITH (NOLOCK) ON jl.JournalVoucherId = j.Id AND ISNULL(j.DocStatus,0) <> -1									
-- 			   LEFT JOIN dbo.GeneralAccountEntities ga WITH (NOLOCK) ON ga.EnumKey = jl.GeneralAccount
-- 			   LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON IIF(ISNULL(jl.OrgId,0) IN (0,-1),j.OrgId,jl.OrgId) = o.Id
-- 			   LEFT JOIN dbo.AcctElementSets s WITH (NOLOCK) ON s.JVLineId = jl.Id --AND jl.MadeByDocTypeId = 149
-- where jl.AccountCode LIKE '2%'/* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
-- 						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
-- 						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) */
-- 		-- and s.isDebit = 0
-- 		and (CONVERT(DATE,ISNULL(NULLIF(s.DocDate,''),j.Date)) BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
-- 		and (ISNULL(s.OrgId,jl.OrgId) in (select Id from #temporg) or @ProjectId is NULL)
-- 		-- and i.SystemCategoryId not in (123,129)
-- 		and MONTH(ISNULL(s.DocDate,j.[Date])) = 6
		


  IF OBJECT_ID(N'tempdb..#Accouctchart4Vat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4Vat;
    END;
  IF OBJECT_ID(N'tempdb..#Accouctchart4NoVat', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #Accouctchart4NoVat;
    END;

