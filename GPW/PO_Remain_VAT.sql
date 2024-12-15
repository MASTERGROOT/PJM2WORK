/*==> Ref:d:\programmanee\pjm-printing\content\printing\reportcommands\gpw_poremaindetailreport_revise.sql ==>*/
 
/* Edit By Bank เอง เพิ่มเรื่อง Roles เข้ามา */
/* 2020-09-01 Edit By Bank เอง  : ปรับเพิ่มเรื่อง Currency Rate ต่างประเทศมา */
/* 2020-11-03 Edit by Sornthep : แก้เรื่อง UnitConversionView join แล้วเบิ้ล ให้มันไป group ที่ subquery ก่อน ในตัวที่หา clramount */
/* 2020-11-30 Edit By Bank เอง : ปรับเรื่องเอา Status ของ AdjustPoes ที่เป็น cancel ออก */
/* 2021-07-14 : Pichet : Fix Performance add tmpUnitConversion */
/* 2021-10-06 : Edit By Bank เอง : MS-21755 แก้เรื่องสิทธิ์ใหม่ให้เห็นแม่ลูกได้ (ปรับไปใช้ Table ใหม่ของพี่ปุ้ย) */
/* 2021-10-11 : Edit By Bank เอง : แก้เรื่องสิทธิ์เพิ่มเติมกรณี GOD ไม่ได้วางสิทธิ์ไว้เลย มันก็ควรจะทะลุ แต่ตอนนี้รายงานไม่มีค่า */
/* 2022-02-09 : Pichet : Fix Performance add READ UNCOMMITTED */
/* 2023-02-22 : Pichet : Fix Performance */

-- DECLARE @p0 DATE = '2024-12-01'; --@FromDate
-- DECLARE @p1 DATE = '2024-12-31'; --@ToDate
-- DECLARE @p2 DATE = '2024-12-10'; --@AsOfDate
-- DECLARE @p3 INT = null; --@OrganizationId
-- DECLARE @p4 BIT = 0; --@IncChild 
-- DECLARE @p5 INT = NULL;--@SupplierId
-- DECLARE @p6 NVARCHAR(100) = 'GPW-POX2412-00003'/* NULL */--'PO-2208-0681'--'CCFSC-64010002'--'PO63010129' --'PA235-62050004'; --@DocCode
-- DECLARE @p7 NVARCHAR(100) = ''; --@docstatus
-- DECLARE @p8 NVARCHAR(200) = NULL; --@categoryId
-- DECLARE @p9 NVARCHAR(200) = NULL; --@ItemmetaId
-- DECLARE @p10 NVARCHAR(200)= NULL; --@CreateBy
-- DECLARE @p11 INT = 1 --@GroupBy
-- DECLARE @p12 BIT = 0 --@GroupByCurrency
-- DECLARE @p13 NVARCHAR(100) = 'Remain only'; --@Specific
-- DECLARE @p14 BIT = 0; --@Expand

DECLARE @FromDate DATE = @p0;
DECLARE @ToDate DATE = @p1;
DECLARE @AsOfDate DATE = @p2;
DECLARE @OrganizationId INT = @p3
DECLARE @IncChild BIT = nullif(@p4,'');
DECLARE @SupplierId INT = @p5
DECLARE @DocCode NVARCHAR(200)= nullif(@p6,'');
DECLARE @docstatus NVARCHAR(200)= nullif(@p7,'');
DECLARE @categoryId INT = @p8
DECLARE @ItemmetaId INT = @p9
DECLARE @CreateBy NVARCHAR(200) = nullif(@p10,'');
DECLARE @GroupBy INT = @p11
DECLARE @GroupByCurrency BIT = nullif(@p12,'');
DECLARE @Specific NVARCHAR(100)= @p13
DECLARE @Expand BIT = nullif(@p14,'');

DECLARE @query NVARCHAR(MAX) = ''
DECLARE @Cat TABLE (Id INT)
DECLARE @CatId NVARCHAR(MAX) = ''
DECLARE @Config NVARCHAR(MAX)	= (SELECT Value FROM	dbo.CompanyConfigs with (nolock) WHERE ConfigName = 'HostUrl')


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF(@AsOfDate = '1900-01-01')
BEGIN
SELECT @AsOfDate = GETDATE()
END

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

/**********************TempRoleSubdoctype*************************/
DECLARE @DoctypeList NVARCHAR(MAX) = '22,23,130'; 
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

/**********************TempRoleSubdoctype*************************/


IF OBJECT_ID(N'tempdb..#tmpUnitConversion') IS NOT NULL
BEGIN
    DROP TABLE #tmpUnitConversion;
END;

create TABLE #tmpUnitConversion
(
 ItemMetaId INT,     
 UnitId INT,    
 NameOfUnit   NVARCHAR(500),    
 Quantity	int,
 ConversionFactor FLOAT
)

create clustered index ix_tmpUnitConversion on #tmpUnitConversion (ItemMetaId,UnitId)

insert into #tmpUnitConversion
(
	ItemMetaId,UnitId,NameOfUnit, Quantity, ConversionFactor
)
select d.ItemMetaId,d.UnitId,d.NameOfUnit, d.Quantity, d.ConversionFactor
from UnitConversionView d
where isnull(ItemMetaId,0) <> 0
GROUP BY d.ItemMetaId,d.UnitId,d.NameOfUnit, d.Quantity, d.ConversionFactor
option(recompile)

/*=============================================================*/
SELECT a.*,IIF(a.TypeVatId = 123, a.Total + a.POVat,a.Total) TotalPlusVat
FROM(select  
DocId
		,DocCode
		,DocDate
		,b.LineNumber
		,b.ExtOrgId
		,b.ExtOrgCode
		,b.ExtOrgName
		,LocationId
		,LocationCode
		,LocationName
		,ItemCode
		,ItemName
		,SAmount
		,case when clearmethod = 1  and samount =0 then 0
		when clearmethod = 1 then 1
		 else QTY end as QTY
		,UnitName
		,ClrAmount
		,case when clearmethod = 1 and isnull(ClrQTY,0) !=0 then 1
		else ClrQTY end as ClrQTY
		,ClearMethod
		,ClearMethodName
		,GroupCode_0
        ,GroupCode_1
		,GroupName_1
		,dbo.SitePath(b.DocTypeId,b.DocId) Path
		,DeliveryDuedate
		,rep.Remarks
		,RemainAmount
		,CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
			  WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
			  WHEN ClearMethod = 0 THEN ReaminQTY
			  ELSE NULL END ReaminQTY
		, case when @Specific = 'All' then IIF(b.ROW# = 1,SUM(b.SAmount) OVER (PARTITION BY b.DocId) - b.PO_SpecialDiscount,0) 
		else IIF(b.ROW# = 1,SUM(b.SAmount) OVER (PARTITION BY b.DocId)-  b.PO_SpecialDiscount+ sum(isnull(rsl.amount * rs.DocCurrencyRate,0))  ,0)  end as Total
		
		,case when @Specific = 'All' then IIF(b.ROW# = 1,ISNULL(SUM(b.ClrAmount) OVER (PARTITION BY b.DocId),0) - sum(isnull(rsl.amount * rs.DocCurrencyRate,0)),0)
		else IIF(b.ROW# = 1,ISNULL(SUM(b.ClrAmount) OVER (PARTITION BY b.DocId),0),0) end as ReceiveAmt

		,IIF(b.ROW# = 1,(SUM(b.SAmount) OVER (PARTITION BY b.DocId) - (b.PO_SpecialDiscount - SUM(ISNULL(bcrl.sumCrl_specialdiscount,0)))) - (ISNULL(SUM(b.ClrAmount) OVER (PARTITION BY b.DocId),0) - sum(isnull(rsl.amount * rs.DocCurrencyRate,0))),0)

		 Remain
		, IIF(b.ROW# = 1,b.PO_SpecialDiscount,0) PO_SpecialDiscount
		, IIF(b.ROW# = 1,sum(isnull(rsl.amount * rs.DocCurrencyRate,0)),0) RS_SpecialDiscount
        , IIF(b.PO_SpecialDiscount != 0,1,0) Disc_PO
        ,b.ItemVat*ISNULL(rs.DocCurrencyRate,1) ItemVat,IIF(b.ROW# = 1,b.POVat*ISNULL(rs.DocCurrencyRate,1),0) POVat
		,b.TypeVatId,b.TypeVat
        , @Expand Expand
		,cd.Description DocStatus
		,@Specific specific
		
from 
		(

		select	ROW_NUMBER() OVER (PARTITION BY bs.DocId ORDER BY bs.DocId,bs.LineNumber) ROW#
						,bs.LineNumber
						,bs.DocId [DocId]
						,bs.DocCode [DocCode]
						,bs.DocDate [DocDate]
						,bs.DocTypeId [DocTypeId]
						,bs.DocType [DocType]
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
						,IIF(bs.DocCurrency = 'THB',NULL,round((round(isnull(bs.Amount,0),2))*isnull(bs.DocCurrencyRate,1),2)) CurrAmount
						,round((round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0))*isnull(bs.DocCurrencyRate,1),2) [SAmount]
						,isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0) [QTY]
						,bs.DocUnitName [UnitName]
						,round(isnull(Clr.ClrAmount,0)*isnull(bs.DocCurrencyRate,1),2) ClrAmount
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
						,round((round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0))*isnull(bs.DocCurrencyRate,1),2) RemainAmount
						,isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0) - ISNULL(Clr.ClrQTY,0) ReaminQTY
						,doc.DocStatus
						,IIF(round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) > 0,
										CASE WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) = 0 THEN 0
										WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) != 0 THEN 5
										WHEN ClearMethod = 0 THEN IIF(isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0) - ISNULL(Clr.ClrQTY,0) > 0, 6, 0)
										ELSE NULL END,0) DocStatusNew
						,round(bs.PO_SpecialDiscount*isnull(bs.DocCurrencyRate,1),2) PO_SpecialDiscount

						,DeliveryDuedate
						,line.TaxAmount [ItemVat]
						,bs.POVat,bs.TypeVatId,bs.TypeVat
				from (
						select bs.DocId,bs.DocCode,bs.DocTypeId
								,p.LineNumber
								,bs.ExtOrgId,bs.ExtOrgCode,bs.ExtOrgName
								,bs.LocationId,bs.LocationCode,bs.LocationName
								,bs.ItemMetaCode,bs.ItemCategoryCode ,bs.Description,bs.ItemCategoryName,bs.ItemMetaName,bs.DocCurrency,bs.DocCurrencyRate,sum(bs.Amount)[Amount]
								,sum(bs.CountQty)[CountQty]
								,sum(bs.DocQty)[DocQty],bs.CountUnitName
								,bs.DocUnitName,bs.ClearMethod,bs.ClearMethodName
								,bs.DocLineId,bs.AdjDocId,bs.DocDate,bs.ItemMetaId
								,bs.ItemCategoryId
								,ISNULL(dc.Amount,0) PO_SpecialDiscount
								,dbo.GROUP_CONCAT_D(FORMAT(bs.duedate,'dd/MM/yy'),' , ')DeliveryDuedate
								,bs.Doctype,POVat.TaxAmount [POVat],POVat.SystemCategoryId [TypeVatId], POVat.SystemCategory [TypeVat]
							
						from BookedStockElementSets bs WITH (NOLOCK,forceseek) 
						INNER loop JOIN dbo.POLines p WITH (NOLOCK,forceseek) ON p.id = bs.DocLineId AND bs.DocTypeId =22
						LEFT loop JOIN dbo.POLines dc WITH (NOLOCK,forceseek) ON dc.SystemCategoryId = 124 AND bs.DocId = dc.POId	
						LEFT loop JOIN dbo.POLines POVat WITH (NOLOCK,forceseek) ON POVat.SystemCategoryId IN (123,129,131) AND bs.DocId = POVat.POId	

						WHERE bs.DocTypeId = 22 AND bs.AdjDocId IS NULL
						AND bs.BookedStockState IN (20,21)
						AND CONVERT(date,bs.DocDate) between @FromDate and @ToDate
						AND ((bs.ItemMetaId IN (SELECT ncode FROM dbo.fn_listCode(@ItemmetaId))) OR ISNULL(@ItemmetaId,'') = '')
						AND ((bs.ItemCategoryId IN (SELECT ncode FROM dbo.fn_listCode(@CatId))) OR ISNULL(@categoryId,'') = '')
						AND ((bs.DocCode LIKE '%'+@DocCode+'%') OR @DocCode IS NULL)
						AND ((bs.ExtOrgId = @SupplierId) OR @SupplierId IS NULL)
						AND ((EXISTS (SELECT 1 FROM @Org ot WHERE ot.Id = bs.LocationId)) OR @OrganizationId IS NULL)		
						group by bs.DocId,bs.DocCode,bs.DocTypeId,bs.ExtOrgId,bs.ExtOrgCode,bs.ExtOrgName
						,bs.LocationId,bs.LocationCode,bs.LocationName,bs.ItemMetaCode,bs.ItemCategoryCode ,bs.Description,bs.ItemCategoryName,bs.ItemMetaName,bs.DocCurrency,bs.DocCurrencyRate
						,bs.CountUnitName,bs.DocUnitName,bs.ClearMethod,bs.ClearMethodName,bs.DocLineId,bs.AdjDocId,bs.DocDate,bs.ItemMetaId,bs.ItemCategoryId,ISNULL(dc.Amount,0)
						,p.LineNumber,bs.Doctype,POVat.TaxAmount,POVat.SystemCategoryId,POVat.SystemCategory
						) bs 

				left loop JOIN POes doc WITH (NOLOCK) on bs.DocId = doc.Id and bs.DocTypeId = 22
				LEFT loop JOIN dbo.POLines line WITH (NOLOCK) ON bs.DocLineId = line.Id
				

				outer apply ( SELECT ajpol.POId [POId]	
									,ajpol.POLineId [POLineId]	
									,SUM(ajpol.AdjustQty) AdjustQty	
									,SUM(ajpol.AdjustAmount) AdjustAmount
									,ajpol.TaxAmount [AdjustItemVat]	
							FROM dbo.AdjustPOLines ajpol WITH (NOLOCK,forceseek)	
							LEFT JOIN dbo.AdjustPOes ajpo WITH (NOLOCK,forceseek) ON ajpol.AdjustPOId = ajpo.Id	
							WHERE 
								doc.Id = ajpol.POId 
							AND line.Id = ajpol.POLineId
							AND ajpo.DocStatus NOT IN (-1)	
							AND isnull(ajpo.date,'') <= @AsOfDate
							GROUP BY ajpol.POId,POLineId,ajpol.TaxAmount
				) adjPO /*ON doc.Id = adjPO.POId AND line.Id = adjPO.POLineId*/

				outer apply (
							select bc.RefDocId,bc.RefDocLineId,round(sum(isnull(bc.Amount,0)),2) ClrAmount
							,sum((isnull(convert(decimal(29,12), d.ConversionFactor),1) / isnull(convert(decimal(29,12), c.ConversionFactor),1)) * isnull(bc.DocQty,1)) ClrQTY

							from BookedStockElementClears bc WITH (NOLOCK,forceseek)

							LEFT JOIN dbo.POLines pol WITH (NOLOCK) ON bc.RefTypeId = 22 AND bc.RefDocLineId = pol.Id

							outer apply
							(
								select d.ItemMetaId,d.UnitId,d.NameOfUnit, d.Quantity,d.ConversionFactor 
								from #tmpUnitConversion d
								where
								bc.ItemMetaId = d.ItemMetaId 
								and bc.DocUnitId = d.UnitId 
								and((bc.DocUnitName = d.NameOfUnit and d.Quantity >= 100) or (d.Quantity < 100)) 
								and d.ItemMetaId != 0
								GROUP BY d.ItemMetaId,d.UnitId,d.NameOfUnit, d.Quantity, d.ConversionFactor
							) d

							outer apply
							(
								select c.ItemMetaId,c.UnitId,c.NameOfUnit, c.Quantity,c.ConversionFactor 
								from #tmpUnitConversion c
								where
								pol.ItemMetaId = c.ItemMetaId 
								AND pol.DocUnitId = c.UnitId 
								AND ((pol.DocUnitName = c.NameOfUnit and c.Quantity >= 100) or (c.Quantity < 100)) 
								and c.ItemMetaId != 0
								GROUP BY c.ItemMetaId,c.UnitId,c.NameOfUnit, c.Quantity, c.ConversionFactor
							) c


							where 
							bs.DocId = bc.RefDocId AND bs.DocLineId = bc.RefDocLineId
							AND DocTypeId = 130 
							AND (NULLIF(@AsOfDate,'1900-01-01') IS NULL OR CONVERT(date,ClearDate) <= @AsOfDate) 
							group BY bc.RefDocId,bc.RefDocLineId,bc.RefDocType

				) Clr /*on bs.DocId = Clr.RefDocId AND bs.DocLineId = Clr.RefDocLineId */

				where ((doc.CreateBy = @CreateBy) OR ISNULL(@CreateBy,'') = '') 
					and (( @Specific='All') OR
							( @Specific='Remain only' 
							AND (IIF( doc.DocStatus = -3, 
																IIF(round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) > 0,CASE WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) = 0 THEN 0
										WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) != 0 THEN isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0)
										WHEN ClearMethod = 0 THEN isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0) - ISNULL(Clr.ClrQTY,0)
										ELSE NULL END,0),
										CASE WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) = 0 THEN 0
										WHEN ClearMethod = 1 AND round(isnull(bs.Amount,0),2) + ISNULL(adjPO.AdjustAmount,0) - ISNULL(Clr.ClrAmount,0) != 0 THEN isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0)
										WHEN ClearMethod = 0 THEN isnull(bs.DocQty,0) + ISNULL(adjPO.AdjustQty,0) - ISNULL(Clr.ClrQTY,0)
										ELSE NULL END)) <> 0 ))
							AND ((exists (SELECT 1 FROM #TempRoleSubdoctype rsd WHERE (rsd.AllSubDocType = 1 OR rsd.SubDocTypeId = doc.SubDocTypeId ) AND (rsd.AllOrg = 1 OR bs.LocationId = rsd.OrgId))) OR @isPowerUser = 1)
		)b
		LEFT JOIN (select code cp,remarks from  Poes )rep ON rep.cp = b.DocCode
		LEFT loop join ReceiveSuppliers rs WITH (NOLOCK,forceseek) on rs.RefDocId = docid and rs.DocStatus !=-1
		LEFT loop join ReceiveSupplierLines rsl WITH (NOLOCK,forceseek) on rs.id = rsl.ReceiveSupplierId and rsl.SystemCategoryId = 124
		outer apply 
		(
			SELECT bcrl.RefDocId,bcrl.RefDocType,bcrl.DocTypeId, SUM(ISNULL(bcrl.SpecialDiscount,0)) sumCrl_specialdiscount 
			FROM dbo.BookedStockElementClears bcrl
			WHERE 
			bcrl.RefDocId = b.DocId  and bcrl.DocTypeId = 23 AND bcrl.RefDocType = b.DocType
			GROUP BY bcrl.RefDocId,bcrl.RefDocType,bcrl.DocTypeId
		)bcrl /*on bcrl.RefDocId = b.DocId  and bcrl.DocTypeId = 23 AND bcrl.RefDocType = b.DocType*/
		LEFT JOIN CodeDescriptions cd on cd.[Value] = b.DocStatus AND name = 'DocStatus'
		where (( @Specific='All') OR
					( @Specific='Remain only' 
					AND (IIF( b.DocStatusNew = -3, 0,
								CASE WHEN ClearMethod = 1 AND RemainAmount = 0 THEN 0
								WHEN ClearMethod = 1 AND RemainAmount != 0 THEN QTY
								WHEN ClearMethod = 0 THEN ReaminQTY
								ELSE NULL END)) <> 0 ))
					AND (b.docstatus IN (select *FROM dbo.fn_listCode(@docstatus)) OR @docstatus IS NULL )

		group by DocId
				,DocCode
				,DocDate
				,b.LineNumber

				,b.ExtOrgId
				,b.ExtOrgCode
				,b.ExtOrgName
				,LocationId
				,LocationCode
				,LocationName
				,ItemCode
				,ItemName
				,SAmount
				,QTY
				,UnitName
				,ClrAmount
				,ClrQTY
				,ClearMethod
				,ClearMethodName
				,GroupCode_0
				,GroupCode_1
				,GroupName_1
				,RemainAmount
				,b.doctypeid
				,b.reaminqty
				,b.ROW#
				,b.PO_SpecialDiscount
				,cd.Description
				,DeliveryDuedate,rep.Remarks,b.ItemVat,b.POVat,b.TypeVatId,b.TypeVat,rs.DocCurrencyRate
) a
option(recompile)



SELECT 
		 CONCAT('Document between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy')) Filterdate
		 ,IIF(NULLIF(@AsOfDate,'1900-01-01') IS NULL,NULL, 'As of date                 ' + FORMAT(@AsOfDate,'dd/MM/yyyy')) AsOfDate
		 ,IIF(@OrganizationId IS NOT NULL,(SELECT Code  FROM	dbo.Organizations WHERE Id = @OrganizationId),NULL) OrgCode
		 ,CASE WHEN @IncChild =1 THEN 'YES'ELSE 'NO'END IncChild
		 ,@DocCode PRCode
		 ,IIF(@categoryId IS NOT NULL,(SELECT ic.Code itemname FROM	dbo.ItemCategories ic WHERE ic.Id = @categoryId),NULL) ItemCategory
		 ,IIF(@ItemmetaId IS NOT NULL,(SELECT im.Code Itemmeta FROM	dbo.ItemMetas im WHERE im.Id = @ItemmetaId),NULL) Itemmeta
		 ,@CreateBy CreateBy 
         ,CASE WHEN @GroupBy = 1 THEN 'PROJECT'				
					                   WHEN @GroupBy = 2 THEN 'SUPPLIER'
					                   ELSE 'DOCUMENT' END
		  ReportName
		 ,IIF (@GroupByCurrency = 1 , 'YES' ,'NO') GroupByCurrency
		 ,@Specific Specific 
		 ,IIF (@Expand = 1 , 'YES' ,'NO') Expand

SET TRANSACTION ISOLATION LEVEL READ COMMITTED


/*3-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM fn_CompanyInfoTable(@OrganizationId)