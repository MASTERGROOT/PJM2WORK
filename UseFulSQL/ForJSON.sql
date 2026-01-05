SELECT STRING_AGG(Id,',') test
from ItemCategories cat
where  SystemCategoryId = 99 AND cat.LastModifiedBy LIKE 'Vivitthachai Laprattanatrai' AND cat.Code LIKe 'M%' AND Parent = 0
UPDATE SubDocTypes
set InputCondition = JSON_MODIFY(InputCondition,'append $.ItemCategoryList','|3907|')
WHERE Id = 84
SELECT JSON_QUERY(InputCondition,'$.ItemCategoryList'),JSON_VALUE(InputCondition,'$.ItemCategoryList[0]'),* from SubDocTypes WHERE Id = 84
-- UNION ALL
-- SELECT Name, Code, ItemCategoryCode ParentCode, ItemCategoryName ParentName,[Description],CBSCode,CBSName, StockMethod,StockMethodName,CountUnitName,'Mat' Type
-- FROM ItemMetas
-- WHERE SystemCategoryId = 99 AND LastModifiedBy LIKE 'Vivitthachai Laprattanatrai'