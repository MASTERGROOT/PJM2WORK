/*==> Query รายงาน Next Approver ==>*/
Use longkongstudioManee

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
IF OBJECT_ID(N'tempdb..#tmpUserRoleApprove') IS NULL BEGIN 
	CREATE TABLE #tmpUserRoleApprove (RoleCode NVARCHAR(50),UserName NVARCHAR(100)) 
	CREATE CLUSTERED INDEX IDX_C_#tmpUserRoleApprove ON #tmpUserRoleApprove(RoleCode) 
END
IF OBJECT_ID(N'tempdb..#tmpUserRole') IS NULL 	
BEGIN	
	CREATE TABLE #tmpUserRole (RoleCode NVARCHAR(50),NameOfUser NVARCHAR(100),UserName NVARCHAR(100),Position NVARCHAR(150),MemberProject INT)  
	CREATE CLUSTERED INDEX IDX_C_#tmpUserRole ON #tmpUserRole(RoleCode)    
END
IF OBJECT_ID(N'tempdb..#tmpDocLineApprove') IS NULL 	
BEGIN	
	CREATE TABLE #tmpDocLineApprove (RowNumber INT,OrgId INT,OrgCode NVARCHAR(100),OrgName NVARCHAR(200),DocDate DATETIME,DocType NVARCHAR(50),DocCode NVARCHAR(100),Progress NVARCHAR(2000))
	CREATE CLUSTERED INDEX IDX_C_#tmpDocLineApprove ON #tmpDocLineApprove(RowNumber)    
END
DECLARE @OrgCode NVARCHAR(MAX)
DECLARE @DocType NVARCHAR(MAX)
DECLARE @DateStart DATETIME = DATEADD(Month,-1,GETDATE())/* '1900-01-01' */, @DateEnd DATETIME = GETDATE()/* '2479-12-31' */

/*===> Filter =================================================================================================================================================================*/
/*===> Filter Role && UserName ================================================================================================================================================*/
insert into #tmpUserRoleApprove
values ('All','All')
--,('Timesheet','patai'),('Timesheet','preeyaporn')
--,('TS_APPROVE_PD','Jiradit')
--,('Timesheet','Jiradit')
--,('@Jiradit','Jiradit')
/*===> Filter Org =============================================================================================================================================================*/
--set @OrgCode = '6011,6021'
/*===> Filter DocType =========================================================================================================================================================*/
set @DocType = 'TimeSheet'
/*===> Filter DateRange =======================================================================================================================================================*/
set @DateStart = '2023-10-01'
set @DateEnd = '2023-11-27'
/*===> Filter =================================================================================================================================================================*/

declare @notFilterUserRole bit = 1
if (select count(*) from #tmpUserRoleApprove where RoleCode != 'All')>0
begin 
	set @notFilterUserRole = 0
end

insert into #tmpDocLineApprove
select row_number() over (order by d.OrgCode, d.DocDate, d.DocTypeId, d.DocId, p.LineNumber), 
d.OrgId, d.OrgCode, d.OrgName, d.DocDate, d.DocType, d.DocCode, ltrim(trim(p.Progress))
from DocLineOfApproves d
inner join LineOfApproveDetailProgresses p on d.Id = p.DocLineOfApproveId
where d.LineOfApproveState != 'done'
and ltrim(rtrim(isnull(p.Progress,''))) not in ('','true')

insert into #tmpUserRole
select r.Code RoleCode, w.Name NameOfUser, w.UserName, w.Position, isnull(om.OrganizationId,-1)
from OrganizationMembers om 
inner join Roles r on om.RoleId = r.Id 
inner join Workers w on om.WorkerId = w.Id 
where w.WorkStatus = 1 
and w.isEmployee = 1
and exists (select 1 from #tmpDocLineApprove t where t.OrgId = om.OrganizationId)
group by r.Code, w.Name, w.UserName, w.Position, isnull(om.OrganizationId,-1)
	 

insert into #tmpUserRole
select '@'+ltrim(w.UserName), w.Name NameOfUser, w.UserName, w.Position, isnull(om.OrganizationId,-1)
from OrganizationMembers om 
inner join Roles r on om.RoleId = r.Id 
inner join Workers w on om.WorkerId = w.Id 
where w.WorkStatus = 1 
and w.isEmployee = 1
and exists (select 1 from #tmpDocLineApprove t where t.OrgId = om.OrganizationId)
group by w.Name, w.UserName, w.Position, isnull(om.OrganizationId,-1)

-- select OrgCode, OrgName, DocDate, DocType, DocCode, Progress, NameOfUser, UserName, Position
-- from (
-- 	select * 
-- 	from #tmpDocLineApprove d
-- 	cross apply string_split(replace(replace(progress,'||',','),'&&',','),',') s
-- ) d
-- inner join (
-- 	select r.*
-- 	from #tmpUserRole r
-- 	where exists (select 1 from #tmpUserRoleApprove ar where r.RoleCode = ar.RoleCode and r.UserName = ar.UserName)
-- 	or (@notFilterUserRole = 1)
-- ) r on d.value = r.RoleCode and (d.OrgId = -1 or d.OrgId = r.MemberProject)
-- where (isnull(@OrgCode,'') = '' or OrgCode in (select value from string_split(@OrgCode,',')))
-- and (isnull(@DocType,'') = '' or DocType in (select value from string_split(@DocType,',')))
-- and (convert(datetime,convert(nvarchar(10),DocDate,120)) between convert(datetime,convert(nvarchar(10),@DateStart, 120)) and convert(datetime,convert(nvarchar(10),@DateEnd, 120)))

/*===> All For Filter Role && UserName ==============================================================>*/
select RoleCode, UserName, NameOfUser, Position, MemberProject 
from #tmpUserRole
/*==> All For Filter Org =============================================================================*/
select OrgCode, OrgName from DocLineOfApproves group by OrgCode, OrgName
/*==> All For Filter DocType =============================================================================*/
select DocType from DocLineOfApproves group by DocType

IF OBJECT_ID(N'tempdb..#tmpUserRole') IS NOT NULL BEGIN DROP TABLE #tmpUserRole END 
IF OBJECT_ID(N'tempdb..#tmpUserRoleApprove') IS NOT NULL BEGIN DROP TABLE #tmpUserRoleApprove END
IF OBJECT_ID(N'tempdb..#tmpDocLineApprove') IS NOT NULL BEGIN DROP TABLE #tmpDocLineApprove END
