/*==> Ref:d:\programmanee\pjm-printing\content\printing\reportcommands\pur_requestremaindetailreport_revise.sql ==>*/
 
/* PUR_RequestRemainDetailReport_revise */
/* Edit 14-07-2020 Edit By แบงค์เอง เพิ่มเรื่อง Special Discount เข้ามา */
/*2023-02-23 : Pichet : Fix Performance*/

DECLARE @p0 DATE = '2021-11-01'; --@FromDate
DECLARE @p1 DATE = '2024-11-11'; --@ToDate
DECLARE @p2 INT = NULL;
DECLARE @p3 INT = NULL;
DECLARE @p4 BIT = 0;
DECLARE @p5 NVARCHAR(200) = NULL;
DECLARE @p6 NVARCHAR(200) = NULL;
DECLARE @p7 INT = '';
DECLARE @p8 INT = '';
DECLARE @p9 NVARCHAR(200)= '';
DECLARE @p10 INT = 1
DECLARE @p11 BIT = 0
DECLARE @p12 NVARCHAR(100) = 'Remain only';
DECLARE @p13 BIT = 1;
DECLARE @p14 BIT = 1;

DECLARE @FromDate DATE = @p0;
DECLARE @ToDate DATE = @p1;
DECLARE @SupplierId INT = @p2
DECLARE @OrganizationId INT = @p3
DECLARE @IncChild BIT = nullif(@p4,'');
DECLARE @DocCode NVARCHAR(200)= nullif(@p5,'');
DECLARE @Docstatus NVARCHAR(200)= nullif(@p6,'');
DECLARE @categoryId INT = @p7
DECLARE @ItemmetaId INT = @p8
DECLARE @CreateBy NVARCHAR(200) = nullif(@p9,'');
DECLARE @GroupBy INT = @p10
DECLARE @GroupByCurrency BIT = nullif(@p11,'');
DECLARE @Specific NVARCHAR(100)= @p12
DECLARE @Expand BIT = @p13;
DECLARE @OrderBy BIT = @p14

DECLARE @query NVARCHAR(MAX) = ''
DECLARE @Cat TABLE (Id INT)
DECLARE @CatId NVARCHAR(MAX) = ''
DECLARE @Config NVARCHAR(MAX)	= (SELECT	Value FROM	dbo.CompanyConfigs WHERE ConfigName = 'HostUrl')

/************************************* TempRoleSubdoctype *******************************************/

DECLARE @DoctypeList NVARCHAR(MAX) = '24,126'; /*24 = request, 126 = Milestone*/
DECLARE @WorkerId INT  = dbo.fn_currentUser(); 
IF OBJECT_ID(N'tempdb..#TempRoleSubdoctype') IS NOT NULL
BEGIN
    DROP TABLE #TempRoleSubdoctype;
END;

DECLARE @isPowerUser BIT = 0

IF @WorkerId IS NULL
BEGIN
	SET @isPowerUser = 1
END

IF @isPowerUser = 0
BEGIN
	SELECT @isPowerUser = IIF(@WorkerId = w.Id,1,0) FROM dbo.CompanyConfigs cf
	INNER JOIN dbo.Workers w ON cf.Value = w.UserName
	WHERE ConfigName = 'GODWorker'
END

SELECT *
INTO #TempRoleSubdoctype
FROM dbo.fn_GetRoleSubDocTypeReport(@WorkerId, @DoctypeList);

/****************************************************************************************************/

	 SELECT  @query += a.Query

	 FROM ( 
					SELECT 'SELECT Id  FROM dbo.ItemCategories WHERE Path LIKE '''+i.Path+'%'';' Query 
					FROM	 dbo.fn_listCode(@categoryId) n
								 LEFT JOIN dbo.ItemCategories i WITH (NOLOCK) ON i.Id = n.ncode
					WHERE	 @categoryId IS NOT NULL
                     ) a /*For Execute More AccountCode*/
INSERT INTO @Cat(Id)
EXECUTE(@query) /*Save AccountId to Temp.*/


			SELECT	@CatId += CONVERT(NVARCHAR(10),ic.Id)+',' 
			FROM		dbo.ItemCategories ic WITH (NOLOCK)
			WHERE		EXISTS (SELECT	Id FROM	@Cat ac WHERE ac.Id = ic.Id)

DECLARE @Org TABLE (Id INT)		
INSERT INTO @Org(Id)
            
            SELECT   o.Id 
            FROM     dbo.Organizations o 
            WHERE    (  (@IncChild = 1 AND o.Path LIKE '%|' + CONVERT(NVARCHAR(10),@OrganizationId) + '|%') 
                        OR 
						((@IncChild = 0 or @IncChild is null) AND o.Id = @OrganizationId)
                     )

declare @sp_24 nvarchar(max)
select @sp_24 = sp.SitePath from SitePathList() sp where sp.DocTypeId = 24

SELECT 
	 *
	 ,IIF(@Expand = 0,final.SAmountOld,final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0)) [SAmount]
	 ,IIF(final.ROW# = 1,final.SpecialDiscount,0) [SpecialDiscountByDoc]
	 ,final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0) [Total]
	 ,final.RemainAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0) [RemainAmount]
	 ,dbo.fn_GetNameDocStatus(final.DocStatus)DocStatus
FROM (
select 
		ROW_NUMBER() OVER (PARTITION BY b.DocId ORDER BY b.DocId) [ROW#]
		,DocId
		,DocCode
		,DocDate
		,ExtOrgId
		,ExtOrgCode
		,ExtOrgName
		,LocationId
		,LocationCode
		,LocationName
		,ItemCode
		,ItemName
		,SAmount [SAmountOld]
		,QTY
		,UnitName
		,ClrAmount
		,IIF(b.DocStatus = -3 AND b.QTY - ClrQTY != 0
				, CONVERT(NVARCHAR(500), CONVERT(DECIMAL(28,2), ClrQTY)) + '(' + CONVERT(NVARCHAR(500),CONVERT(DECIMAL(28,2), b.QTY - ClrQTY)) + ')',CONVERT(NVARCHAR(500)
				,CONVERT(DECIMAL(28,2),b.ClrQTY))) ClrQTY
		,ClearMethod
		,ClearMethodName
		,GroupCode_0
        ,GroupCode_1
		,GroupName_1
		,IIF( b.DocStatus = -3, 0,RemainAmount) RemainAmountOld
		,IIF( b.DocStatus = -3, 0,
			CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
			  WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
			  WHEN ClearMethod = 0 THEN ReaminQTY
			  ELSE NULL END) ReaminQTY
		,CONCAT(@sp_24,DocId)		SitePath
		,b.SpecialDiscount
		,b.DocStatus

from (
		select 
				bs.DocId [DocId]
				,bs.DocCode [DocCode]
				,bs.DocDate [DocDate]
				,bs.ExtOrgId [ExtOrgId]
				,bs.ExtOrgCode [ExtOrgCode]
				,bs.ExtOrgName [ExtOrgName]
				,bs.LocationId [LocationId]
				,bs.LocationCode [LocationCode]
				,bs.LocationName [LocationName]
				,IIF(ISNULL(NULLIF(bs.ItemMetaCode,'####'),'') = '',bs.ItemCategoryCode,bs.ItemMetaCode) [ItemCode]
				,ISNULL(NULLIF(bs.Description,''),IIF(ISNULL(NULLIF(bs.ItemMetaCode,'####'),'') = '',bs.ItemCategoryName,bs.ItemMetaName)) [ItemName]
				,IIF(bs.DocCurrency = 'THB',NULL,bs.DocCurrency) DocCurrency
				,IIF(bs.DocCurrency = 'THB',NULL,bs.DocCurrencyRate) DocCurrencyRate
		        ,IIF(bs.DocCurrency = 'THB',NULL,isnull(bs.Amount,0)) CurrAmount
				,isnull(bs.Amount * doc.DocCurrencyRate,0) [SAmount]
				,isnull(bs.CountQty,bs.DocQty) [QTY]
				,isnull(bs.CountUnitName,bs.DocUnitName) [UnitName]
				,isnull(Clr.ClrAmount,0) ClrAmount
				,isnull(Clr.ClrQTY,0) ClrQTY
				,bs.ClearMethod
				,bs.ClearMethodName
				 ,IIF(@GroupByCurrency = 1,bs.DocCurrency,'a')	GroupCode_0
		         ,CASE WHEN @GroupBy = 1 THEN 'b'					
							WHEN @GroupBy = 2 THEN bs.ExtOrgCode

							ELSE 'b'   END  GroupCode_1
				   ,CASE WHEN @GroupBy = 2 THEN bs.ExtOrgName

							ELSE NULL	END GroupName_1
				,isnull(bs.Amount * doc.DocCurrencyRate ,0) - ISNULL(Clr.ClrAmount * doc.DocCurrencyRate,0) RemainAmount
				,isnull(bs.CountQty,bs.DocQty) - ISNULL(Clr.ClrQTY,0) ReaminQTY
				,doc.DocStatus
				,ISNULL(dc.Amount * doc.DocCurrencyRate ,0) SpecialDiscount

		from BookedStockElementSets bs WITH (NOLOCK)
		LEFT JOIN dbo.RequestLines line WITH (NOLOCK) ON bs.DocId = line.RequestId AND bs.DocLineId = line.Id AND bs.DocTypeId = 24
		LEFT JOIN dbo.RequestLines dc WITH (NOLOCK) ON dc.SystemCategoryId = 124 AND bs.DocId = dc.RequestId
		left join Requests doc WITH (NOLOCK) on line.RequestId = doc.Id
		left join (
					select RefStockSetId,sum(isnull(Amount,0)) ClrAmount
					,SUM(CASE d.Isreverse
						    WHEN 0 THEN
						        (ISNULL(CONVERT(DECIMAL(29, 12), d.ConversionFactor), 1) / ISNULL(CONVERT(DECIMAL(29, 12), c.ConversionFactor), 1)) * ISNULL(bc.DocQty, 1)
						    ELSE
						        (ISNULL(CONVERT(DECIMAL(29, 12), c.ConversionFactor), 1) / ISNULL(CONVERT(DECIMAL(29, 12), d.ConversionFactor), 1)) * ISNULL(bc.DocQty, 1)
						 END) ClrQTY
					from BookedStockElementClears bc
					left join ItemMetas i on bc.ItemMetaId = i.Id
					left join UnitConversionView d on bc.ItemMetaId = d.ItemMetaId and bc.DocUnitId = d.UnitId and ((bc.DocUnitName = d.NameOfUnit and d.Quantity >= 100) or (d.Quantity < 100)) and d.ItemMetaId != 0
					left join UnitConversionView c on i.Id = c.ItemMetaId and i.CountUnitId = c.UnitId and ((i.CountUnitName = c.NameOfUnit and c.Quantity >= 100) or (c.Quantity < 100)) and c.ItemMetaId != 0
					where DocTypeId IN (1,22)
					group by RefStockSetId
		) Clr on Bs.Id = Clr.RefStockSetId 
		where bs.DocTypeId = 24 
			 AND bs.BookedStockState IN (10,11)
			AND CONVERT(date,DocDate) between @FromDate and @ToDate
			AND ((bs.ItemMetaId IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaId))) OR ISNULL(@ItemmetaId,'') = '')
			AND ((bs.ItemCategoryId IN (SELECT ncode FROM dbo.fn_listCode(@CatId))) OR ISNULL(@categoryId,'') = '')
			AND ((bs.DocCode LIKE '%'+@DocCode+'%') OR @DocCode IS NULL)
			AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = bs.LocationId)) OR @OrganizationId IS NULL)
			AND ((doc.CreateBy LIKE '%'+@CreateBy+'%') OR ISNULL(@CreateBy,'') = '')
			AND ((bs.ExtOrgId = @SupplierId) OR @SupplierId IS NULL)
			AND ((doc.docstatus IN (SELECT ncode FROM dbo.fn_listCode(@Docstatus))) OR ISNULL(@Docstatus,'') = '')
			AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR doc.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = doc.LocationId))) OR @isPowerUser = 1)


)b
where (( @Specific='All Item') OR
	      ( @Specific='Remain only' AND (IIF( b.DocStatus = -3, 0,RemainAmount) <> 0  OR 
			(IIF( b.DocStatus = -3, 0,
										CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
										     WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
										     WHEN ClearMethod = 0 THEN ReaminQTY
										     ELSE NULL END)) <> 0)))
) final
ORDER BY (CASE WHEN @OrderBy = 1 THEN DocDate
                ELSE NULL END)
option(recompile)

/* 2-Filter */
SELECT IIF(@OrganizationId IS NOT NULL,(SELECT	Code FROM	dbo.Organizations WHERE Id = @OrganizationId),NULL) OrgCode
		
         ,CASE WHEN @GroupBy = 1 THEN 'DOCUMENT'				
					                   WHEN @GroupBy = 2 THEN 'SUPPLIER'

					                   ELSE 'DOCUMENT' END
		  ReportName
		 ,IIF (@IncChild = 1 , 'YES' ,'NO') IncChild
		 ,IIF (@categoryId IS NULL , NULL , (SELECT Code FROM dbo.ItemCategories WHERE Id = @categoryId)) ItemCategory
		 ,IIF (@ItemmetaId IS NULL , NULL , (SELECT Code FROM dbo.ItemMetas WHERE Id = @ItemmetaId)) ItemmetaId
		 ,IIF (@GroupByCurrency = 1 , 'YES' ,'NO') GroupByCurrency
		 ,@Specific Specific
		 ,IIF (@Expand = 1 , 'YES' ,'NO') Expand
		 ,CONCAT('Document between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy')) filterdate



/*3-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM fn_CompanyInfoTable(@OrganizationId)