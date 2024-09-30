
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
-- VALUES  ( N'WORKER ROLE MENU REPORT' , -- Name - nvarchar(250)
--          4 , -- Column - smallint --¹Ñº¨Ò¡´éÒ¹ã¹àÁ¹Ù à»ç¹¤ÍÅÑÁá¹ÇµÑé§
--          N'LIST MANAGER/GPW REPORT' , -- Path - nvarchar(1000)
--          LOWER(NEWID()) , -- MenuId - nvarchar(100)
--          NULL , -- InActive - bit
--          N'WORKER ROLE MENU REPORT' , -- Description - nvarchar(500)
--          900.0001 , -- SortOrder - decimal --¡´´Ù¤èÒ INDEX ã¹ Inspect *¶éÒÍÂÙèã¹àÁ¹Ùà´ÔÁ¤èÒ¨Ø´·È¹ÔÂÁ ÁÒ¡¡ÇèÒµÑÇà´ÔÁ | áµè¶éÒàÁ¹ÙãËÁè ãËé¤èÒÁÒ¡¡ÇèÒã¹ËÅÑ¡Ë¹èÇÂ
--          90901 , -- DoctypeId - int
--          90901 , -- DoctypeName - nvarchar(max)
-- 		 90901 , -- DoctypeId - int
--          N'/Report/Worker_Role_Menu_Report/Form'  -- List - nvarchar(500)
--        )


--  Delete dbo.CompanyMenuConfigs where Id = 2

-- 	update dbo.CompanyMenuConfigs
--    SET [Description] = 'GPW GL Movement Detail Report'
-- 	WHERE  id= 1
	 
	-- select*from CompanyMenuConfigs --Order By Path,id --DoctypeId--SortOrder--Path --where Path = 'JOB/AAG BUDGET REPORT'


-- Update CompanyMenuConfigs Set Path = 'PROJECT/THS REPORT' where id = 1

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

-- SET IDENTITY_INSERT SubDocTypes ON
-- SELECT * FROM SubDocTypes WHERE Id = 270 

-- UPDATE SubDocTypes 
-- SET PrintSetting = (select PrintSetting From SubDocTypes where Id = 61)
-- WHERE DocTypeId = 2

-- SELECT * FROM SubDocTypes WHERE DocTypeId = 438

-- INSERT INTO SubDocTypeCustomNoteMetas (CustomNoteMetaId,DocType,DocTypeId,SubDocTypeId,SortOrder,DefaultValue,SectionSort,[Required],Condition,[Type],Copies,UserName,Role)
-- SELECT CustomNoteMetaId,DocType,DocTypeId,160,SortOrder,DefaultValue,SectionSort,[Required],Condition,[Type],Copies,UserName,Role 
-- FROM SubDocTypeCustomNoteMetas
-- WHERE Id = 483

-- SELECT * FROM SubDocTypeCustomNoteMetas WHERE DocTypeId = 2 --AND SubDocTypeId = 236



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
SELECT * FROM SubDocTypes WHERE DocTypeId = 50
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

-- SELECT * FROM CustomNoteMetas

-- INSERT INTO SubDocTypeCustomNoteMetas (CustomNoteMetaId, DocType, DocTypeId, SubDocTypeId, SortOrder, DefaultValue,SectionSort,[Required],[Condition],[Type],Copies,UserName,[Role])
-- SELECT CustomNoteMetaId, DocType, DocTypeId, 481, SortOrder, DefaultValue,SectionSort,[Required],[Condition],[Type],Copies,UserName,[Role]
-- FROM SubDocTypeCustomNoteMetas
-- WHERE Id = 270

-- UPDATE SubDocTypeCustomNoteMetas
-- SET [Role] = (select [Role] from SubDocTypeCustomNoteMetas where Id = 139)
-- where Id IN (140,141,142,143,144)


-- select * FROM SubDocTypeCustomNoteMetas where DocType LIKE '%OtherReceive%'


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
