
--INSERT INTO dbo.CompanyMenuConfigs
--        ( Name ,
--          [Column] ,
--          Path ,
--          MenuId ,
--          InActive ,
--          Description ,
--          SortOrder ,
--          DoctypeId ,
--          DoctypeName ,
--		  DocAccessId ,
--          List
--        )
--VALUES  ( N'CAG COPORATE BUDGET ITEM REPORT' , -- Name - nvarchar(250)
--          3 , -- Column - smallint --¹Ñº¨Ò¡´éÒ¹ã¹àÁ¹Ù à»ç¹¤ÍÅÑÁá¹ÇµÑé§
--          N'PROJECT/CAG REPORT' , -- Path - nvarchar(1000)
--          LOWER(NEWID()) , -- MenuId - nvarchar(100)
--          NULL , -- InActive - bit
--          N'รายงาน Coporate Budget เปรียบเทียบตามแผนก' , -- Description - nvarchar(500)
--          100.0400 , -- SortOrder - decimal --¡´´Ù¤èÒ INDEX ã¹ Inspect *¶éÒÍÂÙèã¹àÁ¹Ùà´ÔÁ¤èÒ¨Ø´·È¹ÔÂÁ ÁÒ¡¡ÇèÒµÑÇà´ÔÁ | áµè¶éÒàÁ¹ÙãËÁè ãËé¤èÒÁÒ¡¡ÇèÒã¹ËÅÑ¡Ë¹èÇÂ
--          90104 , -- DoctypeId - int
--          90104 , -- DoctypeName - nvarchar(max)
--		  90104 , -- DoctypeId - int
--          N'/Report/CAG_Coporate_Budget_Item_Report/Form'  -- List - nvarchar(500)
--        )


 --Delete dbo.CompanyMenuConfigs where Id = 8

	--update dbo.CompanyMenuConfigs
 --   SET Description = 'รายงานสรุปเวลาการทำงานแต่ละโปรเจคของพนักงาน'
	--WHERE  id= 15
	 
	select*from CompanyMenuConfigs Order By Path,id --DoctypeId--SortOrder--Path --where Path = 'JOB/AAG BUDGET REPORT'


--Update CompanyMenuConfigs Set Path = 'PROJECT/THS REPORT' where id = 1

-- INSERT INTO ItemAccounts (GeneralAccount, GeneralAccountCode, GeneralAccountName, AccountCode, AccountName, AccountId, [Status],ItemMetaId)
-- SELECT 403 GeneralAccount
--         ,'SaleRev' GeneralAccountCode
--         ,'SaleRev' GeneralAccountName
--         ,411201 AccountCode
--         ,'รายได้จากการขาย' AccountName
--         ,186 AccountId
--         ,1 [Status]
--         ,i.id ItemMetaId
-- from ItemMetas i 
