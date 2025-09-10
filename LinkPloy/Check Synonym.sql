-- USE [Prototype-FcdManee]
SELECT
	DB_NAME() DBname
   ,*
FROM sys.synonyms 
ORDER BY base_object_name


