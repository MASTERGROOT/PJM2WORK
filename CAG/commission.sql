/*==> Ref:d:\pjm2\thecloud\notpublish\customprinting\reportcommands\cag_commission_report.sql ==>*/
 
DECLARE @p0  date				= '2024-12-20';
DECLARE @p1  nvarchar(max)		=186--null;
DECLARE @p2  bit				=	1;
DECLARE @p3  nvarchar(max)		=	null;
		
DECLARE @ToDate date					= @p0;
DECLARE @projectId NVARCHAR(max)		= @p1;
DECLARE @IncChild BIT					= @p2;
DECLARE @FinancialStatus NVARCHAR(max)	= @p3;


DECLARE @WorkerId INT  = dbo.fn_currentUser(); 
DECLARE @WorkerName NVARCHAR(max)  = ( Select Name From Workers Where Id = @WorkerId )


DECLARE @NewLine CHAR(2) = CHAR(13) + CHAR(10)
DECLARE @ga NVARCHAR(max) = ''

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
        
SELECT @ga += CONCAT(EnumKey,',') FROM dbo.GeneralAccountEntities WHERE Module IN ('AR','OtherAsset') AND EnumKey NOT IN (114) 

/**************************** Save More OrgId Or Single OrgId Not Include Child to Temp. ******************************/

DECLARE @OrgId TABLE (Id int)	 /*Save OrgId to Temp.*/
INSERT INTO @Orgid(Id)

SELECT	o.Id
FROM		dbo.Organizations o WITH (NOLOCK)
WHERE		EXISTS (
						SELECT	1
						FROM		dbo.Organizations pj WITH (NOLOCK)
						WHERE		pj.Id in (SELECT ncode FROM dbo.fn_listCode(@projectId)) 
									AND ((@IncChild = 1 AND o.Path LIKE pj.Path +'%')
											OR (@IncChild = 0 AND o.Id = pj.Id)
												)
			)

OPTION (RECOMPILE)
/*************************************************************************************************************/

IF OBJECT_ID('tempdb..#cte_JV') IS NOT NULL
    BEGIN
        DROP TABLE #cte_JV;
END;

create table #cte_JV 
(
	 JVId				int
	 ,JVLineId				int
	,JVCode				nvarchar(2000)
	,JVDate				date

	,OrgCode			nvarchar(2000)
	,OrgName			nvarchar(2000)

	,ExtOrgCode			nvarchar(2000)
	,ExtOrgName			nvarchar(2000)

	,DocId				int
	,DocCode			nvarchar(2000)
	,DocTypeId			int

	--,DueDate			date
	--,AccountCode		nvarchar(2000)
	--,POCode				nvarchar(2000)
	,VatAmt				decimal(26,6)
	,[ARAmt]			decimal(26,6)
	--,DocCurrency		nvarchar(200)
	--,DocCurrencyRate	decimal(26,12)
	--,TaxCode			nvarchar(max)
	--,TaxDate			nvarchar(max)

	--,SystemCategoryId	int
	,[DocStatus]		int
	--,Remarks			nvarchar(max)
	,[CreateBy]			nvarchar(max)


)
CREATE CLUSTERED INDEX IDX_C_cte_JV ON #cte_JV (DocTypeId,DocId)




insert into #cte_JV
(
	 JVId				
	,JVCode	
    ,JVLineId			
	,JVDate				

	,OrgCode			
	,OrgName			

	,ExtOrgCode			
	,ExtOrgName			

	,DocId				
	,DocCode			
	,DocTypeId			
		
	,VatAmt				
	,[ARAmt]			
	,[DocStatus]	
	,[CreateBy]
)
				SELECT	 
						 j.Id					JVId
						, j.Code				JVCode
                        , ar.JVLineId           JVLineId
						, convert(date,j.Date)	JVDate

						, da.LocationCode		OrgCode
						, j.OrgName				OrgName

						, j.ExtOrgCode			ExtOrgCode
						, j.ExtOrgName			ExtOrgName

						, j.MadeByDocId			DocId
						, j.MadeByDocCode		DocCode
						, j.MadeByTypeId		DocTypeId

						, IIF(j.DocStatus = -1,0,da.TaxAmount)	VatAmt
						, IIF(j.DocStatus = -1,0,ar.ARAmt)		[ARAmt]
						, j.DocStatus					[DocStatus]
						, da.CreateBy			[CreateBy]

				from  dbo.JournalVouchers j WITH (NOLOCK)
						inner join dbo.Journals jn WITH (NOLOCK) on jn.Id = j.JournalId --and jn.JournalTypeId = 3
						CROSS APPLY ( 	
									  SELECT   a1.LocationId,a1.LocationCode, q.CreateBy
											  , ISNULL(tv.TaxAmount,0)TaxAmount
									  FROM    dbo.InvoiceARs a1 WITH (NOLOCK)
											  LEFT JOIN dbo.InvoiceARLines tv WITH (NOLOCK) ON tv.InvoiceARId = a1.Id AND tv.SystemCategoryId IN (123,129,199,207) 
											  LEFT JOIN (	Select ivl.InvoiceARId,ivl.RefDocId,q.CreateBy From dbo.InvoiceARLines ivl
															Left Join dbo.Quotations q WITH (NOLOCK) ON q.id = ivl.RefDocId AND ivl.RefDoctypeId = 73
															Where ivl.SystemCategoryId IN (99) AND ivl.RefDoctypeId = 73
															Group By ivl.InvoiceARId,ivl.RefDocId,q.CreateBy ) q ON q.InvoiceARId = a1.Id
									  WHERE   a1.Id = j.MadeByDocId
											  AND j.MadeByTypeId = 38 AND jn.JournalTypeId = 3
						 UNION ALL
									  SELECT  a2.LocationId,a2.LocationCode,IIF(a2.CreateBy = 'Pojjaman2 API','Zip Event',NULL) CreateBy
											  , ISNULL(tv.TaxAmount,0)TaxAmount
									  FROM    dbo.OtherReceives a2 WITH (NOLOCK)
											  LEFT JOIN dbo.OtherReceiveLines tv WITH (NOLOCK) ON tv.OtherReceiveId = a2.Id AND tv.SystemCategoryId IN (123,129,199,207)
									  WHERE   a2.Id = j.MadeByDocId
											  AND j.MadeByTypeId = 44 AND jn.JournalTypeId IN (3,4) AND ExtOrgId != ''

						UNION ALL
									  SELECT  a3.LocationId,a3.LocationCode,NULL CreateBy
											  , ISNULL(IIF(a3.DocTypeId = 41,tv.AdjustTaxAmount * -1,tv.AdjustTaxAmount),0)TaxAmount
									  FROM    dbo.AdjustInvoiceARs a3 WITH (NOLOCK)
											  LEFT JOIN dbo.AdjustInvoiceARLines tv WITH (NOLOCK) ON tv.AdjustInvoiceARId = a3.Id AND tv.SystemCategoryId IN (123,129,199,207)
				
									  WHERE   a3.Id = j.MadeByDocId
											  AND j.MadeByTypeId IN (41,42) AND jn.JournalTypeId = 3
											  ) da
						OUTER APPLY (	SELECT  s.JVLineId,ISNULL(s.DocLineAmount,0) ARAmt--, s.AccountCode, s.DocCurrency, s.DocCurrencyRate 
										FROM    dbo.AcctElementSets s WITH (NOLOCK)
										WHERE	s.DocId = j.MadeByDocId 
												AND s.DocTypeId = j.MadeByTypeId 
												AND (s.GeneralAccount IN (404) AND s.PayeeRefId != '')
												AND (j.MadeByTypeId = 44 AND s.Description != 'ตั้งหนี้')
										UNION ALL 
										SELECT  s.JVLineId,IIF(s.isDebit = 0,s.DocLineAmount * -1,s.DocLineAmount) ARAmt--, s.AccountCode, s.DocCurrency, s.DocCurrencyRate 
										FROM    dbo.AcctElementSets s WITH (NOLOCK)
										WHERE	s.DocId = j.MadeByDocId 
												AND s.DocTypeId = j.MadeByTypeId 
												AND s.GeneralAccount IN (SELECT ncode FROM dbo.fn_listCode(@ga))
												AND ((j.MadeByTypeId = 44 AND s.Description = 'ตั้งหนี้') OR j.MadeByTypeId <> 44)
												)	ar
						Left Join dbo.Organizations o WITH (NOLOCK) ON o.Id = da.LocationId
						inner join Organizations_ProjectConstruction op on o.id= op.id
				WHERE   ISNULL(j.DocStatus,0) NOT IN (-6,-1)
						AND ((op.FinancialStatus IN (SELECT * FROM dbo.fn_listCode(@FinancialStatus))) OR @FinancialStatus IS NULL )
						AND ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = da.LocationId)) OR @projectId is NULL)
						AND (j.Date <= @ToDate)

-- SELECT * from #cte_JV

												

OPTION (RECOMPILE)
/*==============================================================================================*/
IF OBJECT_ID('tempdb..#Revenue') IS NOT NULL
    BEGIN
        DROP TABLE #Revenue;
END;

IF OBJECT_ID('tempdb..#Expenses') IS NOT NULL
    BEGIN
        DROP TABLE #Expenses;
END;

declare @SitePath_64 nvarchar(max)
set @SitePath_64 = (SELECT sp.SitePath FROM dbo.SitePathList() sp WHERE sp.DocTypeId = 64)



--*********************** Temp #Revenue ***********************
			SELECT   
					j.DocCode, j.JVDate DocDate, j.OrgCode, j.OrgName, j.ExtOrgCode, j.ExtOrgName,j.CreateBy
					, dc.DocTypeCode DocType,j.DocStatus
					, ISNULL(IIF(j.DocCode LIKE '%ORRV%',j.ARAmt,vl.ClearAmount),0) Amount--ISNULL(vl.ClearAmount,0) Amount
					, 'รายได้' [Group], 1 SortNumber, vl.*
			INTO	#Revenue
			FROM    #cte_JV j
					left hash join dbo.DocTypeCodeList() dc ON dc.DocTypeId = j.DocTypeId
					INNER hash join (
									  SELECT  jv.DocId,jv.DocTypeId,jv.JVLineId 
											 ,IIF(jv.DocStatus = -1,0,ISNULL(ds.Amount,0)) SpecialDiscount
											  ,IIF(jv.DocStatus = -1,0,ISNULL(de.DepositAmt,0))  DepositAmt
											  ,IIF(jv.DocStatus = -1,0,ISNULL(rt.Amount,0))  RetentionAmt
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.SetARAmount - vat.SetVATAmount,0)) SetAmount
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.ARRemain - vat.VATRemain,0)) RemainAmount
                                              ,IIF(jv.DocStatus = -1,0,ISNULL(ar.ClearARAmount - vat.ClearVATAmount,0)) ClearAmount
									  FROM	   #cte_JV jv  WITH (NOLOCK)
											   LEFT join dbo.InvoiceARs i on jv.DocId = i.Id and jv.DocTypeId = 38 /* เปลี่ยน inner join --> left join */
											   left  join dbo.InvoiceARLines ds WITH (NOLOCK) on ds.InvoiceARId = i.Id and ds.SystemCategoryId = 124
											   OUTER APPLY (
															select	il.InvoiceARId,sum(il.TaxBase)Depositamt
															from	dbo.InvoiceARLines il WITH (NOLOCK)
															where   il.SystemCategoryId = 55
																	AND ISNULL(il.DocQty,0) = 0
																	AND il.InvoiceARId = i.Id
																	group by il.InvoiceARId
																	) de
											   left  join dbo.InvoiceARLines rt WITH (NOLOCK) on rt.InvoiceARId = i.Id and rt.SystemCategoryId = 49
                                               OUTER APPLY (
                                                            select aes.Amount SetARAmount, aesr.RemainAmount ARRemain, aec.Amount ClearARAmount
                                                            from AcctElementSets aes 
                                                            INNER JOIN AcctElementSets_RemainAcctElement aesr ON aes.Id = aesr.Id
                                                            LEFT JOIN AcctElementClears aec ON aesr.Id = aec.SetId
                                                            WHERE aes.GeneralAccount = 111 AND aes.DocId = jv.DocId AND aes.DocTypeId = jv.DocTypeId
                                               ) ar /* เพิ่ม set amount, remain amount, clear amount ของบรรทัดใบเเจ้งหนี้ที่ GA เป็น AR*/
                                               OUTER APPLY (
                                                            select aes.Amount SetVATAmount, aesr.RemainAmount VATRemain, aec.Amount ClearVATAmount
                                                            from AcctElementSets aes 
                                                            INNER JOIN AcctElementSets_RemainAcctElement aesr ON aes.Id = aesr.Id
                                                            LEFT JOIN AcctElementClears aec ON aesr.Id = aec.SetId
                                                            WHERE aes.GeneralAccount = 293 AND aes.DocId = jv.DocId AND aes.DocTypeId = jv.DocTypeId
                                               ) vat /* เพิ่ม set amount, remain amount, clear amount ของบรรทัดใบเเจ้งหนี้ที่ GA เป็น VAT*/
									) vl ON vl.DocId = j.DocId AND vl.DocTypeId = j.DocTypeId AND vl.JVLineId = j.JVLineId
					left hash join dbo.SitePathList() sp on j.DocTypeId = sp.DocTypeId

-- select * FROM #Revenue --where SetAmount != ClearAmount
-- SELECT * FROM #cte_JV where     DocCode like 'CG-ORIV202308-001'

--*********************** Temp #Expenses ***********************

		Select	pd.RefDocCode DocCode,pd.Date DocDate,o.Code OrgCode,o.Name OrgName
				,ISNULL(pv.ExtOrgCode,op.ExtOrgCode) ExtOrgCode
				,ISNULL(pv.ExtOrgName,ISNULL(op.ExtOrgName,wel.Description)) ExtOrgName
				, dc.DocTypeCode DocType
				,ISNULL(pv.DocStatus,ISNULL(op.DocStatus,we.DocStatus)) DocStatus,pd.Amount
				, 'ค่าใช้จ่าย' [Group], 2 SortNumber ,re.*
		INTO	#Expenses
		From dbo.PaidCostLines pd
		Left Join dbo.Organizations o WITH (NOLOCK) ON o.Id = pd.PaidProjectId
		inner join Organizations_ProjectConstruction p on o.id= p.id
		Left Join dbo.Payments pv WITH (NOLOCK) ON pv.id = pd.RefDocId AND pd.RefDocTypeId = 50
		Left Join dbo.OtherPayments op WITH (NOLOCK) ON op.Id = pd.RefDocId AND pd.RefDocTypeId = 43
		Left Join dbo.WorkerExpenses we WITH (NOLOCK) ON we.Id = pd.RefDocId AND pd.RefDocTypeId = 97
		Left Join dbo.WorkerExpenseLines wel WITH (NOLOCK) ON wel.WorkerExpenseId = pd.RefDocId AND pd.RefDocTypeId = 97 AND wel.Id = pd.RefDocLineId
		Left hash Join dbo.DocTypeCodeList() dc ON dc.DocTypeId = pd.RefDocTypeId
        OUTER APPLY (
                    select NULL SetAmount, ISNULL(aesr.RemainAmount,0) RemainAmount, aec.Amount ClearAmount
                            from AcctElementSets aes 
                            INNER JOIN AcctElementSets_RemainAcctElement aesr ON aes.Id = aesr.Id
                            LEFT JOIN AcctElementClears aec ON aesr.Id = aec.SetId
                            WHERE aes.DocLineId = pd.RefDocLineId AND aes.DocId = pd.RefDocId AND aes.DocTypeId = pd.RefDocTypeId
        ) re /* เพิ่ม set amount, remain amount, clear amount ของบรรทัดจาก paid cost lines*/
		Where	((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = o.Id)) OR @projectId is NULL)
				AND ((p.FinancialStatus IN (SELECT * FROM dbo.fn_listCode(@FinancialStatus))) OR @FinancialStatus IS NULL )
				AND (pd.Date <= @ToDate)

-- SELECT * from #Expenses WHERE DocCode like 'CG-ORRV202409-015'

-- --*********************** Show Data ***********************

Select	ROW_NUMBER() OVER (PARTITION BY d.OrgCode ORDER BY d.SortNumber,d.DocCode) #Count,d.*
		,ISNULL(r.TotalRevenue,0) TotalRevenue,ISNULL(e.TotalExpenses,0) TotalExpenses
		,ISNULL(r.TotalRevenue,0)-ISNULL(e.TotalExpenses,0) Profit
		,IIF(ISNULL(r.TotalRevenue,0) = 0,0,((ISNULL(r.TotalRevenue,0)-ISNULL(e.TotalExpenses,0))*100)/ISNULL(r.TotalRevenue,0)) Profit_Percent
		,c.CompanyName,c.TaxId,c.Tax_Branch_Code,c.Tax_Branch_Name,@WorkerName WorkerName,GETDATE() CurrentDate,@ToDate ToDate
        
From (
Select DocCode,DocDate,OrgCode,OrgName,ExtOrgCode,ExtOrgName,CreateBy,DocType,DocStatus,Amount,[Group],SortNumber, SetAmount , RemainAmount , ClearAmount  From #Revenue
Union All
Select DocCode,DocDate,OrgCode,OrgName,ExtOrgCode,ExtOrgName,NULL CreateBy,DocType,DocStatus,Amount,[Group],SortNumber, SetAmount , RemainAmount , ClearAmount  From #Expenses
) d
Left Join (	Select r.OrgCode,SUM(ISNULL(r.Amount,0)) TotalRevenue From #Revenue r Group By r.OrgCode) r ON r.OrgCode = d.OrgCode
Left Join (	Select e.OrgCode,SUM(ISNULL(e.Amount,0)) TotalExpenses From #Expenses e Group By e.OrgCode) e ON e.OrgCode = d.OrgCode
Left Join (
			Select o.Code,c.Name CompanyName,t.TaxId,t.Tax_Branch_Code,t.Tax_Branch_Name
			From dbo.Organizations o
			Left Join dbo.Organizations c WITH (NOLOCK) ON c.Id = o.UnderTaxEntityId AND c.OrgCategory = 999
			Left Join dbo.Organizations_OrganizationTaxEntity t WITH (NOLOCK) ON t.id = c.Id
			Where o.OrgCategory != 999
			) c ON c.Code = d.OrgCode

OPTION (recompile)



IF OBJECT_ID('tempdb..#Revenue') IS NOT NULL
    BEGIN
        DROP TABLE #Revenue;
END;
IF OBJECT_ID('tempdb..#Expenses') IS NOT NULL
    BEGIN
        DROP TABLE #Expenses;
END;