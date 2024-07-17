--UPDATE ITC
--SET  ITC.RunNumber = RN.RunNumber
--  ,ITC.AutoRunPattern = (SELECT Code FROM ItemCategories WHERE Id = ITC.Parent) + '.##'--CONVERT(NVARCHAR, ITC.Parent) + '.###'
--  ,SubDocTypeId = 3,SubDocTypeName = 'เพิ่มหมวดวัสดุ [Running]'
--FROM ItemCategories ITC
--RIGHT JOIN 
--(
--  SELECT  ROW_NUMBER() OVER(PARTITION BY Parent ORDER BY Id ASC) AS RunNumber, Id
--  FROM  ItemCategories  
--  WHERE  SystemCategoryId = 99 AND Level > 1
--)RN
--ON ITC.Id = RN.Id



--UPDATE ITM
--SET  ITM.RunNumber = RN.RunNumber
--  ,ITM.AutoRunPattern = (SELECT Code FROM ItemCategories WHERE Id = ITM.ItemCategoryId) + '.###'--CONVERT(NVARCHAR, ITC.Parent) + '.###'
--  ,SubDocTypeId = 7,SubDocTypeName = 'เพิ่มรหัสวัสดุ [Runing]'
--FROM ItemMetas ITM
--RIGHT JOIN 
--(
--  SELECT  ROW_NUMBER() OVER(PARTITION BY ItemCategoryId ORDER BY Id ASC) AS RunNumber, Id,ItemCategoryId
--  FROM  ItemMetas ITM
--  WHERE  SystemCategoryId = 99
--)RN
--ON ITM.Id = RN.Id