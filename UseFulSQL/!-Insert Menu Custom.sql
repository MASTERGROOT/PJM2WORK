
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
-- VALUES  ( N'HCE AR RECEIPT REMAIN REPORT' , -- Name - nvarchar(250)
--          4 , -- Column - smallint --¹Ñº¨Ò¡´éÒ¹ã¹àÁ¹Ù à»ç¹¤ÍÅÑÁá¹ÇµÑé§
--          N'AR/HCE REPORT' , -- Path - nvarchar(1000)
--          LOWER(NEWID()) , -- MenuId - nvarchar(100)
--          NULL , -- InActive - bit
--          N'รายงานยอดใบเสร็จรับเงินที่ยังไม่ได้รับชำระเงิน' , -- Description - nvarchar(500)
--          400.0001 , -- SortOrder - decimal --¡´´Ù¤èÒ INDEX ã¹ Inspect *¶éÒÍÂÙèã¹àÁ¹Ùà´ÔÁ¤èÒ¨Ø´·È¹ÔÂÁ ÁÒ¡¡ÇèÒµÑÇà´ÔÁ | áµè¶éÒàÁ¹ÙãËÁè ãËé¤èÒÁÒ¡¡ÇèÒã¹ËÅÑ¡Ë¹èÇÂ
--          90401 , -- DoctypeId - int
--          90401 , -- DoctypeName - nvarchar(max)
-- 		  90401 , -- DoctypeId - int
--          N'/Report/HCE_AR_Receipt_Remain_Report/Form'  -- List - nvarchar(500)
--        )


 --Delete dbo.CompanyMenuConfigs where Id = 8

	--update dbo.CompanyMenuConfigs
 --   SET Description = 'รายงานสรุปเวลาการทำงานแต่ละโปรเจคของพนักงาน'
	--WHERE  id= 15
	 
	-- select*from CompanyMenuConfigs Order By Path,id --DoctypeId--SortOrder--Path --where Path = 'JOB/AAG BUDGET REPORT'


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
