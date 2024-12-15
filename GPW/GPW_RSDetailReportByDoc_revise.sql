/*  PUR_RSDetailReport  */
/*Edit By Bank 17-07-2020 เพิ่ม Special Discount ของเอกสารเข้ามา */
/*Edited : 2021-02-02 : Pichet : Fix Performance*/
/*Edit : 2021-05-06 : Pichet : Fix Performance*/

-- DECLARE @p0 DATE = '2024-11-06'; 
-- DECLARE @p1 DATE = '2024-11-06';
-- DECLARE @p2 INT = NULL;
-- DECLARE @p3 BIT = NULL;
-- DECLARE @p4 NVARCHAR(200) = NULL;
-- DECLARE @p5 NVARCHAR(200) = NULL--'RSM1910-0016'--'DE-RS6206-0001';
-- DECLARE @p6 NVARCHAR(200) = NULL;
-- DECLARE @p7 NVARCHAR(200) = NULL;
-- DECLARE @p8 NVARCHAR(200) = NULL;
-- DECLARE @p9 NVARCHAR(200) = NULL;
-- DECLARE @p10 NVARCHAR(200) = NULL;
-- DECLARE @p11 INT = NULL;
-- DECLARE @p12 INT = NULL;
-- DECLARE @p13 NVARCHAR(200) = NULL;
-- DECLARE @p14 BIT = 0;
-- DECLARE @p15 BIT = 0;
-- DECLARE @p16 BIT = 0;
-- DECLARE @p17 NVARCHAR(1000) = 0;

/************************************************************************************************************************************************************************/

DECLARE @FromDate DATE = @p0;
DECLARE @ToDate DATE = @p1;
DECLARE @OrganizationId INT = @p2;
DECLARE @IncChild BIT = nullif(@p3,'');
DECLARE @SupplierCode NVARCHAR(200) = @p4
DECLARE @Code NVARCHAR(200)= nullif(@p5,'');
DECLARE @RefCode NVARCHAR(200)= nullif(@p6,'');
DECLARE @categoryCode NVARCHAR(300) = @p7
DECLARE @ItemmetaCode NVARCHAR(300) = @p8
DECLARE @Status NVARCHAR(200)= @p9
DECLARE @CreateBy NVARCHAR(200)= nullif(@p10,'');
DECLARE @GroupByForm1 INT = @p11
DECLARE @GroupByForm2 INT = @p12
DECLARE @Currency NVARCHAR(200) = @p13
DECLARE @GroupByCurrency BIT = nullif(@p14,'');
DECLARE @NotTHB BIT = nullif(@p15,'');
DECLARE @Canceled BIT = nullif(@p16,'');
DECLARE @SortBy NVARCHAR(1000) = @p17

DECLARE @query NVARCHAR(MAX) = ''
DECLARE @Cat TABLE (Id INT)
DECLARE @Org TABLE (Id INT)

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

/************************************************************************************************************************************************************************/

	 SELECT  @query += a.Query

	 FROM ( 
					SELECT   'SELECT Id  FROM dbo.ItemCategories WITH (NOLOCK) WHERE Path LIKE '''+i.Path+'%'';' Query 
					FROM	   dbo.fn_listCode(@categoryCode) n
							   LEFT JOIN dbo.ItemCategories i WITH (NOLOCK) ON i.Code = n.ncode
					WHERE	   @categoryCode IS NOT NULL
                        ) a /*For Execute More AccountCode*/

INSERT INTO @Cat(Id)

   EXECUTE(@query) /*Save AccountId to Temp.*/

INSERT INTO @Org(Id)
            
            SELECT   o.Id 
            FROM     dbo.Organizations o WITH (NOLOCK)
            WHERE    (  (@IncChild = 1 AND o.Path LIKE '%|' + CONVERT(NVARCHAR(10),@OrganizationId) + '|%') 
                        OR ((@IncChild = 0 or @IncChild is null)  AND o.Id = @OrganizationId)
                           )
			option(recompile)

declare @sitepath_130 nvarchar(max) 
set @sitepath_130 = (select sitepath from SitePathList() where doctypeid = 130)

declare @sitepath_22 nvarchar(max) 
set @sitepath_22 = (select sitepath from SitePathList() where doctypeid = 22)


IF OBJECT_ID('tempdb..#cte_RS') IS NOT NULL
    BEGIN
        DROP TABLE #cte_RS;
END;

create table #cte_RS 
(

	  ROW#					int
	, DocId					int
	, DocCode				nvarchar(200)
	, DocDate				date
	, Remarks				nvarchar(4000)
	, DocStatus				nvarchar(400)

    , OrgId					int
	, OrgCode				nvarchar(200)
	, OrgName				nvarchar(2000)

    , ExtOrgId				int
	, ExtOrgCode			nvarchar(200)
	, ExtOrgName			nvarchar(2000)

    , PaymentDueDate		date
    , DocCurrency			nvarchar(200)
	, DocCurrencyRate		decimal(28,12)
    , CurrAmount			decimal(28,6)
    , LineId				int

    , GroupCode_0			nvarchar(200)
    , GroupCode_1			nvarchar(200)
	, GroupName_1			nvarchar(4000)
    , GroupCode_2			nvarchar(200)
	, GroupName_2			nvarchar(4000)
    , GroupCode_3			nvarchar(200)
    , FormTag				nvarchar(200)    
    , ItemCode				nvarchar(2000)
	, ItemName				nvarchar(2000)
    , DocQty				decimal(28,6)
	, DocUnitName			nvarchar(2000)
    , [UnitPrice]			decimal(28,12)
    , DiscountAmt			decimal(28,6)
	, LineAmt				decimal(28,6)
    , RefDocId				int
    , RefDocCode			nvarchar(200)
    , RefDocLineId			int
	, TypeVatId				int
    , TypeVat        		nvarchar(200)
    , ItemVat               decimal(28,6)
    , RSVat                 decimal(28,6)
	, SpecialDiscount		decimal(28,6)

)
CREATE CLUSTERED INDEX IDX_C_cte_RS  ON #cte_RS (DocId,LineId)

insert into #cte_RS 
(

	  ROW#					
	, DocId					
	, DocCode				
	, DocDate				
	, Remarks				
	, DocStatus				

    , OrgId					
	, OrgCode				
	, OrgName				

    , ExtOrgId				
	, ExtOrgCode			
	, ExtOrgName			

    , PaymentDueDate		
    , DocCurrency			
	, DocCurrencyRate		
    , CurrAmount			
    , LineId				

    , GroupCode_0			
    , GroupCode_1			
	, GroupName_1			
    , GroupCode_2			
	, GroupName_2			
    , GroupCode_3			
    , FormTag				    
    , ItemCode				
	, ItemName				
    , DocQty				
	, DocUnitName			
    , [UnitPrice]			
    , DiscountAmt			
	, LineAmt				
    , RefDocId				
    , RefDocCode			
    , RefDocLineId			
	, TypeVatId
    , TypeVat
    , ItemVat
    , RSVat		
	, SpecialDiscount		

)
SELECT	ROW_NUMBER() OVER (PARTITION BY r.Id ORDER BY r.Id) ROW#
		,r.Id DocId,r.Code DocCode,CONVERT(DATE,r.Date)DocDate,r.Remarks,cd.Description DocStatus
         ,r.DestinationId OrgId,r.DestinationCode OrgCode,r.DestinationName OrgName
         ,r.ExtOrgId, r.ExtOrgCode, r.ExtOrgName
         ,CONVERT(DATE,du.DueDate)PaymentDueDate
         ,IIF(r.DocCurrency = 'THB',NULL,r.DocCurrency) DocCurrency
		   ,IIF(r.DocCurrency = 'THB',NULL,r.DocCurrencyRate) DocCurrencyRate
         ,IIF(r.DocCurrency = 'THB',NULL,st.Amount) CurrAmount
         ,rl.Id LineId
         ,IIF(@GroupByCurrency = 1,r.DocCurrency,'a')	GroupCode_0
         ,CASE WHEN @GroupByForm1 = 1 THEN 'b'					
					WHEN @GroupByForm1 = 2 THEN r.DestinationCode
					WHEN @GroupByForm1 = 3 THEN r.ExtOrgCode
					WHEN @GroupByForm1 = 4 THEN IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryCode,rl.ItemMetaCode)
               WHEN @GroupByForm1 = 5 THEN CONCAT('Payment due. ',FORMAT(du.DueDate,'dd/MM/yyyy'))
					ELSE 'b'   END  GroupCode_1
		   ,CASE WHEN @GroupByForm1 = 2 THEN r.DestinationName
               WHEN @GroupByForm1 = 3 THEN r.ExtOrgName
					WHEN @GroupByForm1 = 4 THEN ISNULL(NULLIF(rl.Description,''),IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryName,rl.ItemMetaName))
					ELSE NULL	END GroupName_1
         ,CASE WHEN @GroupByForm2 = 1 THEN 'c'					
					WHEN @GroupByForm2 = 2 THEN r.DestinationCode
					WHEN @GroupByForm2 = 3 THEN r.ExtOrgCode
					WHEN @GroupByForm2 = 4 THEN IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryCode,rl.ItemMetaCode)
               WHEN @GroupByForm2 = 5 THEN CONCAT('Payment due. ',FORMAT(du.DueDate,'dd/MM/yyyy'))
					ELSE 'c'   END GroupCode_2
		   ,CASE WHEN @GroupByForm2 = 2 THEN r.DestinationName
               WHEN @GroupByForm2 = 3 THEN r.ExtOrgName
					WHEN @GroupByForm2 = 4 THEN ISNULL(NULLIF(rl.Description,''),IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryName,rl.ItemMetaName))
					ELSE NULL	END GroupName_2
         ,IIF(CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
                   WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
                   ELSE 1 END = 1,IIF(@SortBy = 'Document Code',r.Code,FORMAT(r.Date,'yyyy-MM-dd')),'d') GroupCode_3
         ,CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
               WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3
               ELSE 1 END FormTag           
         ,IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryCode,rl.ItemMetaCode) ItemCode
		   ,ISNULL(NULLIF(rl.Description,''),IIF(ISNULL(NULLIF(rl.ItemMetaCode,'####'),'') = '',rl.ItemCategoryName,rl.ItemMetaName)) ItemName
         ,rl.DocQty,rl.DocUnitName
         ,rl.UnitPrice * r.DocCurrencyRate [UnitPrice]
         ,rl.DiscountAmount * r.DocCurrencyRate DiscountAmt
		 ,IIF(vat.SystemCategoryId = 123,(rl.Amount + ISNULL(ivat.TaxAmount,(ivat.Amount-ISNULL(ivat.SpecialDiscount,0))*(vat.TaxRate/100))) * r.DocCurrencyRate ,rl.Amount * r.DocCurrencyRate ) LineAmt/* rl.Amount * r.DocCurrencyRate LineAmt */
         ,IIF(rl.RefDocTypeId = 22,rl.RefDocId,NULL)RefDocId
         ,IIF(rl.RefDocTypeId = 22,rl.RefDocCode,NULL)RefDocCode
         ,IIF(rl.RefDocTypeId = 22,rl.RefDocLineId,NULL)RefDocLineId
		 ,vat.SystemCategoryId TypeVatId
         ,vat.SystemCategory TypeV
        ,CASE WHEN (ivat.TaxAmount IS NULL AND vat.SystemCategoryId = 129) THEN ((ivat.Amount-ISNULL(ivat.SpecialDiscount,0))*(vat.TaxRate/(100+vat.TaxRate)))*r.DocCurrencyRate
            WHEN (ivat.TaxAmount IS NULL AND vat.SystemCategoryId = 123) THEN ((ivat.Amount-ISNULL(ivat.SpecialDiscount,0))*(vat.TaxRate/100))*r.DocCurrencyRate
            WHEN (ivat.TaxAmount IS NULL AND vat.SystemCategoryId = 131) THEN 0
            ELSE ivat.TaxAmount
        END ItemVat
         ,IIF(ROW_NUMBER() OVER (PARTITION BY r.Id ORDER BY r.Id) = 1,vat.TaxAmount*r.DocCurrencyRate,0) RSVat
		 ,ISNULL(dc.Amount * r.DocCurrencyRate,0) SpecialDiscount
FROM	  dbo.ReceiveSuppliers r WITH (NOLOCK)
         INNER JOIN  dbo.ReceiveSupplierLines rl WITH (NOLOCK) ON r.Id = rl.ReceiveSupplierId AND CONVERT(DATE,r.Date)BETWEEN @FromDate AND @ToDate
         LEFT JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = r.DocStatus
         LEFT JOIN dbo.ReceiveSupplierLines du WITH (NOLOCK) ON du.SystemCategoryId IN (46,47) AND du.ReceiveSupplierId = r.Id
         LEFT JOIN dbo.ReceiveSupplierLines st WITH (NOLOCK) ON st.SystemCategoryId = 107 AND st.ReceiveSupplierId = r.Id
		 LEFT JOIN dbo.ReceiveSupplierLines vat WITH (NOLOCK) ON vat.SystemCategoryId IN (123,129,131) AND vat.ReceiveSupplierId = r.Id
		 LEFT JOIN dbo.ReceiveSupplierLines ivat WITH (NOLOCK) ON ivat.SystemCategoryId IN (99,100) AND ivat.ReceiveSupplierId = r.Id AND rl.Id = ivat.Id
		 LEFT JOIN dbo.ReceiveSupplierLines dc WITH (NOLOCK) ON dc.SystemCategoryId = 124 AND dc.ReceiveSupplierId = r.Id
WHERE    ISNULL(rl.ItemCategoryId,0) <> 0
         AND ((rl.ItemMetaCode IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaCode))) OR @ItemmetaCode IS NULL)
			AND ((EXISTS (SELECT 1 FROM @Cat ct WHERE ct.Id = rl.ItemCategoryId)) OR @categoryCode IS NULL)
			AND ((r.Code LIKE '%'+@Code+'%') OR @Code IS NULL)
			AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = r.DestinationId)) OR @OrganizationId IS NULL)
			AND ((r.ExtOrgCode = @SupplierCode) OR @SupplierCode IS NULL)
			AND ((r.DocStatus in (SELECT ncode FROM  dbo.fn_listCode(@Status))) OR @Status IS NULL)
			AND ((r.CreateBy LIKE '%'+@CreateBy+'%') OR @CreateBy IS NULL)
			AND ((r.DocCurrency in (SELECT ncode FROM  dbo.fn_listCode(@Currency))) OR @Currency IS NULL)
			AND ((ISNULL(@Canceled,0) = 0 AND r.DocStatus != -1) OR (ISNULL(@Canceled,0) = 1 ) OR ( ISNULL(@Status,0) = -1))
         AND ((@NotTHB = 1 AND ISNULL(r.DocCurrency,'THB') <> 'THB') OR( @NotTHB = 0 or @NotTHB is null) )
		AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR r.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = r.DestinationId))) OR @isPowerUser = 1)

         AND ((rl.RefDocCode LIKE '%'+@RefCode+'%') OR @RefCode IS NULL)
option(recompile)

SELECT	o.DocId
			,o.DocCode
			,o.DocDate
			,o.Remarks
			,o.DocStatus
			,o.OrgId
			,o.OrgCode
			,o.OrgName
			,o.ExtOrgId
			,o.ExtOrgCode
			,o.ExtOrgName
			,o.PaymentDueDate
			,o.DocCurrency
			,o.DocCurrencyRate
			,o.CurrAmount
			,o.LineId
			,o.GroupCode_0
			,o.GroupCode_1
			,o.GroupName_1
			,o.GroupCode_2
			,o.GroupName_2
			,o.GroupCode_3
			,o.FormTag
			,o.ItemCode
			,o.ItemName
			,o.DocQty
			,o.DocUnitName
			,o.UnitPrice
			,o.DiscountAmt
			,o.LineAmt 
			,o.RefDocId
			,o.RefDocCode
			,o.RefDocLineId
         ,IIF(@GroupByForm1 = 2 OR @GroupByForm2 = 2,o.ExtOrgCode,o.OrgCode) ImplicateCode
         ,IIF(@GroupByForm1 = 2 OR @GroupByForm2 = 2,o.ExtOrgName,o.OrgName) ImplicateName

		 ,@sitepath_130 + convert(nvarchar(max),o.DocId) SitePath
		 ,@sitepath_22 + convert(nvarchar(max),o.RefDocId) SitePathRef

         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2,o.GroupCode_3) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2,o.GroupCode_3) SubTotal
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2) SubTotalG2
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1) SubTotalG1
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0) SubTotalG0
         ,SUM(o.LineAmt) OVER (PARTITION BY 'x') - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY 'x') SubTotalGTT
		 ,o.TypeVatId
         ,o.TypeVat
         ,o.ItemVat
         ,o.RSVat
		 ,o.SpecialDiscount
FROM	   #cte_RS o
option(recompile)

/************************************************************************************************************************************************************************/


		DECLARE @StatusD nvarchar(200) = (
		select Description from CodeDescriptions WITH (NOLOCK) 
		where value = @Status and name ='DocStatus'
		)

SELECT IIF(@OrganizationId IS NOT NULL,(SELECT	Code FROM	dbo.Organizations WHERE Id = @OrganizationId),NULL) OrgCode
         ,CONCAT('Document between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy'))Date1
         ,CONCAT('GROUP BY ',CASE WHEN @GroupByForm1 = 1 THEN 'DOCUMENT'				
					                   WHEN @GroupByForm1 = 2 THEN 'PROJECT'
					                   WHEN @GroupByForm1 = 3 THEN 'SUPPLIER'
					                   WHEN @GroupByForm1 = 4 THEN 'ITEM'
                                  WHEN @GroupByForm1 = 5 THEN 'PAYMENT DUE.'
					                   ELSE 'DOCUMENT' END,' ',CASE WHEN @GroupByForm1 IN (2,3) AND @GroupByForm2 = 1 THEN 'AND DOCUMENT'				
					                                                WHEN @GroupByForm2 = 2 THEN 'AND PROJECT'
					                                                WHEN @GroupByForm2 = 3 THEN 'AND SUPPLIER'
					                                                WHEN @GroupByForm2 = 4 THEN 'AND ITEM'
                                                               WHEN @GroupByForm2 = 5 THEN 'AND PAYMENT DUE.'
					                                                ELSE '' END) ReportName
         ,IIF (@Canceled = 1 , 'YES' ,'NO') IncludeCancel 
		   ,IIF (@NotTHB = 1 , 'YES' ,'NO') NotShowTHB 
		   ,IIF (@GroupByCurrency = 1 , 'YES' ,'NO') GroupByCurrency
		   ,@Code DocCode
		   ,@StatusD status 
		   ,@ItemmetaCode itemmetacode
		   ,@SortBy [SortBy]



/************************************************************************************************************************************************************************/

/************************ Temp HeadName Org *******************************************/

SELECT * FROM fn_CompanyInfoTable(@OrganizationId)