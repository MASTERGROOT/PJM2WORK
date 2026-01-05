Declare @AccCode nVarchar(MAX) = '130103'
Declare @CreateDate DATETIME = GETDATE()
Declare @CreateBy nVarchar(MAX) = 'ใส่ชื่อจะได้รู้ว่าใครเพิ่มผัง'
Declare @IsItem INT = 1



Declare @AccId INT = (Select id From ChartOfAccounts Where Code = @AccCode)
Declare @AccName nVarchar(MAX) = (Select Name From ChartOfAccounts Where Code = @AccCode)
Declare @AccGAId INT = (Select GeneralAccount From ChartOfAccounts Where Code = @AccCode)
Declare @AccGAName nVarchar(MAX) = (Select GeneralAccountName From ChartOfAccounts Where Code = @AccCode)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempItem', 'U') IS NOT NULL
DROP TABLE #TempItem
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempItem
FROM [dbo].Itemmetas /* ดึงข้อมูลมาว่าจะเอาจาก ItemMetas หรือ ItemCategories */
-- WHERE /* add search conditions here */
    
IF @IsItem = 1
BEGIN

    /* เพิ่มผังบัญชีของ item */
    INSERT INTO ItemAccounts (GeneralAccount, GeneralAccountCode, GeneralAccountName, AccountCode, AccountName, AccountId, [Status], LastModifiedTimeStamp,LastModifiedBy,ItemMetaId,ItemCategoryId,CreateTimeStamp,CreateBy)
    SELECT @AccGAId GeneralAccount
            ,@AccGAName GeneralAccountCode
            ,@AccGAName GeneralAccountName
            ,@AccCode AccountCode
            ,@AccName AccountName
            ,@AccId AccountId
            ,1 [Status]
            ,@CreateDate LastModifiedTimeStamp
            ,@CreateBy LastModifiedBy
            ,Id ItemMetaId 
            ,NULL ItemCategoryId 
            ,@CreateDate CreateTimeStamp
            ,@CreateBy CreateBy
    from #TempItem
END

ELSE 
BEGIN

    /* เพิ่มผังบัญชีของ item */
    INSERT INTO ItemAccounts (GeneralAccount, GeneralAccountCode, GeneralAccountName, AccountCode, AccountName, AccountId, [Status], LastModifiedTimeStamp,LastModifiedBy,ItemMetaId,ItemCategoryId,CreateTimeStamp,CreateBy)
    SELECT @AccGAId GeneralAccount
            ,@AccGAName GeneralAccountCode
            ,@AccGAName GeneralAccountName
            ,@AccCode AccountCode
            ,@AccName AccountName
            ,@AccId AccountId
            ,1 [Status]
            ,@CreateDate LastModifiedTimeStamp
            ,@CreateBy LastModifiedBy
            ,NULL ItemMetaId 
            ,Id ItemCategoryId 
            ,@CreateDate CreateTimeStamp
            ,@CreateBy CreateBy
    from #TempItem

END

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempItem', 'U') IS NOT NULL
DROP TABLE #TempItem