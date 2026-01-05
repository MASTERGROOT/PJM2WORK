Declare @AccCode nVarchar(MAX) = '1-100-321'
Declare @ID INT = 9


Declare @AccId INT = (Select id From ChartOfAccounts Where Code = @AccCode)
Declare @AccName nVarchar(MAX) = (Select Name From ChartOfAccounts Where Code = @AccCode)


Update FiscalMetas SET AcctId = @AccId , AcctCode = @AccCode , AcctName = @AccName Where Id = @ID
-- Update FiscalMetas SET AcctId = NULL , AcctCode = NULL , AcctName = NULL Where Id = @ID

Select c.Id AccId,f.AcctId FiscalAcctId,f.AcctCode,f.AcctName,* 
From FiscalMetas f
Left Join ChartOfAccounts c ON c.Code = f.AcctCode

-- -- SELECT * from FiscalItems where SystemCategoryId = 58

-- -- select * from BankAccts