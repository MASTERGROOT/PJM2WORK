UPDATE ChartOfAccounts
SET Name = 'ค่าธรรมเนียมราชการ', AltName = 'ค่าธรรมเนียมราชการ', [Description] = 'ค่าธรรมเนียมราชการ'
WHERE Id = 439
select * FROM ChartOfAccounts WHERE Code LIKE '850501' --ค่าธรรมเนียมราชการ 
UPDATE JVLines
SET AccountName = 'ค่าธรรมเนียมราชการ'
WHERE AccountId = 439
SELECT * FROM JVLines Where AccountId = 439
UPDATE AcctElementSets
SET AccountName = 'ค่าธรรมเนียมราชการ'
WHERE AccountId = 439
SELECT * FROM AcctElementSets where AccountId = 439
