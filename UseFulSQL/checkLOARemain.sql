/* for workflow condition */
-- SELECT STRING_AGG(CONCAT('d.SubDocTypeId == ',Id),'||') from subdoctypes where DocTypeId = 24 AND Name LIKE '%ใบขอเบิก%'

/* check LOA remain */
-- SELECT DocStatus,* from VariationOrders WHERE Id IN (55,89,74,91,82) 
Select d.DocId,d.DocCode,d.id DocLineOfApproveId,d.DocType,d.DocDate,d.OrgId,d.OrgCode,d.OrgName,d.LineOfApproveState
  ,l.SortOrder,l.EntityId,l.EntityName,l.Description
From dbo.DocLineOfApproves d
Left Join dbo.LineOfApprovals l ON l.Id = d.LineOfApproveId
Where d.DocCode IN ('WR-C001-2506-0002')
 
Select * From dbo.LineOfApproveDetailProgresses Where DocLineOfApproveId IN ('b7a49931-0d53-4732-8206-1d6049f4c8ca')
 
Select * From dbo.LineOfApproveDetailNextProgressRoles  Where DocLineOfApproveId IN ('b7a49931-0d53-4732-8206-1d6049f4c8ca')
 
Select * From ApproveDetailLogs Where DocLineOfApproveId IN ('b7a49931-0d53-4732-8206-1d6049f4c8ca')
 
 
/*
Delete dbo.LineOfApproveDetailNextProgressRoles  Where DocLineOfApproveId IN ('D15FDCDD-7C8F-410F-AA9E-F78F19B5ED2A')
 
Delete dbo.LineOfApproveDetailProgresses Where DocLineOfApproveId IN ('D15FDCDD-7C8F-410F-AA9E-F78F19B5ED2A')
 
Delete ApproveDetailLogs Where DocLineOfApproveId IN ('D15FDCDD-7C8F-410F-AA9E-F78F19B5ED2A')
 
Delete dbo.DocLineOfApproves  Where DocCode IN ('RNM-OPDP-0003-2505-001')
*/

/* transaction */

-- -- Drop the table if it already exists
-- IF OBJECT_ID('tempDB..#test', 'U') IS NOT NULL
-- DROP TABLE #test
-- -- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
-- SELECT Code
-- INTO #test
-- FROM [dbo].POes
-- WHERE Id IN (1,2,3)

-- select * from #test
-- -- Start Transaction
-- BEGIN TRANSACTION;
-- -- Savepoint for first operation
-- SAVE Transaction step1;
-- DELETE #test where Code ='PO-HO-2505-001'
-- SELECT * from #test
-- -- Commit Transaction
-- ROLLBACK TRANSACTION step1
-- SELECT * from #test



-- -- Drop the table if it already exists
-- IF OBJECT_ID('tempDB..#test', 'U') IS NOT NULL
-- DROP TABLE #test