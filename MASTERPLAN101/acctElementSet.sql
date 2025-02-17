/*==> Ref:d:\programmanee\prototype-thsd\notpublish\customprinting\reportcommands\mtp101_tax_planning_report.sql ==>*/
 

DECLARE @p0 DATE = '2024-01-01'
DECLARE @p1 DATE = '2024-01-31'
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

-- select * from #temporg

select DISTINCT s.Amount
				,MONTH(s.DocDate) [Date]--FORMAT(s.DocDate ,'yyyyMM')  [Date]
				,s.OrgCode
				-- ,Case when i.SystemCategoryId in (123,129) then 'Vat'
				-- 		else 'NoVat'
				-- 	end vat
				,s.DocType
				,s.DocCode,s.isDebit
from AcctElementSets s
where  s.GeneralAccount LIKE '4%'/* s.AccountCode LIKE '4%' *//* (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600
						,41000601,41000102,41000202,41000302,41000402,41000502,41000602,41000700
						,41000701,41000702,41000703,41000704,41000705,41000707,41000708) */
		-- and s.isDebit = 0
		and (s.DocDate BETWEEN @startDate AND @endDate OR (@startDate IS NULL AND @endDate IS NULL) OR (@startDate = '' AND @endDate = '')  )
		and (s.OrgId in (select Id from #temporg) or @ProjectId is NULL)

 IF OBJECT_ID(N'tempdb..#temporg', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #temporg;
    END;