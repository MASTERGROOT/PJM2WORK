
-- INSERT INTO dbo.CompanyMenuConfigs
--        ( Name ,
--          [Column] ,
--          Path ,
--          MenuId ,
--          InActive ,
--          Description ,
--          SortOrder ,
--          DoctypeId ,
--          DoctypeName ,
-- 		  DocAccessId ,
--          List
--        )
-- VALUES  ( N'GPW REAL ESTATE REPORT' , -- Name - nvarchar(250)
--          4 , -- Column - smallint --¹Ñº¨Ò¡´éÒ¹ã¹àÁ¹Ù à»ç¹¤ÍÅÑÁá¹ÇµÑé§
--          N'PROJECT/GPW REPORT' , -- Path - nvarchar(1000)
--          LOWER(NEWID()) , -- MenuId - nvarchar(100)
--          NULL , -- InActive - bit
--          N'' , -- Description - nvarchar(500)
--          100.0001 , -- SortOrder - decimal --¡´´Ù¤èÒ INDEX ã¹ Inspect *¶éÒÍÂÙèã¹àÁ¹Ùà´ÔÁ¤èÒ¨Ø´·È¹ÔÂÁ ÁÒ¡¡ÇèÒµÑÇà´ÔÁ | áµè¶éÒàÁ¹ÙãËÁè ãËé¤èÒÁÒ¡¡ÇèÒã¹ËÅÑ¡Ë¹èÇÂ
--          90101 , -- DoctypeId - int
--          90101 , -- DoctypeName - nvarchar(max)
--          90101 , -- DoctypeId - int
--          N'/Report/HCE_ProfitRealEstateReport/Form'  -- List - nvarchar(500)
--        )


--  Delete dbo.CompanyMenuConfigs where Id = 2

-- 	update dbo.CompanyMenuConfigs
--    SET [List] = N'/Report/GPW_ProfitRealEstateReport/Form'
-- 	WHERE  id= 10
	 
-- 	select*from CompanyMenuConfigs --Order By Path,id --DoctypeId--SortOrder--Path --where Path = 'JOB/AAG BUDGET REPORT'


-- Update CompanyMenuConfigs Set Path = 'PROJECT/THS REPORT' where id = 1

/* เพิ่มผังบัญชีของ item */
-- INSERT INTO ItemAccounts (GeneralAccount, GeneralAccountCode, GeneralAccountName, AccountCode, AccountName, AccountId, [Status],ItemMetaId)
-- SELECT 403 GeneralAccount
--         ,'SaleRev' GeneralAccountCode
--         ,'SaleRev' GeneralAccountName
--         ,412001 AccountCode
--         ,'รายได้จากการขาย' AccountName
--         ,172 AccountId
--         ,1 [Status]
--         ,i.id ItemMetaId
-- from ItemMetas i WHERE i.id <> 1

/* อัพเดต Print setting  */
-- UPDATE SubDocTypes 
-- SET PrintSetting = (select PrintSetting From SubDocTypes where Id = 265)
-- WHERE DocTypeId = 156

-- SELECT * FROM SubDocTypes WHERE DocTypeId = 156

/* เพิ่ม Custom Note ให้เอกสาร  */
-- INSERT INTO SubDocTypeCustomNoteMetas (CustomNoteMetaId,DocType,DocTypeId,SubDocTypeId,SortOrder,DefaultValue,SectionSort,[Required],Condition,[Type],Copies,UserName,Role)
-- SELECT CustomNoteMetaId,DocType,DocTypeId,606,SortOrder,DefaultValue,SectionSort,[Required],Condition,[Type],Copies,UserName,Role 
-- FROM SubDocTypeCustomNoteMetas
-- WHERE Id = 607
-- select * from subdoctypes WHERE DocTypeId = 64
-- SELECT * from SubDocTypeCustomNoteMetas    where DocTypeId = 64

/* update Custom Note ให้เอกสาร  */
-- UPDATE SubDocTypeCustomNoteMetas
-- SET [Role] = (select [Role] from SubDocTypeCustomNoteMetas where Id = 543)
-- where Id IN (SELECT Id from SubDocTypeCustomNoteMetas WHERE DocTypeId = 43 AND SubDocTypeId IN (SELECT Id from SubDocTypes WHERE DocTypeId = 43 AND Name LIKE '%ค่าใช้จ่ายอื่นๆ%'))


/* update Parallel */
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 97
-- WHERE Id = 100
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 98
-- WHERE Id = 101
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 99
-- WHERE Id = 102
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 176
-- WHERE Id = 177
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 227
-- WHERE Id = 230
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 228
-- WHERE Id = 231
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 229
-- WHERE Id = 232
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 279
-- WHERE Id = 280
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 330
-- WHERE Id = 333
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 331
-- WHERE Id = 334
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 332
-- WHERE Id = 335
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 382
-- WHERE Id = 383
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 433
-- WHERE Id = 436
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 434
-- WHERE Id = 437
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 435
-- WHERE Id = 438
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 485
-- WHERE Id = 486
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 536
-- WHERE Id = 539
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 537
-- WHERE Id = 540
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 538
-- WHERE Id = 541
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 588
-- WHERE Id = 589
-- SELECT * FROM SubDocTypes WHERE DocTypeId = 166
--123 : gpw, 
-- 186 : gpw re, 
-- 250: 100, 
-- 289 : 100 re, 
-- 353: 200, 
-- 392 : 200 re,
-- 456: 300, 
-- 495 : 300 re,
-- 559: 400, 
-- 598 : 400 re,  

/* Acct ของ asset cate */
-- SELECT ic.Code, ic.Name, STRING_AGG(ia.AccountCode,', ') AccountCode, ic.SystemCategory Type, ic.[Path] FROM ItemCategories ic
-- Cross APPLY (select * from ItemAccounts where ItemCategoryId = ic.Id) ia
-- WHERE ic.SystemCategoryId = 33
-- GROUP BY ic.Code, ic.Name, ic.SystemCategory, ic.[Path]

/* ไว้ทำ SSD */
-- SELECT
-- IIF(ISJSON(PrintSetting) = 1,
-- -- IIF(ISJSON(JSON_Query(PrintSetting,'$[9]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[5].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[6].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[7].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[8].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[9].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[8]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[5].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[6].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[7].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[8].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[7]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[5].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[6].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[7].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[6]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[5].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[6].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[5]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[5].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[4]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[4].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[3]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[3].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[2]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[2].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[1]')) = 1,CONCAT(JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),',',JSON_VALUE(PrintSetting,'$[1].FormPrintingName')),
-- IIF(ISJSON(JSON_Query(PrintSetting,'$[0]')) = 1,JSON_VALUE(PrintSetting,'$[0].FormPrintingName'),
--         NULL ))))))))
-- ),NULL)
-- ,*
--   FROM SubDocTypes
