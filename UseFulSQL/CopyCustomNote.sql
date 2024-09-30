  --WHERE GroupName LIKE 'รายละเอียดของสัญญา'
-- Insert rows into table 'CustomNoteMetas' in schema '[dbo]'
-- INSERT INTO [dbo].[CustomNoteMetas]
-- ( -- Columns to insert data into
--  GroupName, KeyName,DataType,Label,UseDocType,UseDocTypeId,Placeholder,Components,DataValues, [Description],IsInternalFile
-- )
-- VALUES
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_scope_of_work','System.String','งานที่ทำ','', NULL,'ระบุงานที่ทำ','TextBox','[]','งานที่ทำ',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_quotation_note','System.String','เลขที่ใบเสนอราคา','', NULL,'ระบุเลขที่ใบเสนอราคา','TextBox','[]','เลขที่ใบเสนอราคา',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_signature_1','System.String','ผู้มีอำนาจลงนาม 1','Worker', 1,'','ComboboxSingle','[]','ผู้มีอำนาจลงนาม 1',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_signature_2','System.String','ผู้มีอำนาจลงนาม 2','Worker', 1,'','ComboboxSingle','[]','ผู้มีอำนาจลงนาม 2',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_guarantee','System.String','หลักค้ำประกัน','', NULL,'','SingleSelectAndKey','["โดยใช้เช็ควางค้ำประกันจนหักคืนครบ","โดยใช้ Bank Guarantee วางค้ำประกันจนหักคืนครบ","ไม่มีการวางค้ำประกัน",""]','หลักค้ำประกัน',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_contact_type','System.String','ประเภทสัญญา','', NULL,'','SingleSelectAndKey','["รับเหมาก่อสร้าง","ค่าของอย่างเดียว","ทั้งค่าแรงและค่าของ","ค่าเช่า","ค่าบริการ","ค่าโฆษณา",""]','ประเภทสัญญา',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_retention_mouth','System.Int32','ประกันผลงานเป็นเวลา___เดือน','', NULL,'ใส่จำนวนเดือนที่ประกันผลงาน','TextBoxNumeric','[]','ประกันผลงานเป็นเวลา___เดือน',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_retentsc_witnession_mouth','System.String','พยาน','Worker', 1,'','ComboboxSingle','[]','พยาน',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_condition','System.String','เงื่อนไขอื่นๆ ระบุ','', NULL,'เงื่อนไขอื่นๆ ระบุ','TextBox','[]','เงื่อนไขอื่นๆ ระบุ',0
-- ),
-- ( -- First row: values for the columns in the list above
--  'รายละเอียดของสัญญา','sc_wht_type','System.String','ประเภทการหัก ณ ที่จ่าย','', NULL,'','ComboboxSingle','["ค่าบริการ","ค่าขนส่ง","ค่าเช่า","ค่าจ้างเหมา"]','ประเภทการหัก ณ ที่จ่าย',0
-- )

-- -- Add more rows here
-- GO
/* 
Doctype
1 : Worker, 2 : Organization, 3 : ExtOrganization, 4 : ItemMeta, 5 : ItemCate, 6 : Journal, 7 : BankAcc
 */

-- IF OBJECT_ID('tempDB..#tempCustom', 'U') IS NOT NULL
-- DROP TABLE #tempCustom
-- GO
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo' in database 'DatabaseName'
-- SELECT GroupName, KeyName,DataType,Label,Components,DataValues, [Description],IsInternalFile
-- INTO #tempCustom
-- FROM [Pojjaman2Manee].[dbo].[CustomNoteMetas]
-- WHERE GroupName LIKE 'รายละเอียดของสัญญา'

-- select * from #tempCustom
-- INSERT INTO dbo.CustomNoteMetas (GroupName, KeyName,DataType,Label,Components,DataValues, [Description],IsInternalFile)
-- SELECT * FROM #tempCustom
-- WHERE /* Put condition */


-- Insert rows into table 'CustomNoteMetas' in schema '[dbo]'
-- INSERT INTO [dbo].[CustomNoteMetas]
-- ( -- Columns to insert data into
--  GroupName, KeyName,DataType,Label,Components,DataValues, [Description],IsInternalFile
-- )
-- VALUES
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบส่งสินค้าหรือสลิป','FileRS','System.Byte','','File','[]','แนบไฟล์ใบส่งสินค้าหรือสลิป',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์หรือรูปใบเสนอราคา','FilePO','System.Byte','','File','[]','แนบไฟล์หรือรูปใบเสนอราคา',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์สัญญาจ้าง','FileSC','System.Byte','','File','[]','แนบไฟล์สัญญาจ้าง',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์สัญญาเปลี่ยนเเปลงงานจ้าง','FileVO','System.Byte','','File','[]','แนบไฟล์สัญญาเปลี่ยนเเปลงงานจ้าง',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ตรวจงาน','FilePA','System.Byte','','File','[]','แนบไฟล์ตรวจงาน',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบขอยืม','FileDN','System.Byte','','File','[]','แนบไฟล์ใบขอยืม',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบแจ้งซ่อม','FilePSWE','System.Byte','','File','[]','แนบไฟล์ใบแจ้งซ่อม',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์เอกสารขอวงเงินสดย่อย','FilePC','System.Byte','','File','[]','แนบไฟล์เอกสารขอวงเงินสดย่อย',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์เอกสารตั้งวงเงินทดรองจ่าย','FileADM','System.Byte','','File','[]','แนบไฟล์เอกสารตั้งวงเงินทดรองจ่าย',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบเสร็จ/บิล','FileWE','System.Byte','','File','[]','แนบไฟล์ใบเสร็จ/บิล',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบลดหนี้','FileCN','System.Byte','','File','[]','แนบไฟล์ใบลดหนี้',0
-- ),
-- ( -- Second row: values for the columns in the list above
--  'แนบไฟล์ใบเพิ่มหนี้','FileDN','System.Byte','','File','[]','แนบไฟล์ใบเพิ่มหนี้',0
-- )
-- -- Add more rows here
-- GO




