Declare @AccCode nVarchar(MAX) = '2-100-304'
Declare @Code nVarchar(MAX) = 'TH-14'


Declare @AccId INT = (Select id From ChartOfAccounts Where Code = @AccCode)
Declare @AccName nVarchar(MAX) = (Select Name From ChartOfAccounts Where Code = @AccCode)



Update TaxMetas SET AcctId = @AccId , AcctCode = @AccCode , AcctName = @AccName Where Code = @Code

Select c.Id AccId,t.AcctId,t.AcctCode,t.AcctName,* 
From TaxMetas t
Left Join ChartOfAccounts c ON c.Code = t.AcctCode
Order By t.Code