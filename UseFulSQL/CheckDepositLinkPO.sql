SELECT pl.guid,pl.id,f.DetailJSON,f.status,f.code,f.guid,* 
FROM polines pl
inner join FiscalItems f on f.DetailJSON like '%' +pl.guid+'%'
where f.RefDocId = 0 --เอาไว้หา dp ที่ผูก po เเล้วไม่ ref 

-- อันนี้ล่างคือที่ update ให้
begin tran
update FiscalItems set
RefDocId = 237,
RefDocCode = 'GPW-POX2501-00009',
RefDocType = 'PO',
RefDocTypeId = 22,
RefDocLineId = 2344,
RefDocDate = '2025-01-16 00:00:00.000'
where id = 162
begin tran
INSERT INTO ReferenceDocStatus (
    Id,
    DocId,
    DocCode,
    DocType,
    DocTypeId,
    RefDocId,
    RefDocCode,
    RefDocType,
    RefDocTypeId,
    RefDocOldStatus,
    RefDocGuid,
    RefDocDate,
    DocGuid,
    DocDate
) 
VALUES (
    'F94E820C-B616-4F39-BD9B-5FCB4DD36EF2', -- Id
    162,                                   -- DocId
    'GPW-DPX2501-00001',                   -- DocCode
    'DepositPay',                          -- DocType
    54,                                    -- DocTypeId
    237,                                   -- RefDocId
    'GPW-POX2501-00009',                   -- RefDocCode
    'PO',                                  -- RefDocType
    22,                                    -- RefDocTypeId
    5,                                     -- RefDocOldStatus
    'b93a7bfb-971e-4524-8e44-cb8124fa1c9c', -- RefDocGuid
    '2025-01-16 00:00:00.000',             -- RefDocDate
    '580ea04b-6a28-447d-8ba8-03b8c7156825', -- DocGuid
    '2025-01-20 00:00:00.000'              -- DocDate
);
commit tran