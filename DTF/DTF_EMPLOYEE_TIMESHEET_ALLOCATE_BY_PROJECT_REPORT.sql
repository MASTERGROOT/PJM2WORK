/*==> Ref:d:\programmanee\prototype-dev-joe\content\printing\reportcommands\bud_employeetimesheetallocatebyprojectforpivotreport.sql ==>*/
 
--=================================================== Variable ============================================================================

--DECLARE	@p0	DATE			= '2024-03-20';
--DECLARE @p1	DATE			= '2024-03-31';


DECLARE @FromDate  DATE = @p0;
DECLARE @ToDate    DATE = @p1;
DECLARE @DateRange INT = DATEDIFF(DAY ,@FromDate,@ToDate)+1;
DECLARE @Minute INT = 60;

--select @DateRange;

--check #temp
	IF  OBJECT_ID(N'tempdb..#DataWorkers') IS NOT NULL	
    BEGIN
            DROP TABLE #DataWorkers
    END

	IF  OBJECT_ID(N'tempdb..#ProjectInfoFromTask') IS NOT NULL	
    BEGIN
            DROP TABLE #ProjectInfoFromTask
    END

	IF  OBJECT_ID(N'tempdb..#TimeSheetInfo') IS NOT NULL	
    BEGIN
            DROP TABLE #TimeSheetInfo
    END
	IF  OBJECT_ID(N'tempdb..#WorkingCalendarData') IS NOT NULL	
    BEGIN
            DROP TABLE #WorkingCalendarData
    END
--=========================== Core ==========================
 SELECT 
           --DENSE_RANK() OVER(ORDER BY Name ASC) AS [No], 
           Name, 
           Code,
		   wk.Id,
		   em.WorkingCalendarId,
		   em.WorkingCalendarCode,
		   em.AnalysisCode,
        	em.RefCode,
		   em.TeamCode
		   into #DataWorkers 
    FROM Workers wk
	LEFT JOIN EmployeeStandardRates em on wk.Id = em.WorkerId 

	SELECT    
	       MAX(tsl.Date) [task Date],
	       tsl.Id [taskId],
           tsl.EmployeeId AS Id, 
           tsl.ProjectName, 
		   tsl.ProjectCode,
           tsl.ProjectId,
           tsl_par.ParentName,
           tsl_par.ParentCode,

		   --Rate
		   cast(max(tsl.OTType) AS DECIMAL(5,2)) [OTType],
		   IIF(MAX(tsl.SystemCategoryId) = 266,sum(tsl.OTRate),null) [OT_Rate],
		   IIF(MAX(tsl.SystemCategoryId) = 266,sum(tsl.HourRate),null) [Workhour_Rate],
		   IIF(max(tsl.SystemCategoryId) = 265 AND absen.LeaveWithOutPay = 0,sum(tsl.HourRate),null) [Absence_Rate],
		   IIF(max(tsl.SystemCategoryId) = 265 AND absen.LeaveWithOutPay = 1,sum(tsl.HourRate),null) [LeaveWithOutPay_Rate],
		   
	      IIF(max(tsl.SystemCategoryId) = 266,CAST(Convert(varchar(5), Sum(DateDiff(minute, 0, tsl.OT)) / @Minute) +'.'+ Convert(char(2), Sum(DateDiff(minute, 0, tsl.OT)) % @Minute) AS DECIMAL(10,2)),NULL) [OT],
	      IIF(max(tsl.SystemCategoryId) = 266,CAST(Convert(varchar(5), Sum(DateDiff(minute, 0, tsl.Hour)) / @Minute) +'.'+ Convert(char(2), Sum(DateDiff(minute, 0, tsl.Hour)) % @Minute) AS DECIMAL(10,2)),NULL) [WorkHour],
		  IIF(max(tsl.SystemCategoryId) = 265 AND absen.LeaveWithOutPay = 0,CAST(Convert(varchar(5), Sum(DateDiff(minute, 0, tsl.Hour)) / @Minute) +'.'+ Convert(char(2), Sum(DateDiff(minute, 0, tsl.Hour)) % @Minute) AS DECIMAL(10,2)),NULL) [Absence],
		  --IIF(max(tsl.SystemCategoryId) = 265 AND absen.LeaveWithOutPay = 1,CAST(Convert(varchar(5), Sum(DateDiff(minute, 0, tsl.Hour)) / @Minute) +'.'+ Convert(char(2), Sum(DateDiff(minute, 0, tsl.Hour)) % @Minute) AS DECIMAL(10,2)),NULL) [LeaveWithOutPay]
		  IIF(max(tsl.SystemCategoryId) = 265 AND absen.LeaveWithOutPay = 1,sum(DATEDIFF(minute, '00:00:00', ISNULL( tsl.Hour , '0:00'))),NULL) [LeaveWithOutPay],

		  bg.LineCode BudgetCode,bg.Name BudgetName

	into #ProjectInfoFromTask
    FROM TaskLists tsl
	left join Absences absen on tsl.AbsenceId = absen.Id 
	left join BudgetLines bg ON bg.Id = tsl.BudgetLineId
	left join (SELECT 
					org.Code,
					org_par.Code [ParentCode],
					org_par.Name [ParentName]
				FROM Organizations org
				LEFT JOIN Organizations org_par on org.Parent = org_par.Id) tsl_par on tsl.ProjectCode = tsl_par.Code
	where  CONVERT(DATE,tsl.Date) between @FromDate and @ToDate	
	group by tsl.Id, tsl.ProjectName ,tsl.ProjectId,tsl.EmployeeId, tsl.ProjectCode,absen.LeaveWithOutPay, tsl_par.ParentName, tsl_par.ParentCode
				,bg.LineCode ,bg.Name 


-- Approved

	select 
             tkl.Id   
			,tkl.EmployeeId
			,tkl.createBy 
			,tkl.ProjectCode
			,tkl.ProjectName
			,tkl.Subject

			--Rate
			,IIF(tsl.SystemCategoryId = 266 ,tkl.HourRate,null) [Approve Workhour_Rate]
			,IIF(tsl.SystemCategoryId = 265 AND absen.LeaveWithOutPay = 0 ,tkl.HourRate,null) [Approve Absence_Rate]
			,IIF(tsl.SystemCategoryId = 266 ,tkl.OTRate,null) [Approve OT_Rate]
			,IIF(tsl.SystemCategoryId = 265 AND absen.LeaveWithOutPay = 1 ,tkl.HourRate,null) [Approve LeaveWithoutPay_Rate]

			,IIF(tsl.SystemCategoryId <> 265,FORMAT(CAST(REPLACE(tkl.Hour, ':', '.') AS DECIMAL(10,2)),'N2'),null) [Approve Workhour]
			,IIF(tsl.SystemCategoryId = 265 AND absen.LeaveWithOutPay = 0,FORMAT(CAST(REPLACE(tkl.Hour, ':', '.') AS DECIMAL(10,2)),'N2'),null) [Approve Absence]
			--,IIF(tsl.SystemCategoryId = 266,FORMAT(CAST(REPLACE(tkl.OT, ':', '.') AS DECIMAL(10,2)),'N2'),null) [Approve OT]
                        ,IIF(tsl.SystemCategoryId = 266 AND (tkl.OT <> ''),FORMAT(CAST(REPLACE(isnull(tkl.OT,'0:00'), ':', '.') AS DECIMAL(10,2)),'N2'),null) [Approve OT]
			,IIF(tsl.SystemCategoryId = 265 AND absen.LeaveWithOutPay = 1,FORMAT(CAST(REPLACE(tkl.Hour, ':', '.') AS DECIMAL(10,2)),'N2'),null) [Approve LeaveWithoutPay]
			
			--,IIF(tsl.SystemCategoryId = 266,tkl.OT,null) [Approve OT]


	
	into #TimeSheetInfo
	from TimeSheetLines tsl
	inner join TaskLists tkl on tkl.Id = tsl.RefTaskId
	inner join Timesheets ts on ts.Id = tsl.TimeSheetId
	left join Absences absen on tkl.AbsenceId = absen.Id
	where 
	ts.Docstatus = 4
	AND CONVERT(DATE,tsl.Date) between @FromDate and @ToDate	
	order by tkl.EmployeeId



             SELECT 
			 CAST(FLOOR(tw.total_work_min / 60.0) + (tw.total_work_min % 60.0) / 100 AS DECIMAL(10,2)) total_work,
			 * 
			 into #WorkingCalendarData
			 from(  
			          select
					  wkc.Code AS WorkingCalendarCode,
					  wkc.HourWork,
					  @DateRange - COUNT(wh.WorkingCalendarId) AS [work_days],
					  COUNT(wh.WorkingCalendarId) AS [holiday],
					 
					  DATEDIFF(minute, '00:00:00', ISNULL( replace(cast(wkc.HourWork AS DECIMAL(10,2)),'.',':') , '0:00'))* (@DateRange - COUNT(wh.WorkingCalendarId)) total_work_min
			
			FROM 
					  WorkingCalendars wkc
					  LEFT OUTER JOIN WorkingCalendarHolidays wh ON wkc.Id = wh.WorkingCalendarId AND CONVERT(DATE, wh.Date) BETWEEN @FromDate AND @ToDate
			 GROUP BY 
					  wkc.HourWork,
					  wkc.Code) tw


SELECT 
		DENSE_RANK() OVER(ORDER BY work.Code ASC) AS [No],
		work.Name, 
		work.Code, 
		--work.AnalysisCode,
		--work.RefCode [Ref.Code],
		work.TeamCode [Team Code],
		--'' AS [ORG], 
		REPLACE(CAST(FLOOR(((wc.Total_Work_Min)-ISNULL((pI.LeaveWithOutPay),0)) / 60.0) +
			(((wc.Total_Work_Min)-ISNULL((pI.LeaveWithOutPay),0)) % 60.0) / 100 AS DECIMAL(10,2)),'.',':') [Total Working],
		wc.total_work - ISNULL(pI.LeaveWithOutPay_Rate,0.00) [Total Working_M100],

		--CAST(floor( (wc.total_work_min - ISNULL(pI.LeaveWithOutPay,0.00))/60)+(( wc.total_work_min - ISNULL(pI.LeaveWithOutPay,0.00))%60/100) AS DECIMAL(10,2)) [Total Working],
		CASE WHEN pI.ProjectName LIKE 'HO' THEN ''
			 ELSE pI.ProjectName
		END [Task Org Name],
		CASE WHEN pI.ProjectCode LIKE 'HO' THEN ''
			 ELSE pI.ProjectCode 
		END [Task Org Code],

		--pI.ParentName [Parent Name],
		--pI.ParentCode [Parent Code],
		REPLACE(ISNULL(pI.WorkHour,0.00),'.',':') [WorkHour],
		--ISNULL(pI.Workhour_Rate,0.00) [WorkHour_M100],

		CASE WHEN wc.total_work <> 0 THEN CAST(ROUND((ISNULL(pI.WorkHour,0.00)/cast(wc.total_work AS DECIMAL(6,2)))*100,2) AS DECIMAL(10,2)) 	   
			 ELSE CAST(ROUND((ISNULL(pI.WorkHour,0.00)/1.00)*100,2) AS DECIMAL(10,2))
		END AS [Percent_Workhour],

		--REPLACE(ISNULL(tsi.[Approve Workhour],0.00),'.',':') [Approve WorkHour],
		--ISNULL(tsi.[Approve Workhour_Rate],0.00) [Approve WorkHour_M100],	  
	   
		--CASE WHEN wc.total_work <> 0 THEN CAST(ROUND((ISNULL(tsi.[Approve Workhour],0.00)/cast(wc.total_work AS DECIMAL(6,2)))*100,2) AS DECIMAL(10,2))	   
		--	 ELSE CAST(ROUND((ISNULL(tsi.[Approve Workhour],0.00)/1.00)*100,2) AS DECIMAL(10,2))
		--END AS [Percent_Approve_Workhour],

		REPLACE(ISNULL(PI.OT,0.00),'.',':') [OT],
		--ISNULL(pI.OT_Rate,0.00) [OT_M100],
		--REPLACE(ISNULL(tsi.[Approve OT],0.00),'.',':') [Approve OT],
		--ISNULL(tsi.[Approve OT_Rate],0.00) [Approve OT_M100],
		ISNULL( pI.OTType,0.00) [OTType],	  
		REPLACE(ISNULL(pI.Absence,0.00),'.',':') [Absence],
		--ISNULL(pI.Absence_Rate,0.00) [Absence_M100],	   

		--CASE WHEN wc.total_work <> 0 THEN CAST(ROUND((ISNULL(pI.Absence,0.00)/cast(wc.total_work AS DECIMAL(6,2)))*100,2) AS DECIMAL(10,2))
		--	 ELSE CAST(ROUND((ISNULL(pI.Absence,0.00)/1.00)*100,2) AS DECIMAL(10,2))
		--END AS [Percent_Absence],

		--REPLACE(ISNULL(tsi.[Approve Absence],0.00),'.',':') [Approve Absence],
		--ISNULL(tsi.[Approve Absence_Rate],0.00) [Approve Absence_M100],

		--CASE WHEN wc.total_work <> 0 THEN CAST(ROUND((ISNULL(tsi.[Approve Absence],0.00)/cast(wc.total_work AS DECIMAL(6,2)))*100,2) AS DECIMAL(10,2))
		--	 ELSE CAST(ROUND((ISNULL(tsi.[Approve Absence],0.00)/1.00)*100,2) AS DECIMAL(10,2))
		--END AS [Percent_Approve_Absence],

		--replace(CAST(FLOOR((ISNULL((pI.LeaveWithOutPay),0)) / 60.0) + ((ISNULL((pI.LeaveWithOutPay),0)) % 60.0) / 100 AS DECIMAL(10,2)),'.',':') [LeavWithoutPay],
		--ISNULL(pI.LeaveWithOutPay_Rate,0.00) [LeaveWithOutPay_M100],
	  
		--REPLACE(ISNULL(tsi.[Approve LeaveWithoutPay],0.00),'.',':') [Approve_LeaveWithoutPay],
		--ISNULL(tsi.[Approve LeaveWithoutPay_Rate],0.00) [Approve_LeaveWithoutPay_M100],
		pI.[task Date],
		--ol.OrgCodeLv1,
		--ol.OrgCodeLv2	 
		pI.BudgetCode,pI.BudgetName
FROM #DataWorkers work 
LEFT JOIN #ProjectInfoFromTask pI ON work.Id = pI.Id 
LEFT JOIN #TimeSheetInfo tsi ON tsi.Id = pI.taskId
LEFT JOIN #WorkingCalendarData wc on wc.WorkingCalendarCode = work.WorkingCalendarCode
--LEFT JOIN (
--	select o.Id OrgId, max(iif(o3.[Level] = 2, o3.Code, '')) OrgCodeLv1, max(iif(o3.[Level] = 3, o3.Code, '')) OrgCodeLv2
--	from Organizations o
--	cross apply string_split(replace(replace(o.Path,'||',','),'|',''),',') s
--	cross apply (
--		select o2.Level, o2.Code, o2.Name 
--		from Organizations o2 
--		where o2.Id = s.value
--		and o2.Level in (2, 3)
--	) o3
--	cross apply (
--		select t.ProjectId
--		from #ProjectInfoFromTask t 
--		where t.ProjectId = o.Id 
--	) o4
--	group by o.Id 
--) ol on pI.ProjectId = ol.OrgId
where pI.ProjectName is not null
--AND pI.Id = 17
ORDER BY work.Code ASC


/*=========================== Filter ===========================*/

SELECT 
	CONCAT('Period From  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  To ',FORMAT(@ToDate,'dd/MM/yyyy')) [FilterDate]

	--check #temp again
	IF  OBJECT_ID(N'tempdb..#DataWorkers') IS NOT NULL	
    BEGIN
            DROP TABLE #DataWorkers
    END

	IF  OBJECT_ID(N'tempdb..#ProjectInfoFromTask') IS NOT NULL	
    BEGIN
            DROP TABLE #ProjectInfoFromTask
    END
	IF  OBJECT_ID(N'tempdb..#TimeSheetInfo') IS NOT NULL	
    BEGIN
            DROP TABLE #TimeSheetInfo
    END
	IF  OBJECT_ID(N'tempdb..#WorkingCalendarData') IS NOT NULL	
    BEGIN
            DROP TABLE #WorkingCalendarData
    END