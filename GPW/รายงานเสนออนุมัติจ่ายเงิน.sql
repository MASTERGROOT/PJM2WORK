/*==> Ref:d:\programmanee\pjm-printing\content\printing\reportcommands\ap_aplistreport_revise.sql ==>*/
 
/*==> Ref:d:\programmanee\pjm-printing\content\printing\reportcommands\ap_aplistreport_revise.sql ==>*/
 
/*==> Ref:d:\pjm2\pojjaman\content\printing\reportcommands\ap_aplistreport_revise.sql ==>*/
 
/*==> Ref:d:\pjm2\pojjaman\content\printing\reportcommands\ap_aplistreport_revise.sql ==>*/
 
/*Last Edited : 2019-07-24*/
/*Last Editor : Pichet*/
 
/*	

	AP_APListReport_revise 
	
	Create By Phollapat @15/06/2019
	
	*** Core of query : dbo.Journals.JournalTypeId = 1

*/

/* 2022-06-13 : Edit By แบงค์เอง : MS-24406 เคสที่เอกสารเป็น MultiVat แล้วทำให้รายการในรายงานแสดงเบิ้ล */


declare @p0  int				= 2
DECLARE @p1  date				= '2024-10-01';
DECLARE @p2  date				= '2024-10-30';

declare @p3  nvarchar(max)		=	NULL;
DECLARE @p4  nvarchar(max)		=	/* '36' */NULL;
DECLARE @p5  bit				= 1;
DECLARE @p6  nvarchar(max)		=	null;

declare @p7  nvarchar(max)		=	null;
DECLARE @p8  nvarchar(max)		=	null;
DECLARE @p9  nvarchar(max)		=  null;

declare @p10 NVARCHAR(max)		=	null;
DECLARE @p11 nvarchar(max)		= null;
DECLARE @p12 nvarchar(max)		= null;


DECLARE @p13 NVARCHAR(MAX)		= NULL;
DECLARE @p14 NVARCHAR(MAX)		= NULL; 
DECLARE @p15 NVARCHAR(MAX)		= NULL;
DECLARE @p16 NVARCHAR(MAX)		= 'ALL';
DECLARE @p17 NVARCHAR(MAX)		= 'Document Date';
DECLARE @p18 bit							= 0;
DECLARE @p19 bit							= 1;



declare @Select int						= @p0;	       /* 1:DocDate,2:DueDate,3:CreateDate */ 
declare @FromDate date					= @p1;			
declare @ToDate date					= @p2;
DECLARE @Account NVARCHAR(MAX)			= @p3;
declare @projectId NVARCHAR(max)		= @p4;
DECLARE @IncChild BIT					= @p5;
DECLARE @NotProject NVARCHAR(MAX)		= @p6;
DECLARE @ExtOrg NVARCHAR(max)			= @p7;
DECLARE @SupplierTag NVARCHAR(MAX)		= @p8;
declare @Code nvarchar(MAX)				= @p9;
declare @Amount nvarchar(MAX)			= @p10;
declare @Status NVARCHAR(MAX)			= @p11;
DECLARE @DoctypeId NVARCHAR(MAX)		= @p12;
DECLARE @SubDocTypeId NVARCHAR(MAX)		= @p13;
DECLARE @Vat NVARCHAR(MAX)			    = @p14;           /* 1:ExcVat,2:IncVat,3:NoVat,4:ZeroVat,5:ExemptVat */
DECLARE @Currency NVARCHAR(MAX)			= @p15;
declare @NonPO nvarchar(MAX)			= @p16;	          /*ALL,PO,NON PO*/
DECLARE @Orderby nvarchar(MAX)			= @p17;			  /*Document Date,Document No.,GL No.*/
DECLARE @IncludeCancel BIT				= @p18;
DECLARE @GroupCurrency BIT				= @p19;


DECLARE @NewLine CHAR(2) = CHAR(13) + CHAR(10)
DECLARE @ga NVARCHAR(max) = ''

        
        SELECT @ga += CONCAT(EnumKey,',') FROM dbo.GeneralAccountEntities WHERE Module = 'AP'

/******************** Save More SupplierId ,Who SupplierTagJSON Like TagName to Temp. *****************************/

DECLARE @SupplierTagId TABLE (Id INT)
DECLARE @query2 NVARCHAR(MAX) = ''

SELECT	@query2 +=	'SELECT  Id  FROM dbo.ExtOrganizations  WHERE SupplierTagJSON LIKE ''%'+TagName+'%'''+';'
FROM		dbo.TagTypeItems  WITH (NOLOCK)
WHERE		TagName IN (SELECT ncode FROM dbo.fn_listCode(@SupplierTag))

INSERT INTO @SupplierTagId(Id)

EXECUTE (@query2);


/**************************** Save More OrgId Or Single OrgId Not Include Child to Temp. ******************************/

DECLARE @OrgId TABLE (Id int)	 /*Save OrgId to Temp.*/
INSERT INTO @Orgid(Id)

SELECT	o.Id
FROM		dbo.Organizations o WITH (NOLOCK)
WHERE		EXISTS (
						SELECT	1
						FROM		dbo.Organizations pj WITH (NOLOCK)
						WHERE		pj.Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId)) 
									AND ((@IncChild = 1 AND o.Path LIKE pj.Path +'%')
											OR (@IncChild = 0 AND o.Id = pj.Id)
												)
			)

OPTION (RECOMPILE)
/*************************************************************************************************************/

IF OBJECT_ID(N'tempdb..#cte_JV', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #cte_JV;
END;

/*
				; with cte_JV AS
(
*/

				SELECT	 
						/*
						row_number() over (order by (case when @Orderby = 'Document No.' then j.MadeByDocCode 
                                          when @Orderby = 'GL No.' then j.Code 
                                          ELSE format(j.MadeByDocDate,'yy/MM/dd') end)) #No
						, 
						*/

						j.Id JVId, j.Code JVCode, convert(date,j.Date) JVDate
						, da.LocationCode OrgCode, da.LocationName OrgName
						, j.ExtOrgCode, j.ExtOrgName
										, j.MadeByDocId DocId, j.MadeByDocCode DocCode, j.MadeByTypeId DocTypeId,j.MadeByDocDate, j.MadeByDocCode
						, da.InvoiceAPCode
						, da.InvoiceAPDate
						, po.POCode
						, da.FiscalDueDate DueDate
						, ap.AccountCode AccountCode
						, da.TaxAmount VatAmt, ap.APAmt
						, da.DocCurrency,da.DocCurrencyRate
						into #cte_JV
				from  dbo.JournalVouchers j WITH (NOLOCK)
						inner join dbo.Journals jn WITH (NOLOCK) on jn.Id = j.JournalId and jn.JournalTypeId IN (1,8) and j.MadeByTypeId <> 140
						CROSS APPLY ( 							   
									  SELECT  a1.LocationId, a1.LocationCode, a1.LocationName
											  , ISNULL(NULLIF(a1.InvoiceAPCode,''),a1.TaxInvoiceAPCode) InvoiceAPCode
											  , ISNULL(NULLIF(a1.InvoiceAPDate,''),a1.TaxInvoiceAPDate) InvoiceAPDate
											  , CONVERT(date,du.FiscalDueDate)FiscalDueDate
											  , ISNULL(a1.DocCurrency,'THB') DocCurrency, ISNULL(a1.DocCurrencyRate,1) DocCurrencyRate
											  , ISNULL(vt.SystemCategoryId,0) SystemCategoryId, ISNULL(vt.TaxAmount,0)TaxAmount
									  FROM	  dbo.Invoices a1 WITH (NOLOCK)
											  LEFT JOIN dbo.InvoiceLines du WITH (NOLOCK) ON du.InvoiceId = a1.Id AND du.SystemCategoryId IN (46,47)
											  LEFT JOIN (
												SELECT 
													SystemCategoryId,InvoiceId,SUM(ISNULL(TaxAmount,0)) [TaxAmount]
												FROM dbo.InvoiceLines 
												WHERE SystemCategoryId IN (123,129,199,207) 
												GROUP BY SystemCategoryId,InvoiceId
											  ) vt ON vt.InvoiceId = a1.Id
									  WHERE	  a1.Id = j.MadebyDocId 
											  AND j.MadeByTypeId in (37,213)
										

						 UNION ALL
									  SELECT  a2.LocationId, a2.LocationCode, a2.LocationName
											  , ISNULL(NULLIF(a2.InvoiceAPCode,''),a2.TaxInvoiceAPCode) InvoiceAPCode
											  , ISNULL(NULLIF(a2.InvoiceAPDate,''),a2.TaxInvoiceAPDate) InvoiceAPDate
											  , CONVERT(date,du.FiscalDueDate)FiscalDueDate
											  , ISNULL(a2.DocCurrency,'THB') DocCurrency, ISNULL(a2.DocCurrencyRate,1) DocCurrencyRate
											  , ISNULL(vt.SystemCategoryId,0) SystemCategoryId, ISNULL(vt.TaxAmount,0)TaxAmount 
									  FROM	  dbo.OtherPayments a2 WITH (NOLOCK)
											  LEFT JOIN dbo.OtherPaymentLines du WITH (NOLOCK) ON du.OtherPaymentId = a2.Id AND du.SystemCategoryId IN (46,47)
											  LEFT JOIN (
													SELECT 
														SystemCategoryId,OtherPaymentId,SUM(ISNULL(TaxAmount,0)) [TaxAmount]
													FROM dbo.OtherPaymentLines 
													WHERE SystemCategoryId IN (123,129,199,207) 
													GROUP BY SystemCategoryId,OtherPaymentId
												) vt ON vt.OtherPaymentId = a2.Id
									  WHERE	  a2.Id = j.MadeByDocId
											  AND j.MadeByTypeId = 43

											 
						UNION ALL
									  SELECT  a3.LocationId, a3.LocationCode, a3.LocationName
											  , ISNULL(NULLIF(a3.InvoiceAPCode,''),a3.TaxInvoiceAPCode) InvoiceAPCode
											  , ISNULL(NULLIF(a3.InvoiceAPDate,''),a3.TaxInvoiceAPDate) InvoiceAPDate
											  , CONVERT(date,du.FiscalDueDate)FiscalDueDate
											  , ISNULL(a3.DocCurrency,'THB') DocCurrency, ISNULL(a3.DocCurrencyRate,1) DocCurrencyRate
											  , ISNULL(vt.SystemCategoryId,0) SystemCategoryId, ISNULL(IIF(a3.DocTypeId = 39,vt.AdjustTaxAmount * -1,vt.AdjustTaxAmount),0)TaxAmount 
									  FROM	  dbo.AdjustInvoices a3 WITH (NOLOCK)
											  LEFT JOIN dbo.AdjustInvoiceLines du WITH (NOLOCK) ON du.AdjustInvoiceId = a3.Id AND du.SystemCategoryId IN (46,47)
											  LEFT JOIN (
												SELECT 
													SystemCategoryId,AdjustInvoiceId,SUM(ISNULL(AdjustTaxAmount,0)) [AdjustTaxAmount]
												FROM dbo.AdjustInvoiceLines 
												WHERE SystemCategoryId IN (123,129,199,207) 
												GROUP BY SystemCategoryId,AdjustInvoiceId
											  ) vt ON vt.AdjustInvoiceId = a3.Id
									  WHERE	  a3.Id = j.MadeByDocId
											  AND j.MadeByTypeId IN (39,40)

											  ) da
						
				                OUTER APPLY (	SELECT sum(IIF(s.isDebit = 1,s.DocLineAmount * -1,s.DocLineAmount)) APAmt, dbo.GROUP_CONCAT(s.AccountCode) [AccountCode]
										FROM    dbo.AcctElementSets s WITH (NOLOCK)
										WHERE	s.DocId = j.MadeByDocId 
												AND s.DocTypeId = j.MadeByTypeId 
												AND s.GeneralAccount IN (SELECT ncode FROM dbo.fn_listCode(@ga))
												AND ((j.MadeByTypeId = 43 AND s.Description = 'ตั้งหนี้') OR j.MadeByTypeId <> 43)
										GROUP BY s.DocId 
												)	ap
						  
						OUTER APPLY (	SELECT  ii.InvoiceId,dbo.GROUP_CONCAT_DS(DISTINCT ii.RefDocCode2,@NewLine,1) POCode 
										FROM    dbo.InvoiceLines ii WITH (NOLOCK)
										WHERE	ISNULL(ii.ItemCategoryId,0) <> 0
												AND ISNULL(ii.RefDocCode2,'') <> ''
												AND j.MadeByDocId = ii.InvoiceId
												AND j.MadeByTypeId IN  (37,213)
												GROUP BY ii.InvoiceId
												) po


						
				WHERE   ISNULL(j.DocStatus,0) NOT IN (-1,-6)
								AND (  (@Select = 1 and CONVERT(DATE,j.Date) between @FromDate and @ToDate)
										or (@Select = 2 and CONVERT(date,da.FiscalDueDate) between @FromDate and @ToDate)
													or (@Select = 3 and CONVERT(DATE,j.CreateTimestamp) between @FromDate and @ToDate)
												) 
								 and ((j.ExtOrgCode in (SELECT ncode FROM dbo.fn_listCode(@ExtOrg))) OR @ExtOrg IS NULL)							
								 and ((EXISTS (select 's_tag' from @SupplierTagId ac WHERE ac.Id = j.ExtOrgId)) OR @SupplierTag IS NULL)					
								 and ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = da.LocationId)) OR @ProjectId is NULL)
								 and ((j.SubDocTypeId IN (select ncode from dbo.fn_listCode(@SubDocTypeId))) OR @SubDocTypeId IS NULL)
								 and ((j.MadeByTypeId IN (select ncode from dbo.fn_listCode(@DocTypeId))) OR @DocTypeId IS NULL)
                         and ((j.DocStatus IN (select ncode from dbo.fn_listCode(@Status))) OR @Status IS NULL)
                         and ((@IncludeCancel = 0 and isnull(j.DocStatus,0) <> -1) or ((@Status like '%-1%') or (@IncludeCancel = 1)))
                         AND (((ap.AccountCode IN (SELECT ncode FROM dbo.fn_listCode(@Account)))) OR @Account IS NULL)
                         AND ((da.DocCurrency IN (SELECT ncode FROM dbo.fn_listCode(@Currency))) OR @Currency IS null)
                         and (  (@Vat Like '%1%' and da.SystemCategoryId = 123)            /* 1: exclude vat */
                                or (@Vat Like '%2%' and da.SystemCategoryId = 129)         /* 2: include vat */
                                  or (@Vat Like '%3%' and da.SystemCategoryId = 0)     /* 3: no vat  */
                                    or (@Vat Like '%4%' and da.SystemCategoryId = 199)     /* 4: zero vat */
                                      or (@Vat Like '%5%' and da.SystemCategoryId = 207)   /* 5: exempt vat */
                                        or @Vat is null
                                        )
                 AND ((ap.APAmt = iif(isnumeric(replace(@Amount,',','')) = 1,convert(money,replace(@Amount,',','')),null)) or @Amount is null)
				 AND (((j.MadeByDocCode Like '%'+@Code+'%') OR (j.Code Like '%'+@Code+'%') OR (po.POCode Like '%'+@Code+'%') OR (da.InvoiceAPCode Like '%'+@Code+'%')) or @Code IS NULL)
				 AND ((@NonPO = 'NON PO' AND po.POCode IS NULL) OR (@NonPO = 'PO' AND po.POCode IS NOT NULL) OR @NonPO = 'ALL')
			option(recompile)
/*
)
*/

select *
from
(
	SELECT 
	/*j.#No,*/
	row_number() over (order by (case when @Orderby = 'Document No.' then j.MadeByDocCode 
						when @Orderby = 'GL No.' then j.JVCode 
						ELSE format(j.MadeByDocDate,'yy/MM/dd') end)) #No
	, 
	j.JVId, j.JVCode, j.JVDate, j.OrgCode, j.OrgName, j.ExtOrgCode, j.ExtOrgName
        , dc.DocTypeCode DocType
        , j.DueDate, j.AccountCode, j.DocCode, j.InvoiceAPCode, j.InvoiceAPDate, j.POCode
        , CONCAT((SELECT sp.SitePath FROM dbo.SitePathList() sp WHERE sp.DocTypeId = j.DocTypeId), j.DocId) SitePathDoc
		, CONCAT((SELECT sp.SitePath FROM dbo.SitePathList() sp WHERE sp.DocTypeId = 64), j.JVId) SitePathJV
		, j.DocCurrency, j.DocCurrencyRate
		
        , ISNULL(j.APAmt,0) - ISNULL(j.VatAmt,0) + ISNULL(vl.DepositAmt,0) + ISNULL(vl.SpecialDiscount,0) DocAmt
        , ISNULL(vl.SpecialDiscount,0) SpecialDiscount
        , ISNULL(j.APAmt * j.DocCurrencyRate,0) - ISNULL(j.VatAmt * j.DocCurrencyRate,0) + ISNULL(vl.DepositAmt * j.DocCurrencyRate,0) CostAmt
        , ISNULL(vl.DepositAmt,0) DepositAmt
        , ISNULL(j.APAmt,0) - ISNULL(j.VatAmt,0) TaxBase
        , ISNULL(j.VatAmt,0) VatAmt
        , ISNULL(j.APAmt,0)	APAmt
        , ISNULL(vl.RetentionAmt,0) RetentionAmt
        , ISNULL(j.APAmt,0) - ISNULL(vl.RetentionAmt,0) NetAmt
		, ISNULL(ti.WHTAmount,0) WHT
        , IIF(@GroupCurrency = 1,j.DocCurrency,'') GroupCurrency
		
        , SUM(ISNULL(j.APAmt* j.DocCurrencyRate,0) - ISNULL(j.VatAmt* j.DocCurrencyRate,0) + ISNULL(vl.DepositAmt* j.DocCurrencyRate ,0) + ISNULL(vl.SpecialDiscount* j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTDocAmt  --เพิ่มเรื่อง * Currency Rate Meen 20/10/2566
        , SUM(ISNULL(vl.SpecialDiscount * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTSpecialDiscount
        , SUM(ISNULL(j.APAmt * j.DocCurrencyRate,0) - ISNULL(j.VatAmt * j.DocCurrencyRate,0) + ISNULL(vl.DepositAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTCostAmt
        , SUM(ISNULL(vl.DepositAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTDepositAmt
        , SUM(ISNULL(j.APAmt * j.DocCurrencyRate,0) - ISNULL(j.VatAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTTaxBase
        , SUM(ISNULL(j.VatAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTVatAmt
        , SUM(ISNULL(j.APAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTAPAmt
        , SUM(ISNULL(vl.RetentionAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTRetentionAmt
        , SUM(ISNULL(j.APAmt * j.DocCurrencyRate,0) - ISNULL(vl.RetentionAmt * j.DocCurrencyRate,0)) OVER (PARTITION BY 'x') GTTNetAmt


	FROM    #cte_JV j
		left hash join dbo.DocTypeCodeList() dc ON dc.DocTypeId = j.DocTypeId
			/*left hash join */
			outer apply
			(

							  SELECT  i.Id DocId/*,jv.DocTypeId*/
                                  ,ISNULL(ds.Amount,0) SpecialDiscount
                                  ,ISNULL(de.DepositAmt,0) DepositAmt
								  ,ISNULL(rt.Amount,0) RetentionAmt

                          FROM	   dbo.Invoices i WITH (NOLOCK)
									   /*inner join #cte_JV jv on jv.DocId = i.Id and jv.DocTypeId in (37,213)*/
                                   left  join dbo.InvoiceLines ds WITH (NOLOCK) on ds.InvoiceId = i.Id and ds.SystemCategoryId = 124
                                   OUTER APPLY (
                                                select	il.InvoiceId,sum(il.Amount)Depositamt
                                                from	dbo.InvoiceLines il WITH (NOLOCK)
                                                where   il.SystemCategoryId = 54
														AND il.InvoiceId = i.Id
                                                        group by il.InvoiceId
														) de
                                   left  join dbo.InvoiceLines rt WITH (NOLOCK) on rt.InvoiceId = i.Id and rt.SystemCategoryId = 48
							 where
							 j.DocTypeId in (37,213)  
							 and
							 j.DocId = i.Id
			) vl /*ON vl.DocId = j.DocId AND vl.DocTypeId = j.DocTypeId*/
			LEFT JOIN (
				SELECT 
					ti.SetDocId
					, ti.SetDocTypeId
					,SUM(DocTaxAmount) WHTAmount
				FROM TaxItems ti
				WHERE ti.SystemCategoryId = 138 --WitholdingTaxPayable
				GROUP BY ti.SetDocId,ti.SetDocTypeId
			)ti ON ti.SetDocId = j.DocId AND ti.SetDocTypeId = j.DocTypeId
) j		  
ORDER BY j.#No
OPTION (recompile)



/*Filter*/
SELECT   iif(@projectId is not null,(SELECT dbo.GROUP_CONCAT_DS(distinct Code,' ,',1) FROM dbo.Organizations WHERE Id IN (SELECT ncode FROM dbo.fn_listCode(@projectId))),null) project
		,IIF(@incChild = 1,'Yes','No') [IncludeChild]
        ,CASE @Select WHEN 1 THEN CONCAT('Document between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy'))
                      WHEN 2 THEN CONCAT('Due Date between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy'))
                      ELSE CONCAT('Create between  ',FORMAT(@FromDate,'dd/MM/yyyy'),'  and  ',FORMAT(@ToDate,'dd/MM/yyyy')) 
                     END Date
	      , IIF(@GroupCurrency = 1,'Yes','No') GroupByCurrency

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
select * from [dbo].[fn_CompanyInfoTable] (@ProjectId)