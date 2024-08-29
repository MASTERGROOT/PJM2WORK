--Delete Workers Where Id NOT IN (1,2)

-- DBCC CHECKIDENT ('Workers',RESEED,0);
-- DBCC CHECKIDENT ('WorkerSignatures',RESEED,0);
-- DBCC CHECKIDENT ('OrganizationMembers',RESEED,0);

Select * From Workers

Select * From WorkerSignatures

SELECT * FROM OrganizationMembers

-- DBCC CHECKIDENT ('Workers');
-- DBCC CHECKIDENT ('WorkerSignatures');
-- DBCC CHECKIDENT ('OrganizationMembers');