-- SELECT * FROM CompanyPrintingConfigs WHERE ServiceName LIKE 'HCE%'
-- SELECT om.WorkerId, w.Name, om.RoleId, r.Code FROM OrganizationMembers om
-- INNER JOIN workers w ON w.Id = om.WorkerId
-- INNER JOIN Roles r ON om.RoleId = r.Id

SELECT * FROM SubDocTypes WHERE DocTypeId IN (38,438,151,44) 

/* AR */
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 320
-- WHERE Id IN (307, 323, 324, 325);
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 383
-- WHERE Id IN (378, 386,387);

/* TIV */
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 321
-- WHERE Id = 320;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 384
-- WHERE Id = 383;

/* Prepay , PV */
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 297
-- WHERE Id = 294;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 294
-- WHERE Id = 297;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 295
-- WHERE Id = 298;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 298
-- WHERE Id = 295;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 296
-- WHERE Id = 299;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 299
-- WHERE Id = 296;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 373
-- WHERE Id = 374;
-- UPDATE SubDocTypes
-- SET ParallelSubDocTypeId = 374
-- WHERE Id = 373;