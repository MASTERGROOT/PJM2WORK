/*
- Search through tables to find specific text
- Written by Luis Chiriff (with help from SQL Server Central)
- luis.chiriff@gmail.com @ 24/11/2008 @ 11:54
*/
-- Variable Declaration

Declare @StringToFind VARCHAR(200), @Schema sysname, @Table sysname, @FullTable int, @NewMinID int, @NewMaxID int,
@SQLCommand VARCHAR(8000), @BaseSQLCommand varchar(8000), @Where VARCHAR(8000), @CountCheck varchar(8000) , @FieldTypes varchar(8000),
@cursor VARCHAR(8000), @columnName sysname, @SCn int, @SCm int
Declare @TableList table (Id int identity(1,1) not null, tablename varchar(250))
Declare @SQLCmds table (id int identity(1,1) not null, sqlcmd varchar(8000))
Declare @DataFoundInTables table (id int identity(1,1) not null, sqlcmd varchar(8000))


-- Settings

SET @StringToFind = 'M-01-03-0010'
SET NOCOUNT ON
SET @StringToFind = '%'+@StringToFind+'%'

-- Gathering Info

if ((select count(*) from sysobjects where name = 'tempcount') > 0)
drop table tempcount

create table tempcount (rowsfound int)
insert into tempcount select 0

-- This section here is to accomodate the user defined datatypes, if they have
-- a SQL Collation then they are assumed to have text in them.
SET @FieldTypes = ''
select @FieldTypes = @FieldTypes + '''' + rtrim(ltrim(name))+''',' from systypes where collation is not null or xtype = 36
select @FieldTypes = left(@FieldTypes,(len(@FieldTypes)-1))

insert into @TableList (tablename) 
select name from sysobjects 
where xtype = 'U' and name not like 'dtproperties' 
order by name

-- Start Processing Table List

select @NewMinID = min(id), @NewMaxID = max(id) from @TableList

while(@NewMinID <= @NewMaxID)
Begin

SELECT @Table = tablename, @Schema='dbo', @Where = '' from @TableList where id = @NewMinID

SET @SQLCommand = 'SELECT * FROM ' + @Table + ' WHERE' 
-- removed ' + @Schema + '.

SET @cursor = 'DECLARE col_cursor CURSOR FOR SELECT COLUMN_NAME
FROM [' + DB_NAME() + '].INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = ''' + @Schema + '''
AND TABLE_NAME = ''' + @Table + '''
AND DATA_TYPE IN ('+@FieldTypes+')'
--Original Check, however the above implements user defined data types --AND DATA_TYPE IN (''char'',''nchar'',''ntext'',''nvarchar'',''text'',''varchar'')'

EXEC (@cursor)

SET @FullTable = 0
DELETE FROM @SQLCmds

OPEN col_cursor   
FETCH NEXT FROM col_cursor INTO @columnName   

WHILE @@FETCH_STATUS = 0   
BEGIN   
   
SET @Where = @Where + ' [' + @columnName + '] LIKE ''' + @StringToFind + ''''
SET @Where = @Where + ' OR'

-- PRINT @Table + '|'+ cast(len(isnull(@Where,''))+len(isnull(@SQLCommand,'')) as varchar(10))+'|'+@Where

if (len(isnull(@Where,''))+len(isnull(@SQLCommand,'')) > 3600)
Begin
SELECT @Where = substring(@Where,1,len(@Where)-3)
insert into @SQLCmds (sqlcmd) select @Where
SET @Where = ''
End

FETCH NEXT FROM col_cursor INTO @columnName   
END   

CLOSE col_cursor   
DEALLOCATE col_cursor 

if (@Where <> '')
Begin
SELECT @Where = substring(@Where,1,len(@Where)-3)
insert into @SQLCmds (sqlcmd) 
select @Where --select @Table,count(*) from @SQLCmds
End

SET @BaseSQLCommand = @SQLCommand

select @SCn = min(id), @SCm = max(id) from @SQLCmds
while(@SCn <= @SCm)
Begin

select @Where = sqlcmd from @SQLCmds where ID = @SCn

if (@Where <> '')
Begin

SET @SQLCommand = @BaseSQLCommand + @Where
SELECT @CountCheck = 'update tempcount set rowsfound = (select count(*) '+ substring(@SQLCommand,10,len(@SQLCommand)) + ')'
EXEC (@CountCheck) 

if ((select rowsfound from tempcount) > 0)
Begin
PRINT '--- ['+cast(@NewMinID as varchar(15))+'/'+cast(@NewMaxID as varchar(15))+'] '+@Table + ' ----------------------------------[FOUND!]'
--PRINT '--- [FOUND USING:] ' +@SQLCommand
insert into @DataFoundInTables (sqlcmd) select @SQLCommand
EXEC (@SQLCommand) 
update tempcount set rowsfound = 0
End
else
Begin
PRINT '--- ['+cast(@NewMinID as varchar(15))+'/'+cast(@NewMaxID as varchar(15))+'] '+@Table
End
End

SET @SCn = @SCn + 1
End

set @NewMinID = @NewMinID + 1
end

if ((select count(*) from sysobjects where name = 'tempcount') > 0)
drop table tempcount

/*

This will now return all the sql commands you need to use

*/

select @NewMinID = min(id), @NewMaxID = max(id) from @DataFoundInTables

if (@NewMaxID > 0)
Begin
PRINT ' '
PRINT ' '
PRINT '-----------------------------------------'
PRINT '----------- TABLES WITH DATA ------------'
PRINT '-----------------------------------------'
PRINT ' '
PRINT 'We found ' + cast(@NewMaxID as varchar(10)) + ' table(s) with the string '+@StringToFind
PRINT ' '

while(@NewMinID <= @NewMaxID)
Begin

select @SQLCommand = sqlcmd from @DataFoundInTables where ID = @NewMinID

PRINT @SQLCommand
PRINT ''
SET @NewMinID = @NewMinID + 1
End

PRINT ' '
PRINT '-----------------------------------------'

End