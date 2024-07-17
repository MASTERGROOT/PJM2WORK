select acctid,ca.id from fiscalitems fi left join ChartOfAccounts ca on ca.code = fi.AcctCode where fi.AcctId in (
select id from ExtAccounts extacc where exists ( select *from fiscalitems  fi where fi.AcctId = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update fi set acctid = ca.id from fiscalitems fi left join ChartOfAccounts ca on ca.code = fi.AcctCode where fi.AcctId in (
--select id from ExtAccounts extacc where exists ( select *from fiscalitems  fi where fi.AcctId = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)


select AccountId,ca.id from AcctElementSets aes left join ChartOfAccounts ca on ca.code = aes.AccountCode where aes.AccountId in (
select id from ExtAccounts extacc where exists ( select *from AcctElementSets  aes where aes.AccountId = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update aes set AccountId=ca.id from AcctElementSets aes left join ChartOfAccounts ca on ca.code = aes.AccountCode where aes.AccountId in (
--select id from ExtAccounts extacc where exists ( select *from AcctElementSets  aes where aes.AccountId = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)

select AccountId,ca.id from AcctElementclears aec left join ChartOfAccounts ca on ca.code = aec.AccountCode where aec.AccountId in (
select id from ExtAccounts extacc where exists ( select *from AcctElementclears  aec where aec.AccountId = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update aec set AccountId=ca.id from AcctElementclears aec left join ChartOfAccounts ca on ca.code = aec.AccountCode where aec.AccountId in (
--select id from ExtAccounts extacc where exists ( select *from AcctElementclears  aec where aec.AccountId = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)

select AccountId,ca.id from jvlines jvl left join ChartOfAccounts ca on ca.code = jvl.AccountCode where jvl.AccountId in (
select id from ExtAccounts extacc where exists ( select *from jvlines  jvl where jvl.AccountId = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update jvl set AccountId=ca.id from jvlines jvl left join ChartOfAccounts ca on ca.code = jvl.AccountCode where jvl.AccountId in (
--select id from ExtAccounts extacc where exists ( select *from jvlines  jvl where jvl.AccountId = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)

select acctid,ca.id from FiscalItems fi left join ChartOfAccounts ca on ca.code = fi.acctcode where fi.acctid in (
select id from ExtAccounts extacc where exists ( select *from FiscalItems  fi where fi.acctid = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update fi set acctid=ca.id from FiscalItems fi left join ChartOfAccounts ca on ca.code = fi.acctcode where fi.acctid in (
--select id from ExtAccounts extacc where exists ( select *from FiscalItems  aec where aec.acctid = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)

select acctid,ca.id from OtherPaymentLines opl left join ChartOfAccounts ca on ca.code = opl.acctcode where opl.acctid in (
select id from ExtAccounts extacc where exists ( select *from OtherPaymentLines  opl where opl.acctid = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update opl set acctid=ca.id from OtherPaymentLines opl left join ChartOfAccounts ca on ca.code = opl.acctcode where opl.acctid in (
--select id from ExtAccounts extacc where exists ( select *from OtherPaymentLines  opl where opl.acctid = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)

select acctid,ca.id from OtherreceiveLines orl left join ChartOfAccounts ca on ca.code = orl.acctcode where orl.acctid in (
select id from ExtAccounts extacc where exists ( select *from OtherreceiveLines  orl where orl.acctid = extacc.id)
and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
)

--update orl set acctid=ca.id from OtherreceiveLines orl left join ChartOfAccounts ca on ca.code = orl.acctcode where orl.acctid in (
--select id from ExtAccounts extacc where exists ( select *from OtherreceiveLines  orl where orl.acctid = extacc.id)
--and not exists (select * from ChartOfAccounts ca where ca.id = extacc.id)
--)