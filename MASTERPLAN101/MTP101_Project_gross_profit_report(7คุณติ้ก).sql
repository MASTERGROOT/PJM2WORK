/*==> Ref:c:\web\prototype-uc02\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/
 

/*รายงานกำไรขั้นต้น รายโครงการ*/

DECLARE @p0 DATETIME = '2025-09-02'
DECLARE @p1 nvarchar(500) = null--'1931'--'1107,1152' --''--
DECLARE @p2 BIT = 0
DECLARE @p3 INT = NULL

DECLARE @Todate DATETIME = @p0
DECLARE @ProjectId nvarchar(500) = @p1
DECLARE @IncChild BIT = @p2
DECLARE @Status INT = @p3

/************************************************************************************************************************************************************************/

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
											AND o.OrgCategory IN (85))
			) OR (@ProjectId IS NULL AND o.OrgCategory IN (85))

OPTION (RECOMPILE)
            

/************************************************************************************************************************************************************************/
/*#Tempbudget*/
IF OBJECT_ID(N'tempdb..#Tempbudget') IS NOT NULL
BEGIN
    DROP TABLE #Tempbudget;
END;

SELECT *
INTO #Tempbudget
FROM
(

select *
from (
		select ProjectId,Id,Date
				, ROW_NUMBER () over (partition by ProjectId,BudgetId order by ProjectId,BudgetId,Date DESC) rvNo
				, Code
				, Description
		from RevisedBudgets
		--where Date <= @Todate
) rv
where rv.rvNo  = 1
)r 
option(recompile);

/************************************************************************************************************************************************************************/
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPo', 'U') IS NOT NULL
DROP TABLE #TempPo
	-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT *

	INTO #TempPo
	FROM (
		SELECT p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.Id PolineId,ISNULL(bl.SystemCategoryId,99) BudgetTypeId,ISNULL(bl.SystemCategory,'Material') BudgetType,vat.VatTypeId,vat.VatType
			,1.00 pt,0.00 PODepositAmount,0.00 PORetentionAmount,0.00 POWHT
			,IIF((vat.VatTypeId = 123 AND pl.CalcVat = 1),ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)*107/100,ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)) AS POAmount
			,CASE WHEN (vat.VatTypeId = 129 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)*100/107
				WHEN (vat.VatTypeId = 123 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)
				ELSE ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)
			END POTaxBase
			,CASE WHEN (vat.VatTypeId = 129 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0)*7/107
				WHEN (vat.VatTypeId = 123 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount/* +ISNULL(difcm.Amount,0) */,0) * 7/100
				ELSE 0
			END POTaxAmount
			,ISNULL(adjPo.AdjustPOAmount,0)AdjustPOAmount,ISNULL(adjPo.AdjustPOTaxBase,0)AdjustPOTaxBase,ISNULL(adjPo.AdjustPOTaxAmount,0)AdjustPOTaxAmount
		from POes p
		LEFT JOIN POLines pl ON p.Id = pl.POId
		LEFT JOIN CommittedCostLines ccl ON ccl.RefdoclineId = pl.Id AND ccl.RefDocTypeId = 22
		LEFT JOIN Budgetlines bl ON bl.Id = ccl.BudgetLineId
		LEFT JOIN (
			select POId,SystemCategoryId VatTypeId,SystemCategory VatType from POLines where SystemCategoryId IN (123,129,131) GROUP BY POId,SystemCategoryId,SystemCategory
		) vat ON vat.POId = p.Id
        outer apply
				(
					SELECT 
						SUM(difcm.amount)amount
						,difcm.CommittedCostLineId 
					FROM CommittedCostLines difcm 
					WHERE 
					difcm.CommittedCostLineId =  ccl.id
					and
					difcm.date <=@Todate --and difcm.AllocationType in (3,4)
					GROUP by difcm.CommittedCostLineId
				) difcm /*on difcm.CommittedCostLineId =  c.id*/
		OUTER APPLY (
			SELECT apl.POId,apl.POLineId,adjvat.VatTypeId,adjvat.VatType
			,IIF((adjvat.VatTypeId = 123 AND apl.CalcVat = 1),ISNULL(apl.AdjustAmount,0)*107/100,ISNULL(apl.AdjustAmount,0)) AS AdjustPOAmount
			,CASE WHEN (adjvat.VatTypeId = 129 AND apl.CalcVat = 1) THEN ISNULL(apl.AdjustAmount,0)*100/107
				WHEN (adjvat.VatTypeId = 123 AND apl.CalcVat = 1) THEN ISNULL(apl.AdjustAmount,0)
				ELSE ISNULL(apl.AdjustAmount,0)
			END AdjustPOTaxBase
			,CASE WHEN (adjvat.VatTypeId = 129 AND apl.CalcVat = 1) THEN ISNULL(apl.AdjustAmount,0)*7/107
				WHEN (adjvat.VatTypeId = 123 AND apl.CalcVat = 1) THEN ISNULL(apl.AdjustAmount,0) * 7/100
				ELSE 0
			END AdjustPOTaxAmount
			FROM AdjustPOes ap
			LEFT JOIN AdjustPOLines apl ON ap.Id = apl.AdjustPOId
			LEFT JOIN (
				select AdjustPOId,SystemCategoryId VatTypeId,SystemCategory VatType from AdjustPOLines where SystemCategoryId IN (123,129,131) GROUP BY AdjustPOId,SystemCategoryId,SystemCategory
			) adjvat ON adjvat.AdjustPOId = apl.AdjustPOId
			WHERE pl.Id = apl.POLineId AND p.Id = apl.POId AND ap.[Date] <= @Todate
			) adjPo 
		WHERE p.DocStatus not in (-1) 
								and pl.SystemCategoryId IN (99,100,105) 
	) po
	WHERE po.Date <= @Todate and ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = po.LocationId)) /* OR @ProjectId is NULL */)
	-- GROUP BY po.LocationId
	option(recompile);
	CREATE INDEX IX_TempPo_LocationId ON #TempPo(LocationId)
	CREATE INDEX IX_TempPo_PolineId ON #TempPo(PolineId)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempSC', 'U') IS NOT NULL
DROP TABLE #TempSC
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT *
	INTO #TempSC
	FROM (
		SELECT sc.LocationId,sc.Id,sc.Code,105 DocType,sc.[Date],scl.Id SCLineId,ISNULL(bl.SystemCategoryId,105) BudgetTypeId,ISNULL(bl.SystemCategory,'SubContract') BudgetType,vat.VatTypeId,vat.VatType
		,scl.Amount/sc.SubTotal pt,(scl.Amount/sc.SubTotal)*sc.DepositAmount SCDepositAmount,(scl.Amount/sc.SubTotal)*sc.RetentionAmount SCRetentionAmount,(scl.Amount/sc.SubTotal)*sc.WHTAmount SCWHT
				,IIF(vat.VatTypeId = 123,ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)*107/100,ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)) AS SCAmount
				,CASE WHEN vat.VatTypeId = 129 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)*100/107
				WHEN vat.VatTypeId = 123 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)
				ELSE ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)
			END SCTaxBase
			,CASE WHEN vat.VatTypeId = 129 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0)*7/107
				WHEN vat.VatTypeId = 123 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount+ISNULL(difcm.Amount,0),0) * 7/100
				ELSE 0
			END SCTaxAmount
			,ISNULL(vo.AdjustSCAmount,0) AdjustSCAmount,ISNULL(vo.AdjustSCTaxBase,0) AdjustSCTaxBase,ISNULL(vo.AdjustSCTaxAmount,0) AdjustSCTaxAmount
		FROM SubContracts sc
		LEFT JOIN SubContractLines scl ON sc.Id = scl.SubContractId AND IsParent = 0
		LEFT JOIN CommittedCostLines ccl ON ccl.RefdoclineId = scl.Id AND ccl.RefDocTypeId = 105
		LEFT JOIN Budgetlines bl ON bl.Id = ccl.BudgetLineId
		LEFT JOIN (
			SELECT SubContractId,SystemCategoryId VatTypeId,SystemCategory VatType FROM SubContractLines  where SystemCategoryId IN (123,129,131) GROUP BY SubContractId,SystemCategoryId,SystemCategory
		) vat ON vat.SubContractId = sc.Id
        outer apply
				(
					SELECT 
						SUM(difcm.amount)amount
						,difcm.CommittedCostLineId 
					FROM CommittedCostLines difcm 
					WHERE 
					difcm.CommittedCostLineId =  ccl.id
					and
					difcm.date <=@Todate --and difcm.AllocationType in (3,4)
					GROUP by difcm.CommittedCostLineId
				) difcm /*on difcm.CommittedCostLineId =  c.id*/
		OUTER APPLY (
				SELECT vol.RefDocId SCId,vol.RefDocLineId SCLineId,volvat.VatTypeId,volvat.VatType
			,IIF(volvat.VatTypeId = 123,ISNULL(vol.AdjustDocLineAmount,0)*107/100,ISNULL(vol.AdjustDocLineAmount,0)) AS AdjustSCAmount
			,CASE WHEN volvat.VatTypeId = 129 THEN ISNULL(vol.AdjustDocLineAmount,0)*100/107
				WHEN volvat.VatTypeId = 123 THEN ISNULL(vol.AdjustDocLineAmount,0)
				ELSE ISNULL(vol.AdjustDocLineAmount,0)
			END AdjustSCTaxBase
			,CASE WHEN volvat.VatTypeId = 129 THEN ISNULL(vol.AdjustDocLineAmount,0)*7/107
				WHEN volvat.VatTypeId = 123 THEN ISNULL(vol.AdjustDocLineAmount,0) * 7/100
				ELSE 0
			END AdjustSCTaxAmount
			FROM VariationOrders vo
			LEFT JOIN VariationOrderLines vol ON vo.Id = vol.VariationOrderId
			LEFT JOIN (
				select VariationOrderId,SystemCategoryId VatTypeId,SystemCategory VatType from VariationOrderLines where SystemCategoryId IN (123,129,131) GROUP BY VariationOrderId,SystemCategoryId,SystemCategory
			) volvat ON volvat.VariationOrderId = vol.VariationOrderId
			WHERE scl.Id = vol.RefDocLineId AND scl.SubContractId = vol.RefDocId and vo.[Date] <= @Todate
		) vo
		WHERE sc.DocStatus != -1 AND scl.SystemCategoryId IN (99,100,105) --AND sc.Id = 6755--1027
	) sc
	WHERE sc.[Date] <= @Todate AND ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = sc.LocationId)) /* OR @ProjectId is NULL */)
	option(recompile);

	CREATE INDEX IX_TempSC_LocationId ON #TempSC(LocationId)
	CREATE INDEX IX_TempSC_SCLineId ON #TempSC(SCLineId)


-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempInvoice', 'U') IS NOT NULL
DROP TABLE #TempInvoice
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

	SELECT il.id,il.Code,il.RefDocId2,il.RefDocCode2,il.RefDocTypeId2,il.RefDocType2
			,il.BudgetTypeId,il.BudgetType,il.RefDocLineId2,il.VatTypeId,il.VatType
			,CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id)  Invpt 
			,il.CalcVat
			,il.InvoiceAmount,il.InvoiceTaxBase,il.InvoiceTaxAmount
			,il.InvoiceDPAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPAmount
			,il.InvoiceDPTaxbase * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPTaxbase
			,il.InvoiceDPTaxAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceDPTaxAmount
			,il.InvoiceRTAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceRTAmount
			,il.InvoiceWHT * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceWHT
			,il.InvoiceAdjustAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustAmount
			,il.InvoiceAdjustTaxBase * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustTaxBase
			,il.InvoiceAdjustTaxAmount * CAST(il.InvoiceAmount AS DECIMAL(20,10))/SUM(ISNULL(il.InvoiceAmount ,0.00)) OVER (PARTITION BY il.Id) InvoiceAdjustTaxAmount
	INTO #TempInvoice
	FROM (
		SELECT i.Id,i.Code,il.RefDocId2,il.RefDocCode2,il.RefDocTypeId2,il.RefDocType2
				,ISNULL(bl.SystemCategoryId,CASE WHEN (RefDocTypeId2 = 22 OR i.DocTypeId = 37) THEN 99 WHEN (RefDocTypeId2 = 105 OR i.DocTypeId = 213) THEN 105 ELSE NULL END) BudgetTypeId
				,ISNULL(bl.SystemCategory,CASE WHEN (RefDocTypeId2 = 22 OR i.DocTypeId = 37) THEN 'Material' WHEN (RefDocTypeId2 = 105 OR i.DocTypeId = 213) THEN 'SubContract' ELSE NULL END) BudgetType
				,ISNULL(il.RefDocLineId2,pal.RefDocLineId)RefDocLineId2,vat.VatTypeId,vat.VatType
				/* ,pt.Invpt */,il.CalcVat
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount)*107/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) ,0)
					ELSE ISNULL((il.Amount - il.SpecialDiscount) ,0) END InvoiceAmount
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL(il.Amount - il.SpecialDiscount,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 100/107,0)
					ELSE ISNULL(il.Amount - il.SpecialDiscount,0) END InvoiceTaxBase
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/107,0)
					ELSE 0 END InvoiceTaxAmount

				,ISNULL(dp.DPAmount,0) /* * pt.Invpt */ InvoiceDPAmount
				,ISNULL(dp.DPTaxbase,0) /* * pt.Invpt */ InvoiceDPTaxbase
				,ISNULL(dp.DPTaxAmount,0) /* * pt.Invpt */ InvoiceDPTaxAmount 
				,ISNULL(rt.RTAmount,0) /* * pt.Invpt */ InvoiceRTAmount
				,ISNULL(wht.WHT,0) /* * pt.Invpt */ InvoiceWHT
				,ISNULL(cn.InvoiceAdjustAmount,0) /* * pt.Invpt */ InvoiceAdjustAmount
				,ISNULL(cn.InvoiceAdjustTaxBase,0) /* * pt.Invpt */ InvoiceAdjustTaxBase
				,ISNULL(cn.InvoiceAdjustTaxAmount,0) /* * pt.Invpt */ InvoiceAdjustTaxAmount
		FROM Invoices i
		left join InvoiceLines il on i.Id = il.InvoiceId
		LEFT JOIN AccountCostLines acl ON acl.RefdoclineId = il.Id AND acl.RefDocTypeId IN (37,213) AND acl.[Date] <= @Todate
		LEFT JOIN Budgetlines bl ON bl.Id = acl.BudgetLineId
		LEFT JOIN ProgressAcceptanceLines pal ON pal.Id = il.RefDocLineId AND pal.ProgressAcceptanceId = il.refdocid AND il.RefDocTypeId IN (209,210)
		-- LEFT JOIN (
		-- 	SELECT Id InvLineId,NULLIF((ISNULL(Amount,0)/ SUM(CASE WHEN SystemCategoryId IN (99,100,105) THEN Amount END)
		-- 		OVER (PARTITION BY invoiceid)),0) Invpt from InvoiceLines where SystemCategoryId IN (99,100,105)
		-- ) pt ON pt.InvLineId = il.Id
		LEFT JOIN (
			select InvoiceId,SUM(Amount) DPAmount,SUM(TaxBase) DPTaxbase,SUM(TaxAmount) DPTaxAmount from InvoiceLines where SystemCategoryId = 54 GROUP BY InvoiceId
		) dp ON i.Id = dp.InvoiceId
		LEFT JOIN (
			select InvoiceId,SUM(Amount) RTAmount from InvoiceLines where SystemCategoryId = 48 GROUP BY InvoiceId
		) rt ON i.Id = rt.InvoiceId
		LEFT JOIN (
			select InvoiceId,SystemCategoryId 
			VatTypeId,SystemCategory VatType from InvoiceLines where SystemCategoryId IN (123,129,131) GROUP BY InvoiceId,SystemCategoryId,SystemCategory
		) vat ON i.Id = vat.InvoiceId
		LEFT JOIN (
				SELECT InvoiceId,SUM(Amount) WHT from InvoiceLines where SystemCategoryId = 138 GROUP BY InvoiceId
				) wht ON wht.InvoiceId = i.Id
		left join (
			select c.Id,cl.RefDocId,cl.RefDocCode
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.AdjustTaxBase),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.AdjustTaxBase),0)
				END InvoiceAdjustTaxBase
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.AdjustTaxAmount),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.AdjustTaxAmount),0)
				END InvoiceAdjustTaxAmount
			,CASE WHEN c.DocTypeId = 39 THEN ISNULL(SUM(cl.Amount),0)*-1
				WHEN c.DocTypeId = 40 THEN ISNULL(SUM(cl.Amount),0)
				END InvoiceAdjustAmount
			from AdjustInvoices c
			left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
			where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1) AND cl.RefDocTypeId = 37 AND c.[Date] <= @Todate
			group by c.Id,cl.RefDocId,cl.RefDocCode,c.DocType,c.DocTypeId
		) cn ON cn.RefDocId = i.Id
		WHERE il.SystemCategoryId IN (99,100,105) and i.DocStatus not in (-1) AND i.[Date] <= @Todate --AND il.refdocid2 IN (select distinct id from #TempPo)
	) il
	option(recompile);
	CREATE INDEX IX_TempInvoice_RefDocLineId2 ON #TempInvoice(RefDocLineId2)
	CREATE INDEX IX_TempInvoice_Id ON #TempInvoice(Id)
	CREATE INDEX IX_TempInvoice_RefDocTypeId2 ON #TempInvoice(RefDocTypeId2)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPV', 'U') IS NOT NULL
DROP TABLE #TempPV
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

	SELECT *
	INTO #TempPV
	FROM (
		SELECT pl.PaymentId,pl.DocId,pl.DocCode,pl.DocTypeId,pl.DocType--,bl.SystemCategoryId BudgetTypeId,bl.SystemCategory BudgetType
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocId,acset.IvId) IvId
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocCode,acset.IvCode) IvCode
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocTypeId,acset.DocTypeId) AcsetDocTypeId
				,IIF(acset.DocTypeId IN (39,40),pvcn.RefDocType,acset.DocType) AcsetDocType,pt.Pvpt
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.PayAmount,0),ISNULL(pl.PayAmount,0)) 
				+ IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.RetentionSetAmount,0),ISNULL(pl.RetentionSetAmount,0)) PayAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.RetentionSetAmount,0),ISNULL(pl.RetentionSetAmount,0)) RetentionSetAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*(ISNULL(dd.DeductAmount,0) * pt.Pvpt),ISNULL(dd.DeductAmount,0) * pt.Pvpt) DeductAmount
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*(ISNULL(wht.WHT,0) * pt.Pvpt),ISNULL(wht.WHT,0) * pt.Pvpt) WHT
				
		from Payments p
		LEFT JOIN PaymentLines pl ON pl.PaymentId = p.Id
		LEFT JOIN (
			SELECT Id PVLineId,ABS(ISNULL(PayAmount,0)/ NULLIF(SUM(CASE WHEN SystemCategoryId  NOT IN (53,56,57,59,74,107,111,138,141,176) THEN PayAmount END)
					OVER (PARTITION BY PaymentId),0)) Pvpt from PaymentLines where SystemCategoryId  NOT IN (53,56,57,59,74,107,111,138,141,176)
		) pt ON pt.PVLineId = pl.Id
		LEFT JOIN (
			SELECT acct.Id SetId,acct.DocId IvId,acct.DocCode IvCode,acct.DocTypeId,acct.DocType
				,CASE WHEN acct.DocTypeId IN (37,213) THEN ivVat.VatTypeId
						WHEN acct.DocTypeId = 149 THEN 129
						ELSE 131
				END VatTypeId
				,CASE WHEN acct.DocTypeId IN (37,213) THEN ivVat.VatType
						WHEN acct.DocTypeId = 149 THEN 'VatInc'
						ELSE 'NoVat'
				END VatType
			from AcctElementSets acct	
			LEFT JOIN (
				SELECT InvoiceId IvId,SystemCategoryId VatTypeId, SystemCategory VatType FROM InvoiceLines ivl
				WHERE ivl.SystemCategoryId IN (123,129,131)
				GROUP BY InvoiceId,SystemCategoryId,SystemCategory,ivl.RefDocTypeId,ivl.RefDocId
			) ivVat ON ivVat.IvId = acct.DocId AND acct.DocTypeId IN (37,213)
			WHERE acct.ReadyToUse = 1 --AND acct.DocTypeId IN (37,39,40)
		) acset ON acset.SetId = pl.SetId
		LEFT JOIN (
			select cl.AdjustInvoiceId,IIF(cl.RefDocId = 0, c.Id,cl.RefDocId) RefDocId,IIF(cl.RefDocId = 0,c.Code,cl.RefDocCode)RefDocCode
			,IIF(cl.RefDocTypeId = 0,c.DocTypeId,cl.RefDocTypeId) RefDocTypeId,IIF(cl.RefDocTypeId = 0,c.DocType,cl.RefDocType) RefDocType,IIF(c.DocTypeId = 39,cl.Amount*-1,cl.Amount) AdjustAmount
			from AdjustInvoices c
			LEFT JOIN AdjustInvoiceLines cl ON cl.AdjustInvoiceId = c.Id
			where cl.SystemCategoryId in (152,153) 
		) pvcn ON (pvcn.AdjustInvoiceId = pl.DocId AND pl.DocTypeId = 39) OR (pvcn.AdjustInvoiceId = acset.IvId AND acset.DoctypeId =39)
		LEFT JOIN (
				SELECT PaymentId, SUM(PayAmount) DeductAmount from PaymentLines where SystemCategoryId = 176 GROUP BY PaymentId
				) dd ON dd.PaymentId = p.ID
		LEFT JOIN (
				SELECT PaymentId, SUM(DocAmount) WHTBase,SUM(PayAmount) WHT from PaymentLines where SystemCategoryId = 138 GROUP BY PaymentId
				) wht ON wht.PaymentId = p.ID
		where pl.SystemCategoryId IN (37,39,40,44,50,147,149,213,142) AND p.DocStatus NOT IN (-1) AND p.[Date] <= @Todate --and pl.PaymentId IN (1995)
	) pv
	option(recompile);
	CREATE INDEX IX_TempPV_PaymentId ON #TempPV(PaymentId)
	CREATE INDEX IX_TempPV_DocId ON #TempPV(DocId)
	CREATE INDEX IX_TempPV_DocTypeId ON #TempPV(DocTypeId)
	CREATE INDEX IX_TempPV_IvId ON #TempPV(IvId)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCost', 'U') IS NOT NULL
DROP TABLE #TempCost
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
SELECT *
INTO #TempCost
FROM (
		SELECT ccl.CommittedProjectId LocationId,ccl.RefDocId Id,ccl.RefDocCode Code,ccl.RefDocTypeId Doctype,ccl.[Date],ccl.RefDocLineId CommitLineId,bl.SystemCategoryId BudgetTypeId,bl.SystemCategory BudgetType,Doc.VatTypeId,Doc.VatType
				,IIF(ccl.RefDocTypeId = 64,1.00,IIF((Doc.VatTypeId = 123 AND Doc.CalcVat = 1),ISNULL(ccl.Amount,0),ISNULL(ccl.Amount,0)*107/100)/NULLIF(Doc.SubTotal,0.00)) pt
				,0.00 DPAmount,0.00 RTAmount,IIF(ccl.RefDocTypeId = 64,1.00,ccl.Amount/NULLIF(Doc.SubTotal,0.00))*Doc.WHT CommitWHT
				,IIF(Doc.CalcVat = 1,ISNULL(ccl.Amount,0)*107/100,ISNULL(ccl.Amount,0)) CommitAmount
				,ISNULL(ccl.Amount,0) CommitTaxBase
				,IIF(Doc.CalcVat = 1,ISNULL(ccl.Amount,0) * 7/100,0) CommitTaxAmount
				,0.00 AdjustAmount,0.00 AdjustTaxBase,0.00 AdjustTaxAmount,NULL RefDocId2,CAST(NULL AS NVARCHAR(20)) RefDocCode2,NULL RefDocLineId2
				,IIF(DocActual.CalcVat = 1,ISNULL(acl.Amount,0)*107/100,ISNULL(acl.Amount,0))  InvoiceAmount
				,ISNULL(acl.Amount,0) InvoiceTaxBase
				,IIF(DocActual.CalcVat = 1,ISNULL(acl.Amount,0) * 7/100,0) InvoiceTaxAmount
				,0.00 InvoiceDPAmount
				,IIF(acl.RefDocTypeId = 64,1.00,IIF((DocActual.VatTypeId = 129 AND DocActual.CalcVat = 1),ISNULL(acl.Amount,0)*107/100,ISNULL(acl.Amount,0))/NULLIF(DocActual.SubTotal,0.00))*DocActual.RTAmount InvoiceRTAmount
				,0.00 InvoiceAdjustAmount,0.00 InvoiceAdjustTaxBase,0.00 InvoiceAdjustTaxAmount
				,IIF(DocPaid.CalcVat = 1,ISNULL(pcl.Amount,0)*107/100,ISNULL(pcl.Amount,0)) AS PayAmount
				,ISNULL(pcl.Amount,0) PayTaxBase
				,IIF(DocPaid.CalcVat = 1,ISNULL(pcl.Amount,0) * 7/100,0) PayTaxAmount
				,IIF(pcl.RefDocTypeId = 64,1.00,IIF((DocPaid.VatTypeId = 129 AND DocPaid.CalcVat = 1),ISNULL(pcl.Amount,0)*107/100,ISNULL(pcl.Amount,0))/NULLIF(DocPaid.SubTotal,0.00))*DocPaid.RTAmount RetentionSetAmount
				,IIF(pcl.RefDocTypeId = 64,1.00,IIF((DocPaid.VatTypeId = 129 AND DocPaid.CalcVat = 1),ISNULL(pcl.Amount,0)*107/100,ISNULL(pcl.Amount,0))/NULLIF(DocPaid.SubTotal,0.00))*DocPaid.DeductAmount DeductAmount
				,IIF(pcl.RefDocTypeId = 64,1.00,IIF((DocPaid.VatTypeId = 129 AND DocPaid.CalcVat = 1),ISNULL(pcl.Amount,0)*107/100,ISNULL(pcl.Amount,0))/NULLIF(DocPaid.SubTotal,0.00))*DocPaid.WHT WHT
		from CommittedCostLines ccl
		LEFT JOIN BudgetLines bl ON bl.Id = ccl.BudgetLineId
		LEFT JOIN AccountCostLines acl ON acl.CommittedCostLineId = ccl.Id AND acl.[Date] <= @Todate
		LEFT JOIN PaidCostLines pcl ON pcl.CommittedCostLineId = ccl.Id AND pcl.[Date] <= @Todate
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal, ISNULL(rt.RTAmount,0) RTAmount
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId NOT IN (47,57,59,74,107,111,123,129,131,138,176) AND isDebit = 1 GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) RTAmount FROM OtherPaymentLines WHERE GeneralAccount = 212 AND isDebit = 0 GROUP BY OtherPaymentId
					) rt ON rt.OtherPaymentId = op.Id
				where opl.guid = ccl.RefDocLineGuid AND ccl.RefDocTypeId = 43 --opl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 43

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal,0.00 RTAmount
						,wel.CalcVat,1 isDebit
				FROM workerexpenselines wel 
				LEFT JOIN ( SELECT WorkerExpenseId,SystemCategoryId VatTypeId, SystemCategory VatType FROM WorkerExpenseLines WHERE SystemCategoryId IN (123,129,131) GROUP BY WorkerExpenseId,SystemCategoryId,SystemCategory
					) vat ON vat.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
				SELECT WorkerExpenseId,SUM(Amount) WHT FROM WorkerExpenseLines WHERE SystemCategoryId IN (138) GROUP BY WorkerExpenseId
					) wht ON wht.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
					SELECT WorkerExpenseId,SUM(Amount) SubTotal FROM workerexpenselines WHERE (SystemCategoryId IS NULL OR SystemCategoryId NOT IN (138,123)) GROUP BY WorkerExpenseId
					) st ON st.WorkerExpenseId = wel.WorkerExpenseId
				WHERE wel.guid = ccl.RefDocLineGuid AND ccl.RefDocTypeId = 97--wel.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 97

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,131 VatTypeId,'NoVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal,0.00 RTAmount
						, 1 CalcVat, isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = ccl.RefDocLineGuid AND ccl.RefDocTypeId = 64 --jvl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) Doc
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal,ISNULL(rt.RTAmount,0) RTAmount
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId NOT IN (47,57,59,74,107,111,123,129,131,138,176) AND isDebit = 1 GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) RTAmount FROM OtherPaymentLines WHERE GeneralAccount = 212 AND isDebit = 0 GROUP BY OtherPaymentId
					) rt ON rt.OtherPaymentId = op.Id
				where opl.guid = acl.RefDocLineGuid AND ccl.RefDocTypeId = 43 --opl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 43

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal,0.00 RTAmount
						,wel.CalcVat,1 isDebit
				FROM workerexpenselines wel 
				LEFT JOIN ( SELECT WorkerExpenseId,SystemCategoryId VatTypeId, SystemCategory VatType FROM WorkerExpenseLines WHERE SystemCategoryId IN (123,129,131) GROUP BY WorkerExpenseId,SystemCategoryId,SystemCategory
					) vat ON vat.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
				SELECT WorkerExpenseId,SUM(Amount) WHT FROM WorkerExpenseLines WHERE SystemCategoryId IN (138) GROUP BY WorkerExpenseId
					) wht ON wht.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
					SELECT WorkerExpenseId,SUM(Amount) SubTotal FROM workerexpenselines WHERE (SystemCategoryId IS NULL OR SystemCategoryId NOT IN (138,123)) GROUP BY WorkerExpenseId
					) st ON st.WorkerExpenseId = wel.WorkerExpenseId
				WHERE wel.guid = acl.RefDocLineGuid AND ccl.RefDocTypeId = 97--wel.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 97

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,131 VatTypeId,'NoVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal,0.00 RTAmount
						, 1 CalcVat, isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = acl.RefDocLineGuid AND ccl.RefDocTypeId = 64 --jvl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) DocActual
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal,ISNULL(rt.RTAmount,0) RTAmount
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId NOT IN (47,57,59,74,107,111,123,129,131,138,176) AND isDebit = 1 GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) RTAmount FROM OtherPaymentLines WHERE GeneralAccount = 212 AND isDebit = 0 GROUP BY OtherPaymentId
					) rt ON rt.OtherPaymentId = op.Id
				where opl.guid = pcl.RefDocLineGuid AND ccl.RefDocTypeId = 43 --opl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 43 

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal,0.00 RTAmount
						,wel.CalcVat,1 isDebit
				FROM workerexpenselines wel 
				LEFT JOIN ( SELECT WorkerExpenseId,SystemCategoryId VatTypeId, SystemCategory VatType FROM WorkerExpenseLines WHERE SystemCategoryId IN (123,129,131) GROUP BY WorkerExpenseId,SystemCategoryId,SystemCategory
					) vat ON vat.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
				SELECT WorkerExpenseId,SUM(Amount) WHT FROM WorkerExpenseLines WHERE SystemCategoryId IN (138) GROUP BY WorkerExpenseId
					) wht ON wht.WorkerExpenseId = wel.WorkerExpenseId
				LEFT JOIN (
					SELECT WorkerExpenseId,SUM(Amount) SubTotal FROM workerexpenselines WHERE (SystemCategoryId IS NULL OR SystemCategoryId NOT IN (138,123)) GROUP BY WorkerExpenseId
					) st ON st.WorkerExpenseId = wel.WorkerExpenseId
				WHERE wel.guid = pcl.RefDocLineGuid AND ccl.RefDocTypeId = 97--wel.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 97

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,131 VatTypeId,'NoVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal,0.00 RTAmount
						, 1 CalcVat,isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = pcl.RefDocLineGuid AND ccl.RefDocTypeId = 64 --jvl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) DocPaid
		WHERE ccl.RefDocTypeId NOT IN (22,105)--(1,2,64,43,97)
) cost
	WHERE cost.[Date] <= @Todate AND ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = cost.LocationId)) /* OR @ProjectId is NULL */)
	option(recompile);
CREATE INDEX IX_TempCost_LocationId ON #TempCost(LocationId)
CREATE INDEX IX_TempCost_CommitLineId ON #TempCost(CommitLineId)

-- Drop the table if it already exists	
IF OBJECT_ID('tempDB..#PoRemain', 'U') IS NOT NULL
DROP TABLE #PoRemain
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT LocationId,(SUM(InvoiceTaxBase)-ISNULL(SUM(InvoiceAdjustTaxBase),0)) - ISNULL(SUM(PayTaxBase)-ISNULL(nonRef.NonRefPayAmount,0),0) PORemain
	,SUM(POAmount) POAmount,SUM(POTaxBase) POTaxBase,SUM(POTaxAmount) POTaxAmount,SUM(PODepositAmount) PODepositAmount
	,SUM(PORetentionAmount) PORetentionAmount,SUM(POWHT) POWHT
	,ISNULL(SUM(AdjustPOAmount),0) AdjustPOAmount,ISNULL(SUM(AdjustPOTaxBase),0) AdjustPOTaxBase,ISNULL(SUM(AdjustPOTaxAmount),0) AdjustPOTaxAmount
	,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
	,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount
	,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
	,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
	,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(PayTaxBase),0) PayTaxBase,ISNULL(SUM(PayTaxAmount),0) PayTaxAmount
	,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
	,ISNULL(nonRef.nonRefNetPayAmount,0) NonRefPoNetPayAmount
	,ISNULL(nonRef.NonRefPayAmount,0) NonRefPoPayAmount,ISNULL(nonRef.NonRefRetentionSetAmount,0) NonRefPoRetentionSetAmount,ISNULL(nonRef.NonRefDeductAmount,0) NonRefPoDeductAmount,ISNULL(nonRef.NonRefWHT,0) NonRefPoWHT
	INTO #PoRemain
	FROM (
		SELECT * 
		from (
			select * from #TempPo where BudgetTypeId = 99
			UNION ALL
			select * from #TempSC where BudgetTypeId = 99
		) p
		OUTER APPLY (
				select il.RefDocId2,il.RefDocCode2,il.RefDocLineId2
					,SUM(il.InvoiceAmount)InvoiceAmount,SUM(il.InvoiceTaxBase)InvoiceTaxBase,SUM(il.InvoiceTaxAmount)InvoiceTaxAmount,SUM(il.InvoiceDPAmount)InvoiceDPAmount,SUM(il.InvoiceRTAmount)InvoiceRTAmount
					,SUM(il.InvoiceAdjustAmount)InvoiceAdjustAmount,SUM(il.InvoiceAdjustTaxBase)InvoiceAdjustTaxBase,SUM(il.InvoiceAdjustTaxAmount) InvoiceAdjustTaxAmount
					,SUM(il.Invpt*CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END) PayTaxBase
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN (il.Invpt*pv.PayAmount) * 7/107
					ELSE 0 END) PayTaxAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN (
					SELECT IvId,SUM(PayAmount) PayAmount,SUM(DeductAmount) DeductAmount,SUM(RetentionSetAmount) RetentionSetAmount,SUM(WHT) WHT
					FROM #TempPV 
					GROUP BY IvId
				) pv ON il.Id = pv.IvId
				WHERE il.RefDocLineId2 = p.PolineId AND il.refdoctypeId2 = p.Doctype
				GROUP BY il.RefDocId2,il.RefDocCode2,il.RefDocLineId2
			) ilpv
		UNION ALL
		SELECT LocationId,Id,Code,Doctype,[Date],CommitLineId PolineId,BudgetTypeId,BudgetType,VatTypeId,VatType,pt
			,DPAmount PODepositAmount,RTAmount PORetentionAmount,WHT POWHT
			,CommitAmount POAmount,CommitTaxBase POTaxBase,CommitTaxAmount POTaxAmount
			,AdjustAmount AdjustPOAmount,AdjustTaxBase AdjustPOTaxBase,AdjustTaxAmount AdjustPOTaxAmount
			,RefDocId2,RefDocCode2,RefDocLineId2,InvoiceAmount,InvoiceTaxBase,InvoiceTaxAmount,InvoiceDPAmount,InvoiceRTAmount
			,InvoiceAdjustAmount,InvoiceAdjustTaxBase,InvoiceAdjustTaxAmount
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,PayTaxBase,PayTaxAmount,RetentionSetAmount,DeductAmount,WHT
		FROM #TempCost
		WHERE BudgetTypeId = 99
	) poRemain
		OUTER APPLY (
		select pcl.PaidProjectId
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) + SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefNetPayAmount
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) NonRefPayAmount
		,SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) NonRefRetentionSetAmount
		,SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) NonRefDeductAmount
		,SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefWHT 
		from #TempPV pv
		LEFT JOIN PaidCostLines pcl ON pcl.RefDocId = pv.IvID AND pv.AcsetDocTypeId = 39
		LEFT JOIN BudgetLines bl ON bl.Id = pcl.BudgetLineId
		where bl.SystemCategoryId = 99 AND pv.AcsetDoctypeID = 39 AND pcl.PaidProjectId = poRemain.LocationId
		group by pcl.PaidProjectId
	) nonRef /* มาจากเอกสาร CN ลอยที่มีการทำ PV เเละจัดสรรเข้างบที่เป็น Mat */
	GROUP BY LocationId,nonRef.NonRefNetPayAmount,nonRef.NonRefPayAmount,nonRef.NonRefRetentionSetAmount,nonRef.NonRefDeductAmount,nonRef.NonRefWHT
	option(recompile);


-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#SCRemain', 'U') IS NOT NULL
DROP TABLE #SCRemain
	-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT LocationId,(SUM(InvoiceTaxBase)-ISNULL(SUM(InvoiceAdjustTaxBase),0)) - ISNULL(SUM(PayTaxBase),0)-ISNULL(nonRef.NonRefPayAmount,0) SCRemain
		,SUM(SCAmount) SCAmount,SUM(SCTaxBase) SCTaxBase,SUM(SCTaxAmount) SCTaxAmount,SUM(SCDepositAmount) SCDepositAmount
		,SUM(SCRetentionAmount) SCRetentionAmount,SUM(SCWHT) SCWHT
		,ISNULL(SUM(AdjustSCAmount),0) AdjustSCAmount,ISNULL(SUM(AdjustSCTaxBase),0) AdjustSCTaxBase,ISNULL(SUM(AdjustSCTaxAmount),0) AdjustSCTaxAmount
		,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
		,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount
		,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
		,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
		,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(PayTaxBase),0) PayTaxBase,ISNULL(SUM(PayTaxAmount),0) PayTaxAmount
		,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
		,ISNULL(nonRef.nonRefNetPayAmount,0) NonRefScNetPayAmount
		,ISNULL(nonRef.NonRefPayAmount,0) NonRefScPayAmount,ISNULL(nonRef.NonRefRetentionSetAmount,0) NonRefScRetentionSetAmount,ISNULL(nonRef.NonRefDeductAmount,0) NonRefScDeductAmount,ISNULL(nonRef.NonRefWHT,0) NonRefScWHT
	INTO #SCRemain
	FROM (
		SELECT * 
		from (
			select * from #TempSC where BudgetTypeId = 105
			UNION ALL
			select * from #TempPo where BudgetTypeId = 105
		) p
		OUTER APPLY (
				select il.RefDocId2,il.RefDocCode2,il.RefDocLineId2
					,SUM(il.InvoiceAmount)InvoiceAmount,SUM(il.InvoiceTaxBase)InvoiceTaxBase,SUM(il.InvoiceTaxAmount)InvoiceTaxAmount,SUM(il.InvoiceDPAmount)InvoiceDPAmount,SUM(il.InvoiceRTAmount)InvoiceRTAmount
					,SUM(il.InvoiceAdjustAmount)InvoiceAdjustAmount,SUM(il.InvoiceAdjustTaxBase)InvoiceAdjustTaxBase,SUM(il.InvoiceAdjustTaxAmount) InvoiceAdjustTaxAmount
					,SUM(il.Invpt*(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END)) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN il.Invpt*pv.PayAmount * 100/107
					ELSE il.Invpt*pv.PayAmount END) PayTaxBase
					,SUM(CASE WHEN (il.VatTypeId IN (123,129) AND il.CalcVat = 1) THEN (il.Invpt*pv.PayAmount) * 7/107
					ELSE 0 END) PayTaxAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN (
					SELECT IvId,SUM(PayAmount) PayAmount,SUM(DeductAmount) DeductAmount,SUM(RetentionSetAmount) RetentionSetAmount,SUM(WHT) WHT
					FROM #TempPV 
					GROUP BY IvId
				) pv ON il.Id = pv.IvId
				WHERE il.RefDocLineId2 = p.SClineId AND il.refdoctypeId2 = p.Doctype
				GROUP BY il.RefDocId2,il.RefDocCode2,il.RefDocLineId2
			) ilpv
		UNION ALL
		SELECT LocationId,Id,Code,Doctype,[Date],CommitLineId SClineId,BudgetTypeId,BudgetType,VatTypeId,VatType,pt
			,DPAmount SCDepositAmount,RTAmount SCRetentionAmount,WHT SCWHT
			,CommitAmount SCAmount,CommitTaxBase SCTaxBase,CommitTaxAmount SCTaxAmount
			,AdjustAmount AdjustSCAmount,AdjustTaxBase AdjustSCTaxBase,AdjustTaxAmount AdjustSCTaxAmount
			,RefDocId2,RefDocCode2,RefDocLineId2,InvoiceAmount,InvoiceTaxBase,InvoiceTaxAmount,InvoiceDPAmount,InvoiceRTAmount
			,InvoiceAdjustAmount,InvoiceAdjustTaxBase,InvoiceAdjustTaxAmount
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,PayTaxBase,PayTaxAmount,RetentionSetAmount,DeductAmount,WHT
		FROM #TempCost
		WHERE BudgetTypeId = 105
	) scRemain
			OUTER APPLY (
		select pcl.PaidProjectId
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) + SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) -SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefNetPayAmount
		,SUM(pv.PayAmount * (pcl.PaidPercentAllocation / 100)) NonRefPayAmount
		,SUM(pv.RetentionSetAmount * (pcl.PaidPercentAllocation / 100)) NonRefRetentionSetAmount
		,SUM(pv.DeductAmount * (pcl.PaidPercentAllocation / 100)) NonRefDeductAmount
		,SUM(pv.WHT * (pcl.PaidPercentAllocation / 100)) NonRefWHT 
		from #TempPV pv
		LEFT JOIN PaidCostLines pcl ON pcl.RefDocId = pv.IvID AND pv.AcsetDocTypeId = 39
		LEFT JOIN BudgetLines bl ON bl.Id = pcl.BudgetLineId
		where bl.SystemCategoryId = 105 AND pv.AcsetDoctypeID = 39 AND pcl.PaidProjectId = scRemain.LocationId
		group by pcl.PaidProjectId
	) nonRef /* มาจากเอกสาร CN ลอยที่มีการทำ PV เเละจัดสรรเข้างบที่เป็น Sub */
	GROUP BY LocationId,nonRef.NonRefNetPayAmount,nonRef.NonRefPayAmount,nonRef.NonRefRetentionSetAmount,nonRef.NonRefDeductAmount,nonRef.NonRefWHT
	option(recompile);

/************************************************************************************************************************************************************************/
IF OBJECT_ID(N'tempdb..#TempInterim') IS NOT NULL
BEGIN
    DROP TABLE #TempInterim;
END;

IF OBJECT_ID(N'tempdb..#TempProjectInfo') IS NOT NULL
BEGIN
    DROP TABLE #TempProjectInfo;
END;

/*Interim Payment*/
select
	ip.Id,
	ip.Code,
	ip.OrgId,
	ip.OrgName,
	ip.ExtOrgId,
	ip.ExtOrgCode,
	ip.ExtOrgName,
	round(iif(coalesce(ip.TaxMethod,0) = 129,ip.Deposit * 100 /107,ip.Deposit),2) * isnull(ip.DocCurrencyRate,1) Deposit,
	ip.DepositRate,
	round(iif(coalesce(ip.TaxMethod,0) = 129,ip.Retention * 100 /107,ip.Retention),2)* isnull(ip.DocCurrencyRate,1) [Retention],
	ip.RetentionRate,
	ip.TaxMethod

into #TempInterim 
from dbo.InterimPayments [ip] 
where ((EXISTS (select 'org' from @OrgId ac WHERE ac.Id = ip.OrgId)) /* OR @ProjectId is NULL */)
 and ip.Status <> 'Canceled'
 
/*Project Info*/
SELECT DISTINCT ip.Id InterimId, ip.OrgId, ip.OrgName, ip.ExtOrgId, ip.ExtOrgCode, ip.ExtOrgName,o.Code,o.Name,p.ContractNO
   ,iif(coalesce(ip.TaxMethod,p.TaxType) = 129,(isnull(p.ContractAmount,0)*isnull(p.CurrencyRate,1))*100 / 107, isnull(p.ContractAmount,0)*isnull(p.CurrencyRate,1)) ContractAmount
   ,p.StartDate,p.EndDate 

INTO #TempProjectInfo
FROM #TempInterim ip
INNER JOIN dbo.Organizations o ON ip.OrgId = o.Id  
LEFT JOIN dbo.Organizations_ProjectConstruction p ON p.Id = o.Id
/************************************************************************************************************************************************************************/
/*1-core*/
SELECT o.Id,o.FinancialStatus
		,o.[Code(2)]
		,o.[Name(3)],o.Parent
		,o.OriginalContractNO
		,o.[OriginalContractAmount(4)]
		,o.VODate
		,o.[VOAmount(5)]
		,o.[CurrentContractAmount(6)]
		,o.ContractNO
		,o.[RVOriginalContract TaxBase(7)]
		,o.[RVVOContract TaxBase(8)]
		,o.[RVTotal TaxBase(9)]
		,o.[Current Budget Mat(10)]
		,o.[Current Budget Sub(11)]
		,o.[MatPay Taxbase(12)]
		,o.POInvoiceAmount,o.POInvoiceTaxBase,o.POInvoiceTaxAmount
		,o.POInvoiceDPAmount,o.POInvoiceRTAmount
		,o.POInvoiceAdjustAmount,o.POInvoiceAdjustTaxBase,o.POInvoiceAdjustTaxAmount
		,o.PayPOAmount,o.PayPOTaxBase,o.PayPOTaxAmount
		,o.PODeductAmount
		,o.PayPORetention,o.PayPOWHT
		,o.NonRefPoNetPayAmount
		,o.NonRefPoPayAmount,o.NonRefPoDeductAmount
		,o.NonRefPoRetentionSetAmount,o.NonRefPoWHT
		,o.[SupPay Taxbase(13)]
		,o.SCInvoiceAmount,o.SCInvoiceTaxBase,o.SCInvoiceTaxAmount
		,o.SCInvoiceDPAmount,o.SCInvoiceRTAmount
		,o.SCInvoiceAdjustAmount,o.SCInvoiceAdjustTaxBase,o.SCInvoiceAdjustTaxAmount
		,o.PaySCAmount,o.PaySCTaxBase,o.PaySCTaxAmount
		,o.SCDeductAmount
		,o.PaySCRetention,o.PaySCWHT
		,o.NonRefScNetPayAmount
		,o.NonRefScPayAmount,o.NonRefScDeductAmount
		,o.NonRefScRetentionSetAmount,o.NonRefScWHT
		,o.[PVTotal Taxbase(14)]
		,o.[Gross profit Taxbase(15)]
		,o.[ReMainContract Taxbase(16)]
		,o.[PORemainTaxbase(17)]
		,o.POAmount,o.POTaxBase,o.POTaxAmount
		,o.PODepositAmount,o.PORetentionAmount,o.POWHT
		,o.AdjustPOAmount,o.AdjustPOTaxBase,o.AdjustPOTaxAmount
		,o.[SCRemainTaxbase(18)]
		,o.SCAmount,o.SCTaxBase,o.SCTaxAmount
		,o.SCDepositAmount,o.SCRetentionAmount,o.SCWHT
		,o.AdjustSCAmount,o.AdjustSCTaxBase,o.AdjustSCTaxAmount
		,o.[TotalRemainTaxbase(19)]
		,o.[BudgetRemainMat(20)]
		,o.[BudgetRemainSub(21)]
		,o.[BudgetRemain(22)]
		,o.[EstCostPaidTaxbase(23)]
		,o.[Est Gross profit Taxbase(24)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit Taxbase(25)]),'%') [% Est Gross profit Taxbase(25)] 
		,o.[JvAmount Taxbase(26)]
		,o.[Est Gross profit and loss minus internal rent(27)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit and loss minus internal rent(28)]),'%') [% Est Gross profit and loss minus internal rent(28)]

FROM(

	select	org.Id,orgP.FinancialStatus
		,org.Code [Code(2)] /*(2)*/
		,org.Name [Name(3)]/*(2)*/,org.Parent
		,orgP.ContractNO [OriginalContractNO] 
		--,(ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(ir.IrTaxBase,0) [OriginalContractAmount(4)] /*(4)*/
		,ISNULL(pn.ContractAmount,0) [OriginalContractAmount(4)] /*New*/
		,pvo.VOcontractdate [VODate]
		,ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0) [VOAmount(5)] /*(5)*/
		--,(ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)+ ISNULL(ir.IrTaxBase,0) +ISNULL(irv.IrVoTaxBase,0) [CurrentContractAmount(6)]  /*(6) = (4)+(5)*/
		,ISNULL(pn.ContractAmount,0) + (ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0)) [CurrentContractAmount(6)] /*New*/
		,m.ContractNO

		--,ISNULL(m.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/
		,ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/

		--,ISNULL(s.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/
		,ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/

		--,(ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/

		,ISNULL(BRMat.BlMatAmount,0) [Current Budget Mat(10)] /*(10)*/
		,ISNULL(BRSub.BlSubAmount,0) [Current Budget Sub(11)] /*(11)*/
		,ISNULL(po.PayTaxBase,0) [MatPay Taxbase(12)] /*(12)*/
		,ISNULL(po.InvoiceAmount,0) POInvoiceAmount,ISNULL(po.InvoiceTaxBase,0) POInvoiceTaxBase,ISNULL(po.InvoiceTaxAmount,0) POInvoiceTaxAmount
		,ISNULL(po.InvoiceDPAmount,0) POInvoiceDPAmount,ISNULL(po.InvoiceRTAmount,0) POInvoiceRTAmount
		,ISNULL(po.InvoiceAdjustAmount,0) POInvoiceAdjustAmount,ISNULL(po.InvoiceAdjustTaxBase,0) POInvoiceAdjustTaxBase,ISNULL(po.InvoiceAdjustTaxAmount,0) POInvoiceAdjustTaxAmount
		,ISNULL(po.PayAmount,0) PayPOAmount,ISNULL(po.PayTaxBase,0) PayPOTaxBase,ISNULL(po.PayTaxAmount,0) PayPOTaxAmount
		,ISNULL(po.DeductAmount,0) PODeductAmount
		,ISNULL(po.RetentionSetAmount,0) PayPORetention,ISNULL(po.WHT,0) PayPOWHT
		,isnull(po.NonRefPoNetPayAmount,0) NonRefPoNetPayAmount
		,ISNULL(po.NonRefPoPayAmount,0) NonRefPoPayAmount,ISNULL(po.NonRefPoDeductAmount,0) NonRefPoDeductAmount
		,ISNULL(po.NonRefPoRetentionSetAmount,0) NonRefPoRetentionSetAmount,ISNULL(po.NonRefPoWHT,0) NonRefPoWHT
		,ISNULL(sc.PayTaxBase,0) [SupPay Taxbase(13)] /*(13)*/
		,ISNULL(sc.InvoiceAmount,0) SCInvoiceAmount,ISNULL(sc.InvoiceTaxBase,0) SCInvoiceTaxBase,ISNULL(sc.InvoiceTaxAmount,0) SCInvoiceTaxAmount
		,ISNULL(sc.InvoiceDPAmount,0) SCInvoiceDPAmount,ISNULL(sc.InvoiceRTAmount,0) SCInvoiceRTAmount
		,ISNULL(sc.InvoiceAdjustAmount,0) SCInvoiceAdjustAmount,ISNULL(sc.InvoiceAdjustTaxBase,0) SCInvoiceAdjustTaxBase,ISNULL(sc.InvoiceAdjustTaxAmount,0) SCInvoiceAdjustTaxAmount
		,ISNULL(sc.PayAmount,0) PaySCAmount,ISNULL(sc.PayTaxBase,0) PaySCTaxBase,ISNULL(sc.PayTaxAmount,0) PaySCTaxAmount
		,ISNULL(sc.DeductAmount,0) SCDeductAmount
		,ISNULL(sc.RetentionSetAmount,0) PaySCRetention,ISNULL(sc.WHT,0) PaySCWHT
		,ISNULL(sc.NonRefScNetPayAmount,0) NonRefScNetPayAmount
		,ISNULL(sc.NonRefScPayAmount,0) NonRefScPayAmount,ISNULL(sc.NonRefScDeductAmount,0) NonRefScDeductAmount
		,ISNULL(sc.NonRefScRetentionSetAmount,0) NonRefScRetentionSetAmount,ISNULL(sc.NonRefScWHT,0) NonRefScWHT
		,ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0) [PVTotal Taxbase(14)]  /*(14) = (12)+(13)*/

		--,((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/

		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0))) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)+ ISNULL(ir.IrTaxBase,0) +ISNULL(irv.IrVoTaxBase,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		,(ISNULL(pn.ContractAmount,0) + (ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0))) - 
		 ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) [ReMainContract Taxbase(16)] /*New*/

		,ISNULL(po.PORemain,0) [PORemainTaxbase(17)] /*(17)*/
		,ISNULL(po.POAmount,0) POAmount,ISNULL(po.POTaxBase,0) POTaxBase,ISNULL(po.POTaxAmount,0) POTaxAmount
		,ISNULL(po.PODepositAmount,0) PODepositAmount,ISNULL(po.PORetentionAmount,0) PORetentionAmount,ISNULL(po.POWHT,0) POWHT
		,ISNULL(po.AdjustPOAmount,0) AdjustPOAmount,ISNULL(po.AdjustPOTaxBase,0) AdjustPOTaxBase,ISNULL(po.AdjustPOTaxAmount,0) AdjustPOTaxAmount
		,ISNULL(sc.SCRemain,0) [SCRemainTaxbase(18)] /*(18)*/
		,ISNULL(sc.SCAmount,0) SCAmount,ISNULL(sc.SCTaxBase,0) SCTaxBase,ISNULL(sc.SCTaxAmount,0) SCTaxAmount
		,ISNULL(sc.SCDepositAmount,0) SCDepositAmount,ISNULL(sc.SCRetentionAmount,0) SCRetentionAmount,ISNULL(sc.SCWHT,0) SCWHT
		,ISNULL(sc.AdjustSCAmount,0) AdjustSCAmount,ISNULL(sc.AdjustSCTaxBase,0) AdjustSCTaxBase,ISNULL(sc.AdjustSCTaxAmount,0) AdjustSCTaxAmount
		,ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0) [TotalRemainTaxbase(19)] /*(19)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) [BudgetRemainMat(20)] /*(20)*/
		,ISNULL(BRMat.BudgetRemainMat,0) /* - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.ActualTaxbase,0) */ [BudgetRemainMat(20)] /*(20) = (10)-(12)-(17)*/

		--,ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemainSub(21)] /*(21)*/
		,ISNULL(BRSub.BudgetRemainSub,0) /* - ISNULL(sp.SCTaxbase,0) - ISNULL(SCRemain.ActualTaxbase,0) */ [BudgetRemainSub(21)] /*(21) = (11)-(13)-(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemain(22)] /*(22) = (20)+(21)*/
		,ISNULL(BRMat.BudgetRemainMat,0) /* - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.ActualTaxbase,0) */ /*(20)*/
		 + ISNULL(BRSub.BudgetRemainSub,0) /* - ISNULL(sp.SCTaxbase,0) - ISNULL(SCRemain.ActualTaxbase,0) */ /*(21)*/
		 [BudgetRemain(22)] /*(22) = (20)+(21)*/

		--,ISNULL((ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0)) + (BRMat.BudgetRemainMat + BRSub.BudgetRemainSub),0) [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/
		,(ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))  /*(19)*/
		  +(ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0)) /*(22)*/
		  [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/


		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--		+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--		+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/

		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) )) /*(23)*/ 
			[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/


		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--	  ELSE	ROUND(ISNULL((((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) /*(6)*/
		--			/ ((((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0)))  /*(15)*/
		--			+ ((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) ,0),2)/*(23)*/ 
		--	END [% Est Gross profit Taxbase(25)] /*(25) = (6) / ((15)+(16)-(23))*/

		,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
			  ELSE	ROUND(ISNULL(
								(( (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))) /*(15)*/
			+ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) /*(16)*/
			- ( (ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0))
				+ ( (ISNULL(BRMat.BudgetRemainMat,0) ) 
				+ (ISNULL(BRSub.BudgetRemainSub,0)) ))) /*(23)*/
							/ ((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) ,0),2)/*(6)*/
			END [% Est Gross profit Taxbase(25)] /*(25) = (24) / (6) */


		,ISNULL(jl.JvAmount,0) [JvAmount Taxbase(26)] /*(26)*/

		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	- ISNULL(jl.JvAmount,0) /*(26)*/
		--      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/

		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))))
		--+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)+ ISNULL(ir.IrTaxBase,0) +ISNULL(irv.IrVoTaxBase,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))))
		--- ((ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0)) + (ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0))) -ISNULL(jl.JvAmount,0)
		--      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/
		
		,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0)))) +
		 (ISNULL(pn.ContractAmount,0) + (ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0))) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) -
		 ((ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0)) + (ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0))) [Est Gross profit and loss minus internal rent(27)] /*New*/
		
		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--		ELSE ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) /*(6)*/
		--			/ ( (((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--			+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--			- ISNULL(jl.JvAmount,0) )  /*(26)*/
		--		END [% Est Gross profit and loss minus internal rent(28)] /*(28) = (6) / (15)+(16)-(23)-(26)*/

		--,ISNULL((((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0))))
		--+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)+ ISNULL(ir.IrTaxBase,0) +ISNULL(irv.IrVoTaxBase,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))))
		--- ((ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0)) + (ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0))) -ISNULL(jl.JvAmount,0))/NULLIF(((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)+ ISNULL(ir.IrTaxBase,0) +ISNULL(irv.IrVoTaxBase,0)),0),0)
		--		[% Est Gross profit and loss minus internal rent(28)] /*(28)*/

		,NULLIF((ISNULL(pn.ContractAmount,0) + (ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0))),0) /
		 (((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(po.PayTaxBase,0) + ISNULL(sc.PayTaxBase,0)))) +
		 (ISNULL(pn.ContractAmount,0) + (ISNULL(pvo.VOSUM,0) + ISNULL(irv.IrVoTaxBase,0))) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) -
		 ((ISNULL(po.PORemain,0) + ISNULL(sc.SCRemain,0)) + (ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0)))) [% Est Gross profit and loss minus internal rent(28)] /*New*/
				
from	Organizations org
LEFT JOIN #TempProjectInfo pn On pn.OrgId = org.Id
left join Organizations_ProjectConstruction orgP on org.Id = orgP.id
left join (	select SUM(isnull(ContractAmount,0)* 100 / 107) VOSUM,
						max(ContractDate) VOcontractdate,
						pv.ProjectConstructionId 
						from ProjectVOes pv
						where ContractDate <= @Todate
						group by pv.ProjectConstructionId
						)pvo on pvo.ProjectConstructionId = org.id
/*รายได้สัญญาณหลักรับแล้ว*/
left join (select orgP.Id,orgP.ContractNO
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from Organizations_ProjectConstruction orgP
			left join TaxItemLines tl on orgP.ContractNO = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by orgP.Id,orgP.ContractNO
			) m on org.Id = m.Id
/*รายได้สัญญาณ VO รับแล้ว*/
left join (select vo.ProjectConstructionId--,vo.Code
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from ProjectVOes vo
			left join TaxItemLines tl on vo.Code = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by vo.ProjectConstructionId
			) s on org.Id = s.ProjectConstructionId
/*จ่ายอุปกรณ์*/
left join #PoRemain po on org.Id = po.LocationId
/*จ่ายค่าแรง*/
left join #SCRemain sc on org.Id = sc.LocationId

/*BudgetMatRemain*/
left join (select bm.ProjectId,bm.Date,bm.BlMatAmount,bm.UseMatAmount,bm.BlMatAmount - bm.UseMatAmount - ISNULL(reAlloc.remainAmount,0)  [BudgetRemainMat]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlMatAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseMatAmount
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.AccountProjectId Orgid,c.BudgetLineId,sum(c.Amount) Amount
								from AccountCostLines c
                                                                where c.AccountProjectId is not null
                                                                          and Date <= @Todate
								group by c.AccountProjectId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 99
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bm 
					OUTER APPLY (
						SELECT cal.CostAllocateProjectId,SUM(cal.Amount) remainAmount
						FROM CostAllocationLines cal
						WHERE cal.IsAllocated = 0 AND cal.CostAllocateProjectId = bm.ProjectId AND cal.RefDocDate <= @Todate AND cal.RefDocTypeId = 37
						GROUP BY cal.CostAllocateProjectId
					) reAlloc 
			)BRMat on org.Id = BRMat.ProjectId
/*BudgetSubRemain*/
left join (select bs.ProjectId,bs.Date,bs.BlSubAmount,bs.UseSubAmount,bs.BlSubAmount - bs.UseSubAmount - ISNULL(reAlloc.remainAmount,0)  [BudgetRemainSub]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlSubAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseSubAmount
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.AccountProjectId OrgId,c.BudgetLineId,sum(c.Amount) Amount
								from AccountCostLines c
								where c.AccountProjectId is not null
                                                                          and Date <= @Todate
								group by c.AccountProjectId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 105
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bs
					OUTER APPLY (
						SELECT cal.CostAllocateProjectId,SUM(cal.Amount) remainAmount
						FROM CostAllocationLines cal
						WHERE cal.IsAllocated = 0 AND cal.CostAllocateProjectId = bs.ProjectId AND cal.RefDocDate <= @Todate AND cal.RefDocTypeId = 213
						GROUP BY cal.CostAllocateProjectId
					) reAlloc 
			)BRSub on org.Id = BRSub.ProjectId
/*JV 41000716 : รายได้ค่าเช่าภายใน*/
left join (select jl.OrgId,sum(isnull(jl.Amount,0)) JvAmount
			from JVLines jl
                        left join JournalVouchers j on j.Id = jl.JournalVoucherId
			where j.Date  <= @Todate
                                        and jl.AccountCode in (41000716)
					and jl.isDebit = 1
			group by jl.OrgId
			) jl on org.Id = jl.OrgId

/*Interrim BF*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrTaxBase
					,sum(irl.TaxAmount) IrTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO = irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) ir on org.Id = ir.OrgId
/*Interrim BF VO*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrVoTaxBase
					,sum(irl.TaxAmount) IrVoTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrVoAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO <> irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) irv on org.Id = irv.OrgId
/*BF OR*/
left join (select ac.OrgId,ac.OrgCode
					,sum(orl.Amount*100/107) BFTaxbase
					,sum(orl.Amount) BFAmount
			from AcctElementSets ac
			inner join OtherReceiveLines orl on ac.DocCode = orl.RefDocCode
			where ac.DocTypeId = 149 and ac.AccountCode = '11130101'
					and orl.SystemCategory = 'SetUpAcctBalFwd' and orl.isDebit = 0
			group by ac.OrgId,ac.OrgCode
			) ac on org.Id = ac.OrgId
/*รายได้สัญญาณหลักรับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORMAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) orm on org.Id = orm.LocationId

/*รายได้สัญญาณ VO รับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORVAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) ors on org.Id = ors.LocationId
where (exists (select 1 from @OrgId a where org.Id = a.Id) /* or @ProjectId is null */)
)o 
WHERE (@Status IS NOT NULL AND o.FinancialStatus = @Status) OR (@Status IS NULL)
order by o.Parent,o.FinancialStatus,o.[Code(2)]
/************************************************************************************************************************************************************************/

/*2-Filter*/
select @Todate [As Of Date]
		--,@ProjectId
		,(SELECT dbo.GROUP_CONCAT(code)  FROM dbo.Organizations WHERE Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) Project
		,IIF(@IncChild = 1,'Include Child','NO') IncChild

/************************************************************************************************************************************************************************/

/*3-Company*/
select * from fn_CompanyInfoTable(@ProjectId)

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPo', 'U') IS NOT NULL
DROP TABLE #TempPo
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempSC', 'U') IS NOT NULL
DROP TABLE #TempSC
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempInvoice', 'U') IS NOT NULL
DROP TABLE #TempInvoice
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempPV', 'U') IS NOT NULL
DROP TABLE #TempPV
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempCost', 'U') IS NOT NULL
DROP TABLE #TempCost

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#PoRemain', 'U') IS NOT NULL
DROP TABLE #PoRemain
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#SCRemain', 'U') IS NOT NULL
DROP TABLE #SCRemain