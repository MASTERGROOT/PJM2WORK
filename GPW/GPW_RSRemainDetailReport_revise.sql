 /*==> GPW_RSRemainDetailReport_revise ==>*/ 
/* Edit By พี่เก๋ แก้เพิ่ม Special Discount เข้าไป */
/* 2023-05-18 : MS-28295 : แก้ปัญหาเวลาใช้ Filter ItemMeta หรือ ItemCate โดยเลือกหลายตัวแล้วรายงาน Preivew ไม่ได้ */

    DECLARE @p0 DATE = '2024-12-01';
    DECLARE @p1 DATE = '2024-12-31';
    DECLARE @p2 DATE = NULL;
    DECLARE @p3 INT = NULL;
    DECLARE @p4 BIT = NULL;
    DECLARE @p5 INT = NULL;
    DECLARE @p6 NVARCHAR(100) = NULL;--'RS-WH01-0030';
    DECLARE @p7 NVARCHAR(2000) = NULL;
    DECLARE @p8 NVARCHAR(2000) = NULL;
    DECLARE @p9 NVARCHAR(200)= NULL;
    DECLARE @p10 INT = 1
    DECLARE @p11 BIT = 0
    DECLARE @p12 NVARCHAR(100) = 'All Item'; /*1. Remain only 2. All Item */
    DECLARE @p13 BIT = 1;

DECLARE @FromDate DATE = @p0;
DECLARE @ToDate DATE = @p1;
DECLARE @AsOfDate DATE = @p2;
DECLARE @OrganizationId INT = @p3;
DECLARE @IncChild BIT = nullif(@p4,'');
DECLARE @SupplierId INT = @p5;
DECLARE @DocCode NVARCHAR(200)= nullif(@p6,'');
DECLARE @categoryId NVARCHAR(2000) = @p7
DECLARE @ItemmetaId NVARCHAR(2000) = @p8
DECLARE @CreateBy NVARCHAR(200) = nullif(@p9,'');
DECLARE @GroupBy INT = @p10
DECLARE @GroupByCurrency BIT = nullif(@p11,'');
DECLARE @Specific NVARCHAR(100)= @p12
DECLARE @Expand BIT = nullif(@p13,'');

DECLARE @query NVARCHAR(MAX) = ''
DECLARE @Cat TABLE (Id INT)
DECLARE @CatId NVARCHAR(MAX) = ''
DECLARE @Config NVARCHAR(MAX)	= (SELECT	Value FROM	dbo.CompanyConfigs WHERE ConfigName = 'HostUrl')
DECLARE @IncludeNonSupplier BIT = 0 /*ยังไม่ได้ set param สร้างเผื่อไว้เฉยๆ Ref : MS-13922*/

/************************************* TempRoleSubdoctype *******************************************/

DECLARE @DoctypeList NVARCHAR(MAX) = '130'; /*130 = ReceiveSupplier*/
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

/*******************************************************************************************************************************************************************/

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
						((@IncChild = 0 or @IncChild is null)  AND o.Id = @OrganizationId)
                     )


SELECT 
		final.*
	 ,IIF(@Expand = 0,final.SAmountOld,final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0)) [SAmount]
	 ,IIF(final.ROW# = 1,final.SpecialDiscount,0) [SpecialDiscountByDoc]
	 ,CASE WHEN (ItemVat.TaxAmount IS NULL AND RSVat.SystemCategoryId = 123) THEN final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0) + (ItemVat.Amount-ISNULL(itemvat.SpecialDiscount,0))*(RSvat.TaxRate/100)
            WHEN (ItemVat.TaxAmount IS NOT NULL AND RSVat.SystemCategoryId = 123) THEN final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0) + RSVat.TaxAmount
        ELSE final.SAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0)
        END [Total]
     ,CASE WHEN (ItemVat.TaxAmount IS NULL AND RSVat.SystemCategoryId = 129) THEN (ItemVat.Amount-ISNULL(itemvat.SpecialDiscount,0))*(RSVat.TaxRate/(100+RSVat.TaxRate))
            WHEN (ItemVat.TaxAmount IS NULL AND RSVat.SystemCategoryId = 123) THEN (ItemVat.Amount-ISNULL(itemvat.SpecialDiscount,0))*(RSvat.TaxRate/100)
            WHEN (ItemVat.TaxAmount IS NULL AND RSVat.SystemCategoryId = 131) THEN 0
            ELSE itemvat.TaxAmount
        END ItemVat
     ,IIF(final.ROW# = 1,RSVat.TaxAmount,0) [RSVat]
     ,RSVat.SystemCategory TypeVat
	 --,final.RemainAmountOld - IIF(final.ROW# = 1,final.SpecialDiscount,0) [RemainAmount]
 ,final.RemainAmountOld [RemainAmount]
FROM (
SELECT   ROW_NUMBER() OVER (PARTITION BY tmpremain.DocId ORDER BY tmpremain.DocId) [ROW#]
		,DocId
        ,DocLineId
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
		--,ClrQTY
		,IIF(tmpremain.DocStatus = -3 AND tmpremain.QTY - ClrQTY != 0
			, CONVERT(NVARCHAR(500), CONVERT(DECIMAL(28,2), ClrQTY)) + '(' + CONVERT(NVARCHAR(500),CONVERT(DECIMAL(28,2), tmpremain.QTY - ClrQTY)) + ')',CONVERT(NVARCHAR(500)
			,CONVERT(DECIMAL(28,2),tmpremain.ClrQTY))) ClrQTY
		,ClearMethod
		,ClearMethodName
		,GroupCode_0
        ,GroupCode_1
		,GroupName_1
		,RemainAmount [RemainAmountOld]
		,IIF( tmpremain.DocStatus = -3, 0,
			CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
			 WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
			 WHEN ClearMethod = 0 THEN ReaminQTY
			 ELSE NULL END) ReaminQTY
		,ISNULL(tmpremain.SpecialDiscount,0) SpecialDiscount
		,dbo.SitePath(DocTypeId,DocId) SitePath
from (
SELECT bs.DocId [DocId]
        ,bs.DocLineId [DocLineId]
		,bs.DocCode [DocCode]
		,bs.DocDate [DocDate]
		,bs.DocTypeId [DocTypeId]
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
		,ROUND(isnull(bs.Amount * doc.DocCurrencyRate,0),2) [SAmount]
		,isnull(bs.CountQty,bs.DocQty) [QTY]
		,isnull(bs.CountUnitName,bs.DocUnitName) [UnitName]
		,isnull(Clr.ClrAmount * doc.DocCurrencyRate,0) ClrAmount
		,isnull(Clr.ClrQTY,0) ClrQTY
		,bs.ClearMethod
		,bs.ClearMethodName
		 ,IIF(@GroupByCurrency = 1,bs.DocCurrency,'a')	GroupCode_0
         ,CASE WHEN @GroupBy = 1 THEN 'b'					
					WHEN @GroupBy = 2 THEN bs.LocationCode
					WHEN @GroupBy = 3 THEN bs.ExtOrgCode
					ELSE 'b'   END  GroupCode_1
		   ,CASE WHEN @GroupBy = 2 THEN bs.LocationName
               WHEN @GroupBy = 3 THEN bs.ExtOrgName
					ELSE NULL	END GroupName_1
		,(CASE WHEN ClearMethod = 0 AND (isnull(bs.CountQty,bs.DocQty) - ISNULL(Clr.ClrQTY,0)) <= 0 THEN 0
			ELSE ROUND(isnull(bs.Amount * doc.DocCurrencyRate,0),2) - round(ISNULL(Clr.ClrAmount * doc.DocCurrencyRate,0),2) END)RemainAmount
		,isnull(bs.CountQty,bs.DocQty) - ISNULL(Clr.ClrQTY,0) ReaminQTY
		,doc.DocStatus
		,dc.Amount * ISNULL(doc.DocCurrencyRate,1) SpecialDiscount
from BookedStockElementSets bs WITH (NOLOCK)
LEFT JOIN ReceiveSuppliers doc WITH (NOLOCK) on bs.DocId = doc.Id and bs.DocTypeId = 130
LEFT JOIN ReceiveSupplierLines dc on doc.id = dc.ReceiveSupplierId and dc.SystemCategoryId = 124
LEFT JOIN (
			select RefStockSetId
			--,sum(round(isnull(Amount,0),2)) ClrAmount -- อันเก่าปัดเศษก่อนค่อย SUM MEEN 09/07/65 ยอด Remain เป็น 0 แต่ Report Diff 0.01
			,ROUND(sum(isnull(Amount,0)),2) ClrAmount -- อันใหม่ sum ก่อนแล้วปัดเศษ MEEN 09/07/65
			,sum(isnull(CountQty,DocQty)) ClrQTY
			from BookedStockElementClears WITH (NOLOCK)
			where DocTypeId = 37 
			AND (NULLIF(@AsOfDate,'1900-01-01') IS NULL OR CONVERT(date,ClearDate) <= @AsOfDate)
			group by RefStockSetId
			) Clr on Bs.Id = Clr.RefStockSetId 
where bs.DocTypeId = 130 
	AND CONVERT(date,DocDate) between @FromDate and @ToDate
	AND ((bs.ItemMetaId IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaId))) OR ISNULL(@ItemmetaId,'') = '')
	AND ((bs.ItemCategoryId IN (SELECT ncode FROM dbo.fn_listCode(@CatId))) OR ISNULL(@categoryId,'') = '')
	AND ((bs.DocCode LIKE '%'+@DocCode+'%') OR @DocCode IS NULL)
	AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = bs.LocationId)) OR @OrganizationId IS NULL)
	AND ((doc.CreateBy LIKE '%'+@CreateBy+'%') OR ISNULL(@CreateBy,'') = '')
	AND ((bs.ExtOrgId = @SupplierId) OR @SupplierId IS NULL)
	AND (@IncludeNonSupplier = 1 OR (ISNULL(bs.ExtOrgId,0) != 0))
	AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR doc.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = doc.DestinationId))) OR @isPowerUser = 1)

	
)tmpremain
where (( @Specific='All Item') OR
	      ( @Specific='Remain only' AND (IIF( tmpremain.DocStatus = -3, 0,RemainAmount) <> 0  OR 
			(IIF( tmpremain.DocStatus = -3, 0,
			CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
			  WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
			  WHEN ClearMethod = 0 THEN ReaminQTY
			  ELSE NULL END)) <> 0)))
) final
CROSS APPLY (
    Select rsl.Id,rsl.Amount,rsl.TaxAmount,rsl.TaxRate,rsl.SpecialDiscount,rsl.DiscountAmount from ReceiveSupplierLines rsl WHERE rsl.Id = final.DocLineId AND rsl.SystemCategoryId IN (99,100) AND rsl.ReceiveSupplierId = final.DocId
) ItemVat
CROSS APPLY (
    Select rsl.ReceiveSupplierId,rsl.SystemCategory,rsl.SystemCategoryId,rsl.TaxBase,rsl.TaxAmount,rsl.TaxRate from ReceiveSupplierLines rsl WHERE rsl.ReceiveSupplierId = final.DocId AND rsl.SystemCategoryId IN (123,129,131)
) RSVat

/* Filter */

DECLARE @CountItemMeta INT = (SELECT COUNT(ncode) FROM dbo.fn_listCode(@ItemmetaId))
DECLARE @CountItemCate INT = (SELECT COUNT(ncode) FROM dbo.fn_listCode(@categoryId))

SELECT 
		  CONCAT('Document between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy')) Filterdate
		 ,IIF(NULLIF(@AsOfDate,'1900-01-01') IS NULL,NULL, 'As of date                ' + FORMAT(@AsOfDate,'dd/MM/yyyy')) AsOfDate
		 ,IIF(@OrganizationId IS NOT NULL,(SELECT Code  FROM	dbo.Organizations WHERE Id = @OrganizationId),NULL) OrgCode
		 ,CASE WHEN @IncChild =1 THEN 'YES'ELSE 'NO'END IncChild
		 ,@DocCode PRCode
		 ,IIF(@CountItemCate > 1,'Multiple',(SELECT Code FROM dbo.ItemCategories WHERE Id = @categoryId)) ItemCategory
		 ,IIF(@CountItemMeta > 1,'Multiple',(SELECT Code FROM dbo.ItemMetas WHERE Id = @ItemmetaId)) Itemmeta
		 ,@CreateBy CreateBy 
         ,CASE WHEN @GroupBy = 1 THEN 'NO GROUP'				
					                   WHEN @GroupBy = 2 THEN 'PROJECT'
					               --    WHEN @GroupBy = 3 THEN 'SUPPLIER'
					                   ELSE 'SUPPLIER' END
		  ReportName
		 ,IIF (@GroupByCurrency = 1 , 'YES' ,'NO') GroupByCurrency
		 ,@Specific Specific 
		 ,IIF (@Expand = 1 , 'YES' ,'NO') Expand


/************************ Temp HeadName Org *******************************************/

SELECT * FROM fn_CompanyInfoTable(@OrganizationId)