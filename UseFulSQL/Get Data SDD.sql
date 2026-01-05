--- SubDoctype ---
select a.*
from
(
select DocType,Name,AutoRunPattern,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(PrintSetting,'[',''),']',''),'{',''),'}',''),':',''),'"',''),'FormPrintingName',''),'PrintCopy,',''),'WaterMark,',''),'Condition,',''),'Signature,',''),'Defaultfalse,',''),'Defaulttrue,',''),',Defaultfalse',''),',Defaulttrue',''),',PrintCopy�鹩�Ѻ',''),',����','') Prinsetting,JournalCode,JournalName,IsRekey
from SubDocTypes
)a
order by a.Prinsetting,a.DocType
--- ORG ---
select id,Code,Name,OrgCategory,OrgCategoryName,Parent from Organizations where OrgCategory not in (80,85)


--- Worker ---
Select Code,UserName,Name,Position,Email,WorkerType,st.SeatTypeName
from workers wk
left join  UserSeats us on wk.Id = us.WorkerId
left join SeatTypeLogs st on st.Id = us.SeatTypeId
Where wk.Code not in ('GOD')

--- JOURNAL ---
select Code,Name,Description,Prefix from Journals

--- TAX ---
select code,Description,SystemCategory,GeneralAccount,GeneralAccountName,AcctCode,AcctName from TaxMetas

--- Chart Of Account ---
select id,Code,Name,Description,Parent,Level,GeneralAccountName from ChartOfAccounts


--- CBS ---
select code,Name,Description,Parent,Level from CBS


--- Bank ---
select bankcode,AcctNumber,AcctName,CallName,AcctCode,code,BookName,Description,BankAcctCurrency,Branch,Type from BankAccts


--- Material ---
select *--a.Level,a.Code,a.Name,a.CBSCode,REPLACE(a.AccountCode,',',' / ') AccountCode
from
(
select itc.level,itc.code,itc.Name,cat.Code [ItemCategoryCode],cat.Name [ItemCategoryName],itc.CBSCode,itc.CBSName,dbo.GROUP_CONCAT(ita.AccountCode) AccountCode,itc.SystemCategoryId,itc.StockMethod,itc.StockMethodName,itc.CountUnitId,itc.CountUnitName
from ItemCategories itc
left join ItemAccounts ita on ita.ItemCategoryId = itc.id
LEFT JOIN ItemCategories cat ON cat.Id = itc.Parent
group by itc.Level,itc.Code,itc.Name,itc.CBSCode,itc.SystemCategoryId,itc.CBSName,cat.Code,cat.Name,itc.StockMethod,itc.StockMethodName,itc.CountUnitId,itc.CountUnitName
Union ALL
select 0 level,code,Name,itm.ItemCategoryCode,itm.ItemCategoryName,CBSCode,CBSName,dbo.GROUP_CONCAT(AccountCode) AccountCode,SystemCategoryId,itm.StockMethod,itm.StockMethodName,itm.CountUnitId,itm.CountUnitName
from ItemMetas itm
left join ItemAccounts ita on ita.ItemMetaId = itm.Id
group by Code,Name,CBSCode,SystemCategoryId,CBSName,ItemCategoryCode,ItemCategoryName,itm.StockMethod,itm.StockMethodName,itm.CountUnitId,itm.CountUnitName
UNION ALL
SELECT 0 level,a.Code,a.Name,a.AssetCategoryCode ItemCategoryCode,a.AssetCategoryName ItemCategoryName, NULL CBSCode, NULL CBSName
,dbo.GROUP_CONCAT(ita.AccountCode) AccountCode, 33 SystemCategoryId,a.StockMethod,a.StockMethodName,a.CountUnitId,a.CountUnitName
from Assets a
LEFT JOIN ItemAccounts ita ON a.Id = ita.AssetId
GROUP BY a.Code,a.Name,a.AssetCategoryCode,a.AssetCategoryName,a.StockMethod,a.StockMethodName,a.CountUnitId,a.CountUnitName

)a
where /* SystemCategoryId = 33 AND */ ItemCategoryCode IS NOT NULL
order by Code

SELECT * from ItemCategories where SystemCategoryId IN (33,100,99)
--- LOA ---
select	IIF(line_NO = 1,a.EntityName,NULL) EntityName
		,IIF(line_NO = 1,a.Description,NULL) Description
		,IIF(line_NO = 1,a.SortOrder,NULL) SortOrder
		,a.FromState
		,a.ToState
		,a.Role
from
(
select row_number() over (partition by loa.id order by loa.id) line_NO,loa.EntityName,loa.Description,loa.SortOrder,loal.FromState,loal.ToState,loal.Role from LineOfApprovals loa
left join LineOfApproveDetails loal on loal.LineOfApprovalId = loa.Id
)a


--- Custom Note ---
select GroupName,KeyName,Label,Components,Description from CustomNoteMetas


--- From ---

select DocType,ServiceName,Description,REPLACE(REPLACE(REPLACE(Forms,'["',''),'"]',''),'"',''),*
from CompanyPrintingConfigs
where CommandName like '%STDFRE_V1%'
-- SELECT * from CompanyPrintingConfigs
