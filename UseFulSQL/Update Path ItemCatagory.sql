
Declare @id int = 8277
Declare @Path nVarchar(MAX) = (	Select ic.path  +'|'+ CONVERT(varchar(4000),i.Id)+'|' [CorrectPath]
								From ItemCategories i
								Left Join ItemCategories ic ON ic.Id = i.Parent
								Where i.SystemCategoryId = 33 AND i.Id = @id )

--Update ItemCategories Set Path = @Path Where SystemCategoryId = 33 AND Id = @id

Select i.Id,i.Code,i.Parent,i.Path,ic.Id [2id],ic.Code [2Code],ic.Path [2Path]
,ic.path +'|'+ CONVERT(varchar(4000),i.Id)+'|' [CorrectPath]
From ItemCategories i
Left Join ItemCategories ic ON ic.Id = i.Parent
Where --i.SystemCategoryId = 33 AND
	  i.Path != ic.path+'|'+ CONVERT(varchar(4000),i.Id)+'|'
Order By i.id

Select i.Id,i.Code,i.Parent,i.Path,ic.Id [2id],ic.Code [2Code],ic.Path [2Path]
,ic.path +'|'+ CONVERT(varchar(4000),i.Id)+'|' [CorrectPath]
From ItemCategories i
Left Join ItemCategories ic ON ic.Id = i.Parent
Where i.SystemCategoryId = 33 AND i.Id = @id