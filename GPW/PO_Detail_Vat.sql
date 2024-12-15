 
/* PUR_PODetailReport_revise */

/*Edit 21-04-2020 By แบงค์เอง เพิ่มเรื่อง RoleSubDocType*/
/*Edit 2021-06-01 : Pichet : Fix Performance*/
/*Edit 2021-07-07 : Pichet : Fix Performance*/
/* 2021-10-06 : Edit By Bank เอง : MS-21755 แก้เรื่องสิทธิ์ใหม่ให้เห็นแม่ลูกได้ (ปรับไปใช้ Table ใหม่ของพี่ปุ้ย) */
/* 2021-10-11 : Edit By Bank เอง : MS-22008 เพิ่ม Filter SupplierTag ลงในรายงาน */
/* 2023-04-18 : Edit By Bank เอง : MS-28119 แก้เรื่อง DiscountAmount Percent ถ้าไม่มีก็ไม่ต้องแสดงยอดอไรออกมา */
/* 2023-11-29 : Edit By Opor : MS-30544 เพิ่ม Filter ติ๊ก Remarks เพื่อให้แสดงรายการ Remark ในแต่ละบรรทัดของเอกสาร PO*/

-- DECLARE @p0 DATE = '2024-11-28';
-- DECLARE @p1 DATE = '2024-11-28';
-- DECLARE @p2 DATE = NULL;
-- DECLARE @p3 DATE = NULL;
-- /*******************************/
-- DECLARE @p4 INT = NULL;
-- DECLARE @p5 BIT = 0
-- DECLARE @p6 NVARCHAR(200) = NULL;
-- DECLARE @p7 NVARCHAR(200) = NULL;
-- /*******************************/
-- DECLARE @p8 NVARCHAR(200) = NULL--'PO-M-HO-6506-001'
-- DECLARE @p9 NVARCHAR(200) = NULL;
-- DECLARE @p10 NVARCHAR(200) = NULL;
-- DECLARE @p11 NVARCHAR(200) = NULL;
-- DECLARE @p12 NVARCHAR(200) = NULL;
-- /*******************************/
-- DECLARE @p13 INT = 0;
-- DECLARE @p14 INT = 0;
-- DECLARE @p15 NVARCHAR(200) = NULL;
-- DECLARE @p16 NVARCHAR(200) = NULL;
-- DECLARE @p17 nvarchar(max) = ''
-- DECLARE @p18 BIT = 0;
-- DECLARE @p19 BIT = 0;
-- DECLARE @p20 BIT = 0;
-- DECLARE @p21 BIT = 1;
-- DECLARE @p22 BIT = 0;

/************************************************************************************************************************************************************************/

DECLARE @DocFromDate DATE = @p0;
DECLARE @DocToDate DATE = @p1;
DECLARE @DueFromDate DATE = @p2;
DECLARE @DueToDate DATE = @p3;
/*******************************/
DECLARE @OrganizationId INT = @p4;
DECLARE @IncChild BIT = @p5;
DECLARE @Destination NVARCHAR(200) = @p6;
DECLARE @SupplierCode NVARCHAR(200) = @p7;
/*******************************/
DECLARE @Code NVARCHAR(200)= @p8;
DECLARE @categoryCode NVARCHAR(300) = @p9;
DECLARE @ItemmetaCode NVARCHAR(300) = @p10;
DECLARE @Status NVARCHAR(200)= @p11; 
DECLARE @CreateBy NVARCHAR(200)= @p12;
/*******************************/
DECLARE @GroupByForm1 INT = @p13;
DECLARE @GroupByForm2 INT = @p14;
DECLARE @Currency NVARCHAR(200) = @p15;
DECLARE @SupplierTag NVARCHAR(200) = @p16;
DECLARE @filterItem nvarchar(max) = @p17;
DECLARE @GroupByCurrency BIT = @p18;
DECLARE @NotTHB BIT = @p19;
DECLARE @Canceled BIT = @p20;
DECLARE @ShowDateApprove BIT = @p21;
DECLARE @ShowRemark BIT = @p22;

/*******************************/
DECLARE @query NVARCHAR(MAX) = ''
DECLARE @Cat TABLE (Id INT)
DECLARE @Org TABLE (Id INT)
DECLARE @FormTag INT =	CASE	WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
															WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
															ELSE 1 END
set @filterItem = '%' + nullif(@filterItem, '') + '%'

/************************************* Tmp ItemCategory **************************************/

	 SELECT  @query += a.Query

	 FROM ( 
					SELECT   'SELECT Id  FROM dbo.ItemCategories WHERE Path LIKE '''+i.Path+'%'';' Query 
					FROM	   dbo.fn_listCode(@categoryCode) n
							   LEFT JOIN dbo.ItemCategories i WITH (NOLOCK) ON i.Code = n.ncode
					WHERE	   @categoryCode IS NOT NULL
                        ) a /*For Execute More AccountCode*/


	INSERT INTO @Cat(Id)

	EXECUTE(@query) /*Save AccountId to Temp.*/

/************************************* Tmp Organizations **************************************/


INSERT INTO @Org(Id)
            
            SELECT   o.Id 
            FROM     dbo.Organizations o 
            WHERE    (  (@IncChild = 1 AND o.Path LIKE '%|' + CONVERT(NVARCHAR(10),@OrganizationId) + '|%') 
                        OR (@IncChild = 0 AND o.Id = @OrganizationId)
                           )
declare @SitePath22 nvarchar(max)
select @SitePath22 = sp.SitePath from dbo.SitePathList() sp where sp.DocTypeId = 22

/************************************* Tmp SupplierTag **************************************/

declare @query2 NVARCHAR(MAX) = ''
DECLARE @SupplierTagId TABLE (Id INT);


                        select  @query2 += 'SELECT  Id  FROM dbo.ExtOrganizations  WHERE SupplierTagJSON LIKE ''%'+ti.TagName+'%'''+';'
                        FROM	  dbo.TagTypeItems ti 
                        WHERE	  ti.TagName IN (SELECT ncode FROM dbo.fn_listCode(@SupplierTag))

INSERT INTO @SupplierTagId(Id)

EXECUTE (@query2); 

/************************************* TempRoleSubdoctype *******************************************/

DECLARE @DoctypeList NVARCHAR(MAX) = '22,126'; 
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
	SELECT @isPowerUser = IIF(COUNT(w.Id) >= 1,1,0) 
	FROM dbo.CompanyConfigs cf
	INNER JOIN dbo.Workers w ON cf.Value = w.UserName
	WHERE ConfigName = 'GODWorker' AND @WorkerId = w.Id
END

SELECT *
INTO #TempRoleSubdoctype
FROM dbo.fn_GetRoleSubDocTypeReport(@WorkerId, @DoctypeList);

/************************************* Temp MileStone *******************************************/

IF OBJECT_ID(N'tempdb..#Temp_mi') IS NOT NULL
BEGIN
    DROP TABLE #Temp_mi;
END;

create table #Temp_mi
(
	  MiId				int
	, DocId				int
	, DocLineId			int
	, DocQty			nvarchar(200)
	, DocUnitName		nvarchar(2000)
	, DocUnitPrice		decimal(26,8)
	, DiscountPercent	nvarchar(200)
	, DiscountAmt		decimal(26,8)
	, DocAmount			decimal(26,8)
	, MiQty				nvarchar(200)
	, MiUnitPrice		decimal(26,8)
	, MiAmount			decimal(26,8)
	, DueDate			date
	, DestinationCode	nvarchar(200)
	, DestinationName	nvarchar(2000)
)

/************************************* Temp PO UNGROUP *******************************************/

IF OBJECT_ID(N'tempdb..#Temp_po_ungroup') IS NOT NULL
BEGIN
    DROP TABLE #Temp_po_ungroup;
END;

create table #Temp_po_ungroup
(

	 DocId					int
	,DocCode				nvarchar(200)
	,DocDate				date
	,PaymentDueDate			date
	,DueDate				date
	,Remarks				nvarchar(4000)
	,OrgId					int
	,OrgCode				nvarchar(200)
	,OrgName				nvarchar(2000)
	,ExtOrgId				int
	,ExtOrgCode				nvarchar(200)
	,ExtOrgName				nvarchar(2000)
	,ExtOrgContact			nvarchar(2000)
	,SystemCategoryId		int
	,DocCurrency			nvarchar(200)
	,DocCurrencyRate		decimal(28,12)
	,CurrAmount				decimal(26,8)
	,GroupCode_0			nvarchar(200)
	,GroupCode_1			nvarchar(200)
	,GroupName_1			nvarchar(2000)
	,GroupCode_2			nvarchar(200)
	,GroupName_2			nvarchar(2000)
	,GroupCode_3			nvarchar(200)
	,LineId					int
	,LineNumber				int
	,ItemCode				nvarchar(200)
	,ItemName				nvarchar(2000)
	,DocQty					nvarchar(200)
	,DocUnitName			nvarchar(2000)
	,UnitPrice				decimal(26,8)
	,DiscountPercent		nvarchar(200)
	,DiscountAmt			decimal(26,8)
	,LineAmt				decimal(26,8)
	,SubTotal				decimal(26,8)
	,MiQty					nvarchar(200)
	,MiAmount				decimal(26,8)
	,MiUnitPrice			decimal(26,8)
	,DestinationCode		nvarchar(200)
	,DestinationName		nvarchar(2000)
	,DocStatus				nvarchar(2000)
	,FormTag				int
	,SpecialDiscount		decimal(26,8)

)

/************************************* Temp PO *******************************************/

IF OBJECT_ID(N'tempdb..#Temp_po') IS NOT NULL
BEGIN
    DROP TABLE #Temp_po;
END;

create table #Temp_po
(

	 [ROW#]					int
	,DocId					int
	,DocCode				nvarchar(200)
	,DocDate				date
	,PaymentDueDate			date
	,Remarks				nvarchar(4000)
	,OrgId					int
	,OrgCode				nvarchar(200)
	,OrgName				nvarchar(2000)
	,ExtOrgId				int
	,ExtOrgCode				nvarchar(200)
	,ExtOrgName				nvarchar(2000)
	,ExtOrgContact			nvarchar(2000)
	,SystemCategoryId		int
	,DocCurrency			nvarchar(200)
	,DocCurrencyRate		decimal(28,12)
	,CurrAmount				decimal(26,8)
	,GroupCode_0			nvarchar(200)
	,GroupCode_1			nvarchar(200)
	,GroupName_1			nvarchar(2000)
	,GroupCode_2			nvarchar(200)
	,GroupName_2			nvarchar(2000)
	,GroupCode_3			nvarchar(200)
	,LineId					int
	,LineNumber				int
	,ItemCode				nvarchar(200)
	,ItemName				nvarchar(2000)
	,DocQty					nvarchar(200)
	,DocUnitName			nvarchar(2000)
	,UnitPrice				decimal(26,8)
	,DiscountPercent		nvarchar(200)
	,DiscountAmt			decimal(26,8)
	,LineAmt				decimal(26,8)
	,SubTotal				decimal(26,8)
	,DestinationCode		nvarchar(200)
	,DestinationName		nvarchar(2000)
	,DocStatus				nvarchar(2000)
	,SitePath				nvarchar(4000)
	,DueDate				nvarchar(4000)
	,FormTag				int
	,SpecialDiscount		decimal(26,8)
	,ItemVat				decimal(26,8)
	,POVat					decimal(26,8)
	,TypeVat				nvarchar(200)
	,TypeVatId				int

)

/************************************* Main Query *******************************************/

IF @FormTag IN (1,2)
BEGIN 


insert into #Temp_mi
(
	  MiId				
	, DocId				
	, DocLineId			
	, DocQty			
	, DocUnitName		
	, DocUnitPrice	
	, DiscountPercent	
	, DiscountAmt		
	, DocAmount			
	, MiQty				
	, MiUnitPrice		
	, MiAmount			
	, DueDate			
	, DestinationCode	
	, DestinationName	
)
SELECT 
				mx.MiId
			, mx.DocId
			, mx.DocLineId
			, mx.DocQty
			, mx.DocUnitName
			, mx.DocUnitPrice
		    , mx.DiscountPercent
			, mx.DiscountAmt
			, mx.DocAmount
			, mx.MiQty
			, mx.MiUnitPrice
			, mx.MiAmount
			, mx.DueDate
			, mx.DestinationCode
			, mx.DestinationName
FROM	
(
		SELECT	m.Id MiId
				,m.DocId
				,m.DocLineId
				,FORMAT(pol.DocQty,'n')DocQty
				,pol.DocUnitName
				,pol.UnitPrice DocUnitPrice
				,IIF(DATALENGTH(pol.Discount) = 0 or pol.Discount IS NULL ,'0', pol.Discount)  DiscountPercent
				,ISNULL(pol.DiscountAmount,0) DiscountAmt
				,ROUND((pol.UnitPrice*pol.DocQty),2) DocAmount
				,FORMAT(m.DocQty,'n') MiQty
				,m.DocQty * m.Amount MiUnitPrice
				,m.Amount MiAmount
				,CONVERT(DATE,m.DueDate)DueDate
				,m.DestinationCode
				,m.DestinationName
				,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocId)RefDocId
				,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocCode)RefDocCode
				,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocLineId)RefDocLineId
		FROM	   dbo.Milestones m WITH (NOLOCK)
		inner JOIN dbo.POLines pol WITH (NOLOCK) ON pol.Id = m.DocLineId AND m.DocTypeId = 22
		inner JOIN dbo.POes po WITH (NOLOCK) ON po.Id = m.DocId AND m.DocTypeId = 22
		WHERE    ((CONVERT(DATE,po.Date)BETWEEN @DocFromDate AND @DocToDate) OR NULLIF(@DocFromDate,'1900-01-01') IS NULL)
			AND ((CONVERT(DATE,m.DueDate)BETWEEN @DueFromDate AND @DueToDate) OR NULLIF(@DueFromDate,'1900-01-01') IS NULL)
			AND m.DocTypeId = 22 
			AND m.BookedStockState = 21
			AND m.SystemCategoryId <> 105
			AND ((pol.ItemMetaCode IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaCode))) OR @ItemmetaCode IS NULL)
			AND ((EXISTS (SELECT 1 FROM @Cat ct WHERE ct.Id = pol.ItemCategoryId)) OR @categoryCode IS NULL)
			AND ((po.Code LIKE '%'+@Code+'%') OR @Code IS NULL)
			AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = po.LocationId)) OR @OrganizationId IS NULL)
			AND ((po.ExtOrgCode = @SupplierCode) OR @SupplierCode IS NULL)
			AND ((po.DocStatus in (SELECT ncode FROM  dbo.fn_listCode(@Status))) OR @Status IS NULL)
			AND ((po.CreateBy LIKE '%'+ @CreateBy + '%') OR @CreateBy IS NULL)
			AND ((po.DocCurrency in (SELECT ncode FROM  dbo.fn_listCode(@Currency))) OR @Currency IS NULL)
			AND ((@Canceled = 0 AND ISNULL(po.DocStatus,0) <> -1) OR @Canceled = 1)
			AND ((@NotTHB = 1 AND ISNULL(po.DocCurrency,'THB') <> 'THB') OR @NotTHB = 0 )
			AND ((m.DestinationCode = @Destination) OR @Destination IS NULL)
			AND ((EXISTS (SELECT  'S_tag' FROM  @SupplierTagId spt WHERE spt.Id = po.ExtOrgId)) OR @SupplierTag IS NULL)
			AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR po.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = po.LocationId))) OR @isPowerUser = 1)

		UNION    ALL

		SELECT	
					m.Id MiId
					,m.DocId
					,pol.Id DocLineId
					,FORMAT(pol.DocQty,'n')DocQty
					,pol.DocUnitName
					,pol.UnitPrice DocUnitPrice
					,IIF(DATALENGTH(pol.Discount) = 0 or pol.Discount IS NULL ,'0', pol.Discount)  DiscountPercent
					,ISNULL(pol.DiscountAmount,0) DiscountAmt
					,pol.Amount DocAmount
					,CONCAT(FORMAT(m.DocQty,'#'),'%') MiQty
					,(m.Amount * 100)/m.DocQty MiUnitPrice
					,ROUND((pol.Amount*m.DocQty)/100,2) MiAmount
					,CONVERT(DATE,m.DueDate)DueDate
					,m.DestinationCode
					,m.DestinationName
					,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocId)RefDocId
					,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocCode)RefDocCode
					,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocLineId)RefDocLineId
		FROM	   dbo.Milestones m WITH (NOLOCK)
					inner JOIN dbo.POLines pol WITH (NOLOCK) ON ISNULL(pol.ItemCategoryId,0) <> 0 AND pol.SystemCategoryId IN (104,105) AND pol.POId = m.DocId AND m.DocTypeId = 22
					inner JOIN dbo.POes po WITH (NOLOCK) ON po.Id = m.DocId AND m.DocTypeId = 22
		WHERE    ((CONVERT(DATE,po.Date)BETWEEN @DocFromDate AND @DocToDate) OR NULLIF(@DocFromDate,'1900-01-01') IS NULL)
					AND ((CONVERT(DATE,m.DueDate)BETWEEN @DueFromDate AND @DueToDate) OR NULLIF(@DueFromDate,'1900-01-01') IS NULL)
					AND m.DocTypeId = 22 AND (m.BookedStockState = 21 OR m.BookedStockState IS NULL)
					AND m.SystemCategoryId IN (104,105)
					AND ((pol.ItemMetaCode IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaCode))) OR @ItemmetaCode IS NULL)
					AND ((EXISTS (SELECT 1 FROM @Cat ct WHERE ct.Id = pol.ItemCategoryId)) OR @categoryCode IS NULL)
					AND ((po.Code LIKE '%'+@Code+'%') OR @Code IS NULL)
					AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = po.LocationId)) OR @OrganizationId IS NULL)
					AND ((po.ExtOrgCode = @SupplierCode) OR @SupplierCode IS NULL)
					AND ((po.DocStatus in (SELECT ncode FROM  dbo.fn_listCode(@Status))) OR @Status IS NULL)
					AND ((po.CreateBy LIKE '%'+ @CreateBy + '%') OR @CreateBy IS NULL)
					AND ((po.DocCurrency in (SELECT ncode FROM  dbo.fn_listCode(@Currency))) OR @Currency IS NULL)
					AND ((@Canceled = 0 AND ISNULL(po.DocStatus,0) <> -1) OR @Canceled = 1)
					AND ((@NotTHB = 1 AND ISNULL(po.DocCurrency,'THB') <> 'THB') OR @NotTHB = 0 )
					AND ((m.DestinationCode = @Destination) OR @Destination IS NULL)
					AND ((EXISTS (SELECT  'S_tag' FROM  @SupplierTagId spt WHERE spt.Id = po.ExtOrgId)) OR @SupplierTag IS NULL)
					AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR po.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = po.LocationId))) OR @isPowerUser = 1)
) mx
option(recompile)

/*----------------------------------------------------------------------------*/

insert into #Temp_po_ungroup
(

	 DocId					
	,DocCode				
	,DocDate				
	,PaymentDueDate			
	,DueDate				
	,Remarks				
	,OrgId					
	,OrgCode				
	,OrgName				
	,ExtOrgId				
	,ExtOrgCode				
	,ExtOrgName	
	,ExtOrgContact
	,SystemCategoryId		
	,DocCurrency			
	,DocCurrencyRate		
	,CurrAmount				
	,GroupCode_0			
	,GroupCode_1			
	,GroupName_1			
	,GroupCode_2			
	,GroupName_2			
	,GroupCode_3			
	,LineId					
	,LineNumber				
	,ItemCode				
	,ItemName				
	,DocQty					
	,DocUnitName			
	,UnitPrice	
	,DiscountPercent		
	,DiscountAmt			
	,LineAmt				
	,SubTotal				
	,MiQty					
	,MiAmount				
	,MiUnitPrice			
	,DestinationCode		
	,DestinationName		
	,DocStatus				
	,FormTag				
	,SpecialDiscount


)
SELECT   
			po.Id DocId
			,po.Code DocCode
			,CONVERT(DATE,po.Date) DocDate
			,CONVERT(DATE,ISNULL(NULLIF(du.DueDate,''),po.Date))PaymentDueDate
			,mi.DueDate
			,po.Remarks
			,po.LocationId OrgId
			,po.LocationCode OrgCode
			,po.LocationName OrgName
			,po.ExtOrgId
			,po.ExtOrgCode
			,po.ExtOrgName
			,po.ExtOrgContact
			,po.SystemCategoryId
			,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrency) DocCurrency
			,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrencyRate) DocCurrencyRate
			,IIF(po.DocCurrency = 'THB',NULL,st.Amount) CurrAmount
			,IIF(@GroupByCurrency = 1,po.DocCurrency,'a')	GroupCode_0
			,CASE WHEN @GroupByForm1 = 1 THEN 'b'					
					WHEN @GroupByForm1 = 2 THEN po.LocationCode
					WHEN @GroupByForm1 = 3 THEN po.ExtOrgCode
					WHEN @GroupByForm1 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				WHEN @GroupByForm1 = 5 THEN CONCAT('Delivery date. ',FORMAT(mi.DueDate,'dd/MM/yyyy'))
					ELSE 'b'   END  GroupCode_1
			,CASE WHEN @GroupByForm1 = 2 THEN po.LocationName
				WHEN @GroupByForm1 = 3 THEN po.ExtOrgName
					WHEN @GroupByForm1 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
					ELSE NULL	END GroupName_1
			,CASE WHEN @GroupByForm2 = 1 THEN 'c'					
					WHEN @GroupByForm2 = 2 THEN po.LocationCode
					WHEN @GroupByForm2 = 3 THEN po.ExtOrgCode
					WHEN @GroupByForm2 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				WHEN @GroupByForm2 = 5 THEN CONCAT('Delivery date. ',FORMAT(mi.DueDate,'dd/MM/yyyy'))
					ELSE 'c'   END GroupCode_2
			,CASE WHEN @GroupByForm2 = 2 THEN po.LocationName
				WHEN @GroupByForm2 = 3 THEN po.ExtOrgName
					WHEN @GroupByForm2 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
					ELSE NULL	END GroupName_2
			,IIF(CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
				    WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
				    ELSE 1 END = 1,po.Code,'d') GroupCode_3 
			,pol.Id LineId,pol.LineNumber
			,IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode) ItemCode
			,ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName)) ItemName		
			,mi.DocQty
			,mi.DocUnitName
			,mi.DocUnitPrice * po.DocCurrencyRate UnitPrice
			,CASE   WHEN CHARINDEX('%',mi.DiscountPercent) > 0 then mi.DiscountPercent
                    WHEN mi.DocAmount = 0 THEN '0%'
					WHEN mi.DiscountAmt = 0 THEN '' /*หากไม่มี DiscountAmt หรือ DiscountPercent ก็ให้ไม่แสดงอะไรเลย*/
                    WHEN mi.DocAmount % 100 <> 0 THEN FORMAT(mi.DocAmount/100,'0.00') + '%'
                    ELSE CONCAT(CONVERT(INT,mi.DocAmount/100),'%')
             END  [DiscountPercent]
			,mi.DiscountAmt * po.DocCurrencyRate	DiscountAmt
			,mi.DocAmount * po.DocCurrencyRate LineAmt
			,st.Amount * po.DocCurrencyRate SubTotal
			,mi.MiQty,mi.MiAmount * po.DocCurrencyRate MiAmount ,mi.MiUnitPrice * po.DocCurrencyRate MiUnitPrice
			,mi.DestinationCode, mi.DestinationName
			,cd.Description DocStatus
			,CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
				WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
				ELSE 1 END FormTag
			,ISNULL(dc.Amount,0) SpecialDiscount
			
FROM	
	#Temp_mi mi
	LEFT JOIN dbo.POLines pol WITH (NOLOCK) ON pol.Id = mi.DocLineId AND mi.DocId = pol.POId
	LEFT JOIN dbo.POes po WITH (NOLOCK) ON po.Id = pol.POId
	LEFT hash JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = po.DocStatus
	LEFT JOIN dbo.POLines du WITH (NOLOCK) ON du.SystemCategoryId IN (46,47) AND du.POId = po.Id
	LEFT JOIN dbo.POLines st WITH (NOLOCK) ON st.SystemCategoryId = 107 AND st.POId = po.Id
	LEFT JOIN dbo.POLines dc WITH (NOLOCK) ON dc.SystemCategoryId = 124 AND dc.POId = po.Id

UNION ALL 

	SELECT   
			po.Id DocId
			,po.Code DocCode
			,CONVERT(DATE,po.Date) DocDate
			,CONVERT(DATE,ISNULL(NULLIF(du.DueDate,''),po.Date))PaymentDueDate
			,NULL DueDate
			,po.Remarks
			,po.LocationId OrgId
			,po.LocationCode OrgCode
			,po.LocationName OrgName
			,po.ExtOrgId
			,po.ExtOrgCode
			,po.ExtOrgName
			,po.ExtOrgContact
			,pol.SystemCategoryId
			,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrency) DocCurrency
			,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrencyRate) DocCurrencyRate
			,IIF(po.DocCurrency = 'THB',NULL,st.Amount) CurrAmount
			,IIF(@GroupByCurrency = 1,po.DocCurrency,'a')	GroupCode_0
			,CASE WHEN @GroupByForm1 = 1 THEN 'b'					
					WHEN @GroupByForm1 = 2 THEN po.LocationCode
					WHEN @GroupByForm1 = 3 THEN po.ExtOrgCode
					WHEN @GroupByForm1 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				WHEN @GroupByForm1 = 5 THEN ''
					ELSE 'b'   END  GroupCode_1
			,CASE WHEN @GroupByForm1 = 2 THEN po.LocationName
				WHEN @GroupByForm1 = 3 THEN po.ExtOrgName
					WHEN @GroupByForm1 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
					ELSE NULL	END GroupName_1
			,CASE WHEN @GroupByForm2 = 1 THEN 'c'					
					WHEN @GroupByForm2 = 2 THEN po.LocationCode
					WHEN @GroupByForm2 = 3 THEN po.ExtOrgCode
					WHEN @GroupByForm2 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				WHEN @GroupByForm2 = 5 THEN ''
					ELSE 'c'   END GroupCode_2
			,CASE WHEN @GroupByForm2 = 2 THEN po.LocationName
				WHEN @GroupByForm2 = 3 THEN po.ExtOrgName
					WHEN @GroupByForm2 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
					ELSE NULL	END GroupName_2
			,IIF(CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
				    WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
				    ELSE 1 END = 1,po.Code,'d') GroupCode_3 
			,pol.Id LineId,pol.LineNumber
			,IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode) ItemCode
			,ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName)) ItemName		
			,NULL DocQty
			,NULL DocUnitName
			,NULL UnitPrice
			,NULL [DiscountPercent]
			,NULL	DiscountAmt
			,NULL LineAmt
			,st.Amount * po.DocCurrencyRate SubTotal
			,NULL MiQty
			,NULL MiAmount
			,NULL MiUnitPrice
			,NULL DestinationCode
			,NULL DestinationName
			,cd.Description DocStatus
			,CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
				WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
				ELSE 1 END FormTag
			,ISNULL(dc.Amount,0) SpecialDiscount
	FROM 
		(select * from dbo.POes po where po.Id in (select DocId from #Temp_mi group by DocId )) po
		JOIN dbo.POLines pol WITH (NOLOCK) ON pol.POId = po.Id AND pol.SystemCategoryId = -2
		LEFT hash JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = po.DocStatus
		LEFT JOIN dbo.POLines du WITH (NOLOCK) ON du.SystemCategoryId IN (46,47) AND du.POId = po.Id
		LEFT JOIN dbo.POLines st WITH (NOLOCK) ON st.SystemCategoryId = 107 AND st.POId = po.Id
		LEFT JOIN dbo.POLines dc WITH (NOLOCK) ON dc.SystemCategoryId = 124 AND dc.POId = po.Id
	WHERE @ShowRemark = 1 
	AND NOT (ISNULL(@GroupByForm1,0) = 4 OR ISNULL(@GroupByForm2,0) = 4)

option(recompile)


/*----------------------------------------------------------------------------*/

insert into #Temp_po
(
	 [ROW#]					
	,DocId					
	,DocCode				
	,DocDate				
	,PaymentDueDate			
	,Remarks				
	,OrgId					
	,OrgCode				
	,OrgName				
	,ExtOrgId				
	,ExtOrgCode				
	,ExtOrgName	
	,ExtOrgContact
	,SystemCategoryId		
	,DocCurrency			
	,DocCurrencyRate		
	,CurrAmount				
	,GroupCode_0			
	,GroupCode_1			
	,GroupName_1			
	,GroupCode_2			
	,GroupName_2			
	,GroupCode_3			
	,LineId					
	,LineNumber				
	,ItemCode				
	,ItemName				
	,DocQty					
	,DocUnitName			
	,UnitPrice		
	,DiscountPercent
	,DiscountAmt			
	,LineAmt				
	,SubTotal				
	,DestinationCode		
	,DestinationName		
	,DocStatus				
	,SitePath				
	,DueDate				
	,FormTag				
	,SpecialDiscount	
    ,ItemVat	
	,POVat		
	,TypeVat	
	,TypeVatId	
)

		SELECT   ROW_NUMBER() OVER (PARTITION BY t.DocId ORDER BY t.DocId,t.LineNumber) ROW#
					,t.DocId
					,t.DocCode
					,t.DocDate
					,t.PaymentDueDate
					,t.Remarks
					,t.OrgId
					,t.OrgCode
					,t.OrgName
					,t.ExtOrgId
					,t.ExtOrgCode
					,t.ExtOrgName
					,t.ExtOrgContact
					,t.SystemCategoryId
					,t.DocCurrency
					,t.DocCurrencyRate
					,t.CurrAmount
					,t.GroupCode_0
					,t.GroupCode_1
					,t.GroupName_1
					,t.GroupCode_2
					,t.GroupName_2
		         ,t.GroupCode_3
					,t.LineId
					,t.LineNumber
					,t.ItemCode
					,t.ItemName
					,t.DocQty
					,t.DocUnitName
					,t.UnitPrice
					,t.DiscountPercent
					,t.DiscountAmt
					,IIF(pvat.SystemCategoryId = 123, round(t.LineAmt-t.DiscountAmt,2) + (ivat.TaxAmount * ISNULL(t.DocCurrencyRate,1)),round(t.LineAmt-t.DiscountAmt,2))/* round(t.LineAmt-t.DiscountAmt,2) */ LineAmt 
					,IIF(pvat.SystemCategoryId = 123, t.SubTotal-t.SpecialDiscount + (pvat.TaxAmount * ISNULL(t.DocCurrencyRate,1)),t.SubTotal-t.SpecialDiscount) SubTotal
		            ,NULL DestinationCode
					,NULL DestinationName
					,t.DocStatus
					,@SitePath22 + convert(nvarchar(100),t.DocId)	SitePath	/*dbo.SitePath(22,t.DocId)*/		
		         ,dbo.GROUP_CONCAT_DS(DISTINCT CASE WHEN t.SystemCategoryId = 105 
		                                            THEN CONCAT('DUE. ',FORMAT(t.DueDate,'dd/MM/yy'),'  |  AMT. ',FORMAT(t.LineAmt,'n'),' (',t.MiQty,')')
													WHEN t.SystemCategoryId = -2
		                                            THEN ''
		                                            ELSE CONCAT('DUE. ',FORMAT(t.DueDate,'dd/MM/yy'),'  |  QTY. ',t.MiQty) 
		                                            END ,'   ',1) DueDate 
		          ,t.FormTag 
				  ,t.SpecialDiscount
				  , ivat.TaxAmount [ItemVat]
                  , IIF(t.LineNumber = 1,pvat.TaxAmount,0) POVat
					,pvat.SystemCategory TypeVat
					,pvat.SystemCategoryId  TypeVatId

FROM  #Temp_po_ungroup t
LEFT JOIN POLines ivat ON t.LineId = ivat.Id AND ivat.SystemCategoryId IN (99,100)
LEFT JOIN POLines pvat ON t.DocId = pvat.POId AND pvat.SystemCategoryId IN (123,129,131)
GROUP BY 
			t.DocId
			,t.DocCode
			,t.DocDate
			,t.PaymentDueDate
			,t.Remarks
			,t.OrgId
			,t.OrgCode
			,t.OrgName
			,t.ExtOrgId
			,t.ExtOrgCode
			,t.ExtOrgName
			,t.ExtOrgContact
			,t.SystemCategoryId
			,t.DocCurrency
			,t.DocCurrencyRate
			,t.CurrAmount
			,t.GroupCode_0
			,t.GroupCode_1
			,t.GroupName_1
			,t.GroupCode_2
			,t.GroupName_2
			,t.GroupCode_3
			,t.LineId
			,t.LineNumber
			,t.ItemCode
			,t.ItemName
			,t.DocQty
			,t.DocUnitName
			,t.UnitPrice
			,t.DiscountPercent
			,t.DiscountAmt
			,t.LineAmt
			,t.SubTotal
			,t.DocStatus
			,t.FormTag 
			,t.SpecialDiscount
			,pvat.SystemCategory,pvat.SystemCategoryId,ivat.TaxAmount,pvat.TaxAmount
option(recompile)

SELECT	o.DocId
			,o.DocCode
			,o.DocDate
			,o.PaymentDueDate
			,o.Remarks
			,o.OrgId
			,o.OrgCode
			,o.OrgName
			,o.ExtOrgId
			,o.ExtOrgCode
			,o.ExtOrgName
			,o.ExtOrgContact
			,o.SystemCategoryId
			,o.DocCurrency
			,o.DocCurrencyRate
			,o.CurrAmount
			,o.GroupCode_0
			,o.GroupCode_1
			,o.GroupName_1
			,o.GroupCode_2
			,o.GroupName_2
			,o.GroupCode_3
			,o.LineId
			,o.LineNumber
			,nr.LineNumberNotRemark
			,o.ItemCode
			,o.ItemName
			,o.DocQty
			,o.DocUnitName
			,o.UnitPrice
			,o.DiscountPercent
			,o.DiscountAmt
			,o.LineAmt
			,o.SubTotal
			,o.DestinationCode
			,o.DestinationName
			,o.DocStatus
			,o.SitePath
			,mls.Location
			,o.DueDate
			,o.FormTag
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1,o.GroupCode_2) SubTotalG2
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0,o.GroupCode_1) SubTotalG1
         ,SUM(o.LineAmt) OVER (PARTITION BY o.GroupCode_0) - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY o.GroupCode_0) SubTotalG0
         ,SUM(o.LineAmt) OVER (PARTITION BY 'x') - SUM(IIF(ROW# = 1,o.SpecialDiscount,0)) OVER (PARTITION BY 'x') SubTotalGTT
		 ,dp2.CreateTimeStamp [DateApprove]
		 ,@ShowDateApprove ShowDateApprove
		 ,o.SpecialDiscount
         ,o.ItemVat, o.POVat
		,o.TypeVat
		 
FROM	
#Temp_po o
outer apply
(
		SELECT dp2.DocId,apl.Action,apl.CreateTimeStamp 
		FROM dbo.DocLineOfApproves dp2 with(forceseek)
		INNER JOIN	dbo.ApproveDetailLogs apl ON dp2.Id = apl.DocLineOfApproveId AND apl.Action = 'Done'	
		where
		o.DocId = dp2.DocId
		AND dp2.DocTypeId = 22
) dp2 /*ON o.DocId = dp2.DocId*/
	OUTER APPLY (select dbo.GROUP_CONCAT_D(distinct ml.DestinationCode,', ') Location from Milestones ml where ml.DocId = o.DocId and ml.DocTypeId = 22 and ml.DocLineId = o.LineId) mls
	LEFT JOIN (
		select ROW_NUMBER() OVER (PARTITION BY notRemark.DocId ORDER BY notRemark.LineNumber) LineNumberNotRemark ,notRemark.LineId
		from #Temp_po notRemark
		where notRemark.SystemCategoryId <> -2
	) nr on nr.LineId = o.LineId
where ( @filterItem is null or (o.ItemName Like @filterItem))
option(recompile)

END
ELSE 
BEGIN 

insert into #Temp_mi
(
	  MiId				
	, DocId				
	, DocLineId			
	, DocQty			
	, DocUnitName		
	, DocUnitPrice	
	, DiscountPercent
	, DiscountAmt		
	, DocAmount			
	, MiQty				
	, MiUnitPrice		
	, MiAmount			
	, DueDate			
	, DestinationCode	
	, DestinationName	
)
SELECT 
		  mx.MiId
		, mx.DocId
		, mx.DocLineId
		, mx.DocQty
		, mx.DocUnitName
		, mx.DocUnitPrice
		, mx.DiscountPercent
		, mx.DiscountAmt
		, mx.DocAmount
		, mx.MiQty
		, mx.MiUnitPrice
		, mx.MiAmount
		, mx.DueDate
		, mx.DestinationCode
		, mx.DestinationName
FROM	
(
		SELECT	m.Id MiId,m.DocId,m.DocLineId,FORMAT(pol.DocQty,'n')DocQty,pol.DocUnitName,pol.UnitPrice DocUnitPrice,IIF(DATALENGTH(pol.Discount) = 0 or Discount IS NULL ,'0', pol.Discount)  DiscountPercent
					,ROUND((pol.UnitPrice*pol.DocQty),2) DocAmount,ISNULL(pol.DiscountAmount,0) DiscountAmt
				  	,FORMAT(m.DocQty,'n') MiQty,m.DocQty * m.Amount MiUnitPrice,m.Amount MiAmount,CONVERT(DATE,m.DueDate)DueDate,m.DestinationCode,m.DestinationName
				  	,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocId)RefDocId,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocCode)RefDocCode,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocLineId)RefDocLineId
		FROM	   dbo.Milestones m WITH (NOLOCK)
				  	LEFT JOIN dbo.POLines pol WITH (NOLOCK) ON pol.Id = m.DocLineId AND m.DocTypeId = 22
				  	LEFT JOIN dbo.POes po WITH (NOLOCK) ON po.Id = m.DocId AND m.DocTypeId = 22
					--INNER JOIN #TempRoleSubdoctype rsd WITH (NOLOCK) ON rsd.SubDocTypeId = po.SubDocTypeId AND po.LocationId = rsd.OrgId
		WHERE    ((CONVERT(DATE,po.Date)BETWEEN @DocFromDate AND @DocToDate) OR NULLIF(@DocFromDate,'1900-01-01') IS NULL)
					AND ((CONVERT(DATE,m.DueDate)BETWEEN @DueFromDate AND @DueToDate) OR NULLIF(@DueFromDate,'1900-01-01') IS NULL)
					AND m.DocTypeId = 22 --AND m.BookedStockState = 21
					AND m.SystemCategoryId <> 105
					AND ((pol.ItemMetaCode IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaCode))) OR @ItemmetaCode IS NULL)
				AND ((EXISTS (SELECT 1 FROM @Cat ct WHERE ct.Id = pol.ItemCategoryId)) OR @categoryCode IS NULL)
				AND ((po.Code LIKE '%'+@Code+'%') OR @Code IS NULL)
				AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = po.LocationId)) OR @OrganizationId IS NULL)
				AND ((po.ExtOrgCode = @SupplierCode) OR @SupplierCode IS NULL)
				AND ((po.DocStatus in (SELECT ncode FROM  dbo.fn_listCode(@Status))) OR @Status IS NULL)
				AND ((po.CreateBy LIKE '%'+ @CreateBy + '%') OR @CreateBy IS NULL)
				AND ((po.DocCurrency in (SELECT ncode FROM  dbo.fn_listCode(@Currency))) OR @Currency IS NULL)
				AND ((@Canceled = 0 AND ISNULL(po.DocStatus,0) <> -1) OR @Canceled = 1)
					AND ((@NotTHB = 1 AND ISNULL(po.DocCurrency,'THB') <> 'THB') OR @NotTHB = 0 )
					AND ((m.DestinationCode = @Destination) OR @Destination IS NULL)
					AND ((EXISTS (SELECT  'S_tag' FROM  @SupplierTagId spt WHERE spt.Id = po.ExtOrgId)) OR @SupplierTag IS NULL)
				AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR po.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = po.LocationId))) OR @isPowerUser = 1)

		UNION    ALL

		SELECT	
					m.Id MiId,m.DocId,pol.Id DocLineId,FORMAT(pol.DocQty,'n')DocQty,pol.DocUnitName,pol.UnitPrice DocUnitPrice,IIF(DATALENGTH(pol.Discount) = 0 or Discount IS NULL ,'0', pol.Discount)  DiscountPercent
					,ISNULL(pol.DiscountAmount,0) DiscountAmt,pol.Amount DocAmount
					,CONCAT(FORMAT(m.DocQty,'#'),'%') MiQty,(m.Amount * 100)/m.DocQty MiUnitPrice,ROUND((pol.Amount*m.DocQty)/100,2) MiAmount,CONVERT(DATE,m.DueDate)DueDate,m.DestinationCode,m.DestinationName
					,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocId)RefDocId,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocCode)RefDocCode,IIF(ISNULL(pol.RefDocId,0)=0,NULL,pol.RefDocLineId)RefDocLineId
		FROM	   dbo.Milestones m WITH (NOLOCK)
					LEFT JOIN dbo.POLines pol WITH (NOLOCK) ON ISNULL(pol.ItemCategoryId,0) <> 0 AND pol.SystemCategoryId = 105 AND pol.POId = m.DocId AND m.DocTypeId = 22
					LEFT JOIN dbo.POes po WITH (NOLOCK) ON po.Id = m.DocId AND m.DocTypeId = 22
					--INNER JOIN #TempRoleSubdoctype rsd WITH (NOLOCK) ON rsd.SubDocTypeId = po.SubDocTypeId AND po.LocationId = rsd.OrgId
		WHERE    ((CONVERT(DATE,po.Date)BETWEEN @DocFromDate AND @DocToDate) OR NULLIF(@DocFromDate,'1900-01-01') IS NULL)
					AND ((CONVERT(DATE,m.DueDate)BETWEEN @DueFromDate AND @DueToDate) OR NULLIF(@DueFromDate,'1900-01-01') IS NULL)
					AND m.DocTypeId = 22 --AND m.BookedStockState = 21
					AND m.SystemCategoryId = 105
					AND ((pol.ItemMetaCode IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaCode))) OR @ItemmetaCode IS NULL)
					AND ((EXISTS (SELECT 1 FROM @Cat ct WHERE ct.Id = pol.ItemCategoryId)) OR @categoryCode IS NULL)
					AND ((po.Code LIKE '%'+@Code+'%') OR @Code IS NULL)
					AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = po.LocationId)) OR @OrganizationId IS NULL)
					AND ((po.ExtOrgCode = @SupplierCode) OR @SupplierCode IS NULL)
					AND ((po.DocStatus in (SELECT ncode FROM  dbo.fn_listCode(@Status))) OR @Status IS NULL)
					AND ((po.CreateBy LIKE '%'+ @CreateBy + '%') OR @CreateBy IS NULL)
					AND ((po.DocCurrency in (SELECT ncode FROM  dbo.fn_listCode(@Currency))) OR @Currency IS NULL)
					AND ((@Canceled = 0 AND ISNULL(po.DocStatus,0) <> -1) OR @Canceled = 1)
					AND ((@NotTHB = 1 AND ISNULL(po.DocCurrency,'THB') <> 'THB') OR @NotTHB = 0 )
					AND ((m.DestinationCode = @Destination) OR @Destination IS NULL)
					AND ((EXISTS (SELECT  'S_tag' FROM  @SupplierTagId spt WHERE spt.Id = po.ExtOrgId)) OR @SupplierTag IS NULL)
					AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR po.SubDocTypeId = rsd.SubDocTypeId ) AND (rsd.AllOrg = 1 OR rsd.OrgId = po.LocationId))) OR @isPowerUser = 1)
) mx
option(recompile)

/*----------------------------------------------------------------------------*/

SELECT   t.DocId
			,t.DocCode
			,t.DocDate
			,t.PaymentDueDate
			,t.Remarks
			,t.OrgId
			,t.OrgCode
			,t.OrgName
			,t.ExtOrgId
			,t.ExtOrgCode
			,t.ExtOrgName
			,t.ExtOrgContact
			,t.SystemCategoryId
			,t.DocCurrency
			,t.DocCurrencyRate
			,t.CurrAmount
			,t.GroupCode_0
			,t.GroupCode_1
			,t.GroupName_1
			,t.GroupCode_2
			,t.GroupName_2
            ,t.GroupCode_3
			,t.LineId
			,t.LineNumber
			,t.ItemCode
			,t.ItemName
			,t.MiQty DocQty
			,t.DocUnitName
			,t.MiUnitPrice UnitPrice
			,NULL DiscountPercent
			,NULL DiscountAmt
			,IIF(t.TypeVatId = 123, t.MiAmount + (t.ItemVat * ISNULL(t.DocCurrencyRate,1)),t.MiAmount) LineAmt
			,IIF(t.TypeVatId = 123, t.SubTotal + (t.POVat - t.SpecialDiscount) * ISNULL(t.DocCurrencyRate,1),t.SubTotal-t.SpecialDiscount) SubTotal
         ,t.DestinationCode, t.DestinationName
			,t.DocStatus
			,@SitePath22 + convert(nvarchar(100),t.DocId)	SitePath	/*dbo.SitePath(22,t.DocId)*/
			,Location
         ,FORMAT(t.DueDate,'dd/MM/yy')DueDate 
          ,t.FormTag 
         ,SUM(t.MiAmount) OVER (PARTITION BY t.GroupCode_0,t.GroupCode_1,t.GroupCode_2) - SUM(t.SpecialDiscount) OVER (PARTITION BY t.GroupCode_0,t.GroupCode_1,t.GroupCode_2) SubTotalG2
         ,SUM(t.MiAmount) OVER (PARTITION BY t.GroupCode_0,t.GroupCode_1) - SUM(t.SpecialDiscount) OVER (PARTITION BY t.GroupCode_0,t.GroupCode_1) SubTotalG1
         ,SUM(t.MiAmount) OVER (PARTITION BY t.GroupCode_0) - SUM(t.SpecialDiscount) OVER (PARTITION BY t.GroupCode_0) SubTotalG0
         ,SUM(t.MiAmount) OVER (PARTITION BY 'x') - SUM(t.SpecialDiscount) OVER (PARTITION BY 'x') SubTotalGTT
		 ,t.DateApprove
		 ,@ShowDateApprove ShowDateApprove
		 ,t.SpecialDiscount,t.POVat,t.ItemVat,t.TypeVat
		 
FROM  
(
	SELECT   
				 po.Id DocId
				,po.Code DocCode
				,CONVERT(DATE,po.Date) DocDate
				,CONVERT(DATE,ISNULL(NULLIF(du.DueDate,''),po.Date))PaymentDueDate
				,mi.DueDate
				,po.Remarks
				,po.LocationId OrgId
				,po.LocationCode OrgCode
				,po.LocationName OrgName
				,po.ExtOrgId
				,po.ExtOrgCode
				,po.ExtOrgName
				,po.ExtOrgContact
			 ,po.SystemCategoryId
			 ,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrency) DocCurrency
			   ,IIF(po.DocCurrency = 'THB',NULL,po.DocCurrencyRate) DocCurrencyRate
			 ,IIF(po.DocCurrency = 'THB',NULL,st.Amount) CurrAmount
			 ,IIF(@GroupByCurrency = 1,po.DocCurrency,'a')	GroupCode_0
			 ,CASE WHEN @GroupByForm1 = 1 THEN 'b'					
						WHEN @GroupByForm1 = 2 THEN po.LocationCode
						WHEN @GroupByForm1 = 3 THEN po.ExtOrgCode
						WHEN @GroupByForm1 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				   WHEN @GroupByForm1 = 5 THEN CONCAT('Delivery date. ',FORMAT(mi.DueDate,'dd/MM/yyyy'))
						ELSE 'b'   END  GroupCode_1
			   ,CASE WHEN @GroupByForm1 = 2 THEN po.LocationName
				   WHEN @GroupByForm1 = 3 THEN po.ExtOrgName
						WHEN @GroupByForm1 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
						ELSE NULL	END GroupName_1
			 ,CASE WHEN @GroupByForm2 = 1 THEN 'c'					
						WHEN @GroupByForm2 = 2 THEN po.LocationCode
						WHEN @GroupByForm2 = 3 THEN po.ExtOrgCode
						WHEN @GroupByForm2 = 4 THEN IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode)
				   WHEN @GroupByForm2 = 5 THEN CONCAT('Delivery date. ',FORMAT(mi.DueDate,'dd/MM/yyyy'))
						ELSE 'c'   END GroupCode_2
			   ,CASE WHEN @GroupByForm2 = 2 THEN po.LocationName
				   WHEN @GroupByForm2 = 3 THEN po.ExtOrgName
						WHEN @GroupByForm2 = 4 THEN ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName))
						ELSE NULL	END GroupName_2
			 ,IIF(CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
					   WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
					   ELSE 1 END = 1,po.Code,'d') GroupCode_3 
			 ,pol.Id LineId,pol.LineNumber
			   ,IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryCode,pol.ItemMetaCode) ItemCode
			   ,ISNULL(NULLIF(pol.Description,''),IIF(ISNULL(NULLIF(pol.ItemMetaCode,'####'),'') = '',pol.ItemCategoryName,pol.ItemMetaName)) ItemName		
			   ,mi.DocQty
			   ,mi.DocUnitName 
			   ,mi.DocUnitPrice * po.DocCurrencyRate UnitPrice
			   ,CASE    WHEN CHARINDEX('%',mi.DiscountPercent) > 0 then mi.DiscountPercent
						WHEN mi.DocAmount = 0 THEN '0%'
						WHEN mi.DocAmount % 100 <> 0 THEN FORMAT(mi.DocAmount/100,'0.00') + '%'
						ELSE CONCAT(CONVERT(INT,mi.DocAmount/100),'%')
				END  [DiscountPercent]
			   ,mi.DiscountAmt * po.DocCurrencyRate	DiscountAmt
			   ,mi.DocAmount * po.DocCurrencyRate LineAmt 
			 ,st.Amount * po.DocCurrencyRate SubTotal
			 ,mi.MiQty,mi.MiAmount * po.DocCurrencyRate MiAmount ,mi.MiUnitPrice * po.DocCurrencyRate MiUnitPrice
			 ,mi.DestinationCode, mi.DestinationName
			   ,cd.Description DocStatus
			 ,CASE WHEN @GroupByForm1 = 4 OR @GroupByForm2 = 4 THEN 2 
				   WHEN @GroupByForm1 = 5 OR @GroupByForm2 = 5 THEN 3 
				   ELSE 1 END FormTag
				   ,dp2.CreateTimeStamp [DateApprove]
				   ,ISNULL(dc.Amount,0) SpecialDiscount
				   ,mls.Location
                   ,ItemVat.TaxAmount [ItemVat], IIF(pol.LineNumber = 1,POVat.TaxAmount,0)POVat
                --    ,CASE WHEN POVat.SystemCategoryId = 123 THEN 'Exc'
                --             WHEN POVat.SystemCategoryId = 129 THEN 'Inc'
                --             WHEN POVat.SystemCategoryId = 131 THEN 'NoVat'
                --     END TypeVat
					, POVat.SystemCategoryId TypeVatId,POVat.SystemCategory TypeVat
				   

	FROM	   
	#Temp_mi mi
	LEFT JOIN dbo.POLines pol WITH (NOLOCK) ON pol.Id = mi.DocLineId AND mi.DocId = pol.POId
	LEFT JOIN dbo.POes po WITH (NOLOCK) ON po.Id = pol.POId
	OUTER APPLY (select dbo.GROUP_CONCAT_D(distinct ml.DestinationCode,', ') Location from Milestones ml where ml.DocId = po.Id and ml.DocTypeId = 22 and ml.DocLineId = pol.Id) mls
	LEFT JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = po.DocStatus
	LEFT JOIN dbo.POLines du WITH (NOLOCK) ON du.SystemCategoryId IN (46,47) AND du.POId = po.Id
	LEFT JOIN dbo.POLines st WITH (NOLOCK) ON st.SystemCategoryId = 107 AND st.POId = po.Id
	LEFT JOIN dbo.POLines dc WITH (NOLOCK) ON dc.SystemCategoryId = 124 AND dc.POId = po.Id
	LEFT JOIN POLines ItemVat ON mi.DocLineId = ItemVat.Id AND ItemVat.SystemCategoryId IN (99,100)
    LEFT JOIN POLines POVat ON mi.DocId = POVat.POId AND POVat.SystemCategoryId IN (123,129,131)
	LEFT JOIN 
	(
		SELECT dl.DocId,apl.Action,apl.CreateTimeStamp 
		FROM dbo.DocLineOfApproves dl 
		INNER JOIN 
		dbo.ApproveDetailLogs apl 
		ON dl.Id = apl.DocLineOfApproveId 
		AND apl.Action = 'Done'
		AND dl.DocTypeId = 22
	) dp2 ON po.Id = dp2.DocId
) t
where ( @filterItem is null or (t.ItemName Like @filterItem))
option(recompile)

END


/************************************* Filter *******************************************/

SELECT 
@code DocCode,
IIF(@OrganizationId IS NOT NULL,(SELECT	Code FROM	dbo.Organizations WHERE Id = @OrganizationId),NULL) OrgCode
         , CONCAT('Document between  ',FORMAT(@DocFromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@DocToDate,'dd/MM/yyyy')) Date1
        , case when isnull(@DueFromDate,'') !='' then CONCAT('Delivery between  ',FORMAT(@DueFromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@DueToDate,'dd/MM/yyyy'))
		 else  'Delivery between and ' end as Date2
         ,CONCAT('GROUP BY ',CASE WHEN @GroupByForm1 = 1 THEN 'DOCUMENT'				
					                   WHEN @GroupByForm1 = 2 THEN 'PROJECT'
					                   WHEN @GroupByForm1 = 3 THEN 'SUPPLIER'
					                   WHEN @GroupByForm1 = 4 THEN 'ITEM'
                                  WHEN @GroupByForm1 = 5 THEN 'DELIVERY'
					                   ELSE 'DOCUMENT' END,' ',CASE WHEN @GroupByForm1 IN (2,3) AND @GroupByForm2 = 1 THEN 'AND DOCUMENT'				
					                                                WHEN @GroupByForm2 = 2 THEN 'AND PROJECT'
					                                                WHEN @GroupByForm2 = 3 THEN 'AND SUPPLIER'
					                                                WHEN @GroupByForm2 = 4 THEN 'AND ITEM'
                                                               WHEN @GroupByForm2 = 5 THEN 'AND DELIVERY'
					                                                ELSE '' END) ReportName
         ,IIF (@Canceled = 1 , 'YES' ,'NO') IncludeCancel 
		   ,IIF (@NotTHB = 1 , 'YES' ,'NO') NotShowTHB 
		   ,IIF (@GroupByCurrency = 1 , 'YES' ,'NO') GroupByCurrency
		   ,@SupplierTag [SupplierTag]
		   ,IIF (@ShowRemark = 1 , 'YES' ,'NO') ShowRemark
/************************ Temp HeadName Org *******************************************/

SELECT * FROM fn_CompanyInfoTable(@OrganizationId)