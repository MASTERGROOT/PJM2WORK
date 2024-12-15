
-- UPDATE Organizations
-- SET Code = REPLACE(Code,'400-','KDX-'),Name = REPLACE(Name,'400-','KDX-')
-- WHERE Code LIKE '400-%'
-- UPDATE Payees
-- SET Code = REPLACE(Code,'400-','KDX-'), Name = REPLACE(Name,'400-','KDX-')
-- WHERE Code LIKE '400-%'
-- SELECT * from Organizations where code LIKE '400-%' OR code like 'KDX%'
-- SELECT * from Payees where code LIKE '400-%'OR code like 'KDX%'

-- DECLARE @SQL VARCHAR(MAX) 
-- DECLARE @valueToFind VARCHAR(100) 
-- DECLARE @columnName VARCHAR(100) 

-- SET @valueToFind = 'GPW' 
-- SET @columnName = '%Name%' 

-- CREATE TABLE #TMP 
--    (Clmn VARCHAR(500), 
--    CNT INT) 

-- SELECT @SQL=COALESCE(@SQL,'')+CAST('INSERT INTO #TMP Select ''' + TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME + ''' AS Clmn, count(*) CNT FROM '  
--         + TABLE_SCHEMA + '.[' + TABLE_NAME + 
--        '] WHERE [' + COLUMN_NAME + '] LIKE ''%' + @valueToFind + '%'' ;'  AS VARCHAR(MAX)) 
-- FROM INFORMATION_SCHEMA.COLUMNS  
--    JOIN sysobjects B  
--    ON INFORMATION_SCHEMA.COLUMNS.TABLE_NAME = B.NAME 
-- WHERE COLUMN_NAME LIKE @columnName AND xtype = 'U' 
--    AND DATA_TYPE IN ('char','nchar','ntext','nvarchar','text','varchar') 

-- PRINT @SQL 
-- EXEC(@SQL) 

-- SELECT * FROM #TMP WHERE CNT > 0 
-- DROP TABLE #TMP 

DECLARE @SQL VARCHAR(MAX) 
DECLARE @valueToFind VARCHAR(100) 
DECLARE @columnName VARCHAR(100) 

SET @valueToFind = 'G100' 
SET @columnName = '%Code%' 

IF OBJECT_ID('tempDB..#TMP', 'U') IS NOT NULL
DROP TABLE #TMP

-- Create a temporary table to store the results
CREATE TABLE #TMP 
   (Clmn VARCHAR(500), 
   FoundValue VARCHAR(500))

-- Build the dynamic SQL to search for the specific value in the specified columns
SELECT @SQL = COALESCE(@SQL, '') + 
    'INSERT INTO #TMP SELECT ''' + TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME + 
    ''' AS Clmn, [' + COLUMN_NAME + 
    '] AS FoundValue FROM ' + TABLE_SCHEMA + '.[' + TABLE_NAME + 
    '] WHERE [' + COLUMN_NAME + '] LIKE ''%' + @valueToFind + '%''; '  
FROM INFORMATION_SCHEMA.COLUMNS  
JOIN sysobjects B  
   ON INFORMATION_SCHEMA.COLUMNS.TABLE_NAME = B.NAME 
WHERE COLUMN_NAME LIKE @columnName 
   AND xtype = 'U' 
   AND DATA_TYPE IN ('char', 'nchar', 'ntext', 'nvarchar', 'text', 'varchar') 

-- Print the generated SQL for debugging purposes
PRINT @SQL 

-- Execute the dynamic SQL
EXEC(@SQL) 

-- Retrieve results from the temporary table where matches were found
SELECT * FROM #TMP 

-- Drop the temporary table after use
DROP TABLE #TMP
