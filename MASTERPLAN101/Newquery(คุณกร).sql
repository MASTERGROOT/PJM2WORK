DECLARE @p0 DATETIME = '2025-08-05'
DECLARE @p1 nvarchar(500) = '204'--'1931'--'1107,1152' --''--
DECLARE @p2 BIT = 0

DECLARE @Todate DATETIME = @p0
DECLARE @ProjectId nvarchar(500) = @p1
DECLARE @IncChild BIT = @p2


/************************************************************************************************************************************************************************/
DECLARE @OrgId TABLE (Id int not null);

INSERT INTO @OrgId(Id)     /*Save More OrgId Or Single OrgId Not Include Child to Temp.*/
            
            SELECT   distinct orgD.ChildrenId       
            FROM   dbo.fn_organizationDepends() orgD
			where (@incChild = 1 and orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)))
			or (isnull(@incChild,0) = 0 and  orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)) and orgD.OrgId = orgD.ChildrenId)

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
			,IIF((vat.VatTypeId = 123 AND pl.CalcVat = 1),ISNULL(pl.Amount-pl.SpecialDiscount,0)*107/100,ISNULL(pl.Amount-pl.SpecialDiscount,0)) AS POAmount
			,CASE WHEN (vat.VatTypeId = 129 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount,0)*100/107
				WHEN (vat.VatTypeId = 123 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount,0)
				ELSE ISNULL(pl.Amount-pl.SpecialDiscount,0)
			END POTaxBase
			,CASE WHEN (vat.VatTypeId = 129 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount,0)*7/107
				WHEN (vat.VatTypeId = 123 AND pl.CalcVat = 1) THEN ISNULL(pl.Amount-pl.SpecialDiscount,0) * 7/100
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
			FROM AdjustPOLines apl
			LEFT JOIN (
				select AdjustPOId,SystemCategoryId VatTypeId,SystemCategory VatType from AdjustPOLines where SystemCategoryId IN (123,129,131) GROUP BY AdjustPOId,SystemCategoryId,SystemCategory
			) adjvat ON adjvat.AdjustPOId = apl.AdjustPOId
			WHERE pl.Id = apl.POLineId AND p.Id = apl.POId
			) adjPo 
		WHERE p.DocStatus not in (-1) 
								and pl.SystemCategoryId IN (99,100,105) 
	) po
	WHERE po.Date <= @Todate and po.LocationId IN (select ncode from dbo.fn_listCode(@ProjectId))
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
		SELECT sc.LocationId,sc.Id,sc.Code,105 DocType,sc.[Date],scl.Id SCLineId,ISNULL(bl.SystemCategoryId,99) BudgetTypeId,ISNULL(bl.SystemCategory,'SubContract') BudgetType,vat.VatTypeId,vat.VatType
		,scl.Amount/sc.SubTotal pt,(scl.Amount/sc.SubTotal)*sc.DepositAmount SCDepositAmount,(scl.Amount/sc.SubTotal)*sc.RetentionAmount SCRetentionAmount,(scl.Amount/sc.SubTotal)*sc.WHTAmount SCWHT
				,IIF(vat.VatTypeId = 123,ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)*107/100,ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)) AS SCAmount
				,CASE WHEN vat.VatTypeId = 129 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)*100/107
				WHEN vat.VatTypeId = 123 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)
				ELSE ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)
			END SCTaxBase
			,CASE WHEN vat.VatTypeId = 129 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount,0)*7/107
				WHEN vat.VatTypeId = 123 THEN ISNULL(scl.Amount-scl.SpecialDiscountAmount,0) * 7/100
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
			FROM VariationOrderLines vol
			LEFT JOIN (
				select VariationOrderId,SystemCategoryId VatTypeId,SystemCategory VatType from VariationOrderLines where SystemCategoryId IN (123,129,131) GROUP BY VariationOrderId,SystemCategoryId,SystemCategory
			) volvat ON volvat.VariationOrderId = vol.VariationOrderId
			WHERE scl.Id = vol.RefDocLineId AND scl.SubContractId = vol.RefDocId
		) vo
		WHERE sc.DocStatus != -1 AND scl.SystemCategoryId IN (99,100,105) --AND sc.Id = 6755--1027
	) sc
	WHERE sc.[Date] <= @Todate AND sc.LocationId IN (select ncode from dbo.fn_listCode(@ProjectId))
	option(recompile);

	CREATE INDEX IX_TempSC_LocationId ON #TempSC(LocationId)
	CREATE INDEX IX_TempSC_SCLineId ON #TempSC(SCLineId)




-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#TempInvoice', 'U') IS NOT NULL
DROP TABLE #TempInvoice
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

	SELECT *
	INTO #TempInvoice
	FROM (
		SELECT i.Id,i.Code,il.RefDocId2,il.RefDocCode2,il.RefDocTypeId2,il.RefDocType2,bl.SystemCategoryId BudgetTypeId,bl.SystemCategory BudgetType
				,ISNULL(il.RefDocLineId2,pal.RefDocLineId)RefDocLineId2,vat.VatTypeId,vat.VatType
				,pt.Invpt
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount)*107/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) ,0)
					ELSE ISNULL((il.Amount - il.SpecialDiscount) ,0) END InvoiceAmount
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL(il.Amount - il.SpecialDiscount,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 100/107,0)
					ELSE ISNULL(il.Amount - il.SpecialDiscount,0) END InvoiceTaxBase
				,CASE WHEN (vat.VatTypeId = 123 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/100,0)
					WHEN (vat.VatTypeId = 129 AND il.CalcVat = 1) THEN ISNULL((il.Amount - il.SpecialDiscount) * 7/107,0)
					ELSE 0 END InvoiceTaxAmount

				,ISNULL(dp.DPAmount,0) * pt.Invpt InvoiceDPAmount
				,ISNULL(dp.DPTaxbase,0) * pt.Invpt InvoiceDPTaxbase
				,ISNULL(dp.DPTaxAmount,0) * pt.Invpt InvoiceDPTaxAmount 
				,ISNULL(rt.RTAmount,0) * pt.Invpt InvoiceRTAmount
				,ISNULL(cn.InvoiceAdjustAmount,0) * pt.Invpt InvoiceAdjustAmount
				,ISNULL(cn.InvoiceAdjustTaxBase,0) * pt.Invpt InvoiceAdjustTaxBase
				,ISNULL(cn.InvoiceAdjustTaxAmount,0) * pt.Invpt InvoiceAdjustTaxAmount
		FROM Invoices i
		left join InvoiceLines il on i.Id = il.InvoiceId
		LEFT JOIN AccountCostLines acl ON acl.RefdoclineId = il.Id AND acl.RefDocTypeId IN (37,213)
		LEFT JOIN Budgetlines bl ON bl.Id = acl.BudgetLineId
		LEFT JOIN ProgressAcceptanceLines pal ON pal.Id = il.RefDocLineId AND pal.ProgressAcceptanceId = il.refdocid AND il.RefDocTypeId IN (209,210)
		LEFT JOIN (
			SELECT Id InvLineId,NULLIF((ISNULL(Amount,0)/ SUM(CASE WHEN SystemCategoryId IN (99,100,105) THEN Amount END)
				OVER (PARTITION BY invoiceid)),0) Invpt from InvoiceLines where SystemCategoryId IN (99,100,105)
		) pt ON pt.InvLineId = il.Id
		LEFT JOIN (
			select InvoiceId,SUM(Amount) DPAmount,SUM(TaxBase) DPTaxbase,SUM(TaxAmount) DPTaxAmount from InvoiceLines where SystemCategoryId = 54 GROUP BY InvoiceId
		) dp ON i.Id = dp.InvoiceId
		LEFT JOIN (
			select InvoiceId,SUM(Amount) RTAmount from InvoiceLines where SystemCategoryId = 48 GROUP BY InvoiceId
		) rt ON i.Id = rt.InvoiceId
		LEFT JOIN (
			select InvoiceId,SystemCategoryId VatTypeId,SystemCategory VatType from InvoiceLines where SystemCategoryId IN (123,129,131) GROUP BY InvoiceId,SystemCategoryId,SystemCategory
		) vat ON i.Id = vat.InvoiceId
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
			where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1) AND cl.RefDocTypeId = 37
			group by c.Id,cl.RefDocId,cl.RefDocCode,c.DocType,c.DocTypeId
		) cn ON cn.RefDocId = i.Id
		WHERE il.SystemCategoryId IN (99,100,105) and i.DocStatus not in (-1) --AND il.refdocid2 IN (select distinct id from #TempPo)
	) il
	option(recompile);
	CREATE INDEX IX_TempInvoice_RefDocLineId2 ON #TempInvoice(RefDocLineId2)
	CREATE INDEX IX_TempInvoice_Id ON #TempInvoice(Id)
	CREATE INDEX IX_TempInvoice_RefDocTypeId2 ON #TempInvoice(RefDocTypeId2)

-- select * from #TempInvoice where refdocId2 IS NULL--refdoctypeId2 = 22 AND BudgetTypeId = 105


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
				,IIF(pl.DocTypeId IN (39,40),(pvcn.AdjustAmount/ISNULL(pl.PayAmount,0))*ISNULL(pl.PayAmount,0),ISNULL(pl.PayAmount,0)) PayAmount
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
		where pl.SystemCategoryId IN (37,39,40,44,50,147,149,213,142) AND p.DocStatus NOT IN (-1) --and pl.PaymentId IN (1995)
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
				,IIF(ccl.RefDocTypeId = 64,1.00,NULLIF(ccl.Amount/Doc.SubTotal,0.00)) pt,0.00 DPAmount,0.00 RTAmount,IIF(ccl.RefDocTypeId = 64,1.00,NULLIF(ccl.Amount/Doc.SubTotal,0.00))*Doc.WHT CommitWHT
				,IIF((doc.VatTypeId = 123 AND doc.CalcVat = 1),ISNULL(ccl.Amount,0)*107/100,ISNULL(ccl.Amount,0)) * IIF(Doc.isDebit = 1,1,-1)  AS CommitAmount
				,CASE WHEN (Doc.VatTypeId = 129 AND Doc.CalcVat = 1) THEN ISNULL(ccl.Amount,0)*100/107 
						WHEN (Doc.VatTypeId = 123 AND Doc.CalcVat = 1) THEN ISNULL(ccl.Amount,0)
						ELSE 0
					END * IIF(Doc.isDebit = 1,1,-1) CommitTaxBase
					,CASE WHEN (Doc.VatTypeId = 129 AND Doc.CalcVat = 1) THEN ISNULL(ccl.Amount,0)*7/107
						WHEN (Doc.VatTypeId = 123 AND Doc.CalcVat = 1) THEN ISNULL(ccl.Amount,0) * 7/100
						ELSE 0
					END * IIF(Doc.isDebit = 1,1,-1) CommitTaxAmount
				,0.00 AdjustAmount,0.00 AdjustTaxBase,0.00 AdjustTaxAmount,NULL RefDocId2,CAST(NULL AS NVARCHAR(20)) RefDocCode2,NULL RefDocLineId2,0.00 InvoiceAmount,0.00 InvoiceTaxBase,0.00 InvoiceTaxAmount,0.00 InvoiceDPAmount,0.00 InvoiceRTAmount
				,0.00 InvoiceAdjustAmount,0.00 InvoiceAdjustTaxBase,0.00 InvoiceAdjustTaxAmount
				,pcl.Amount * IIF(DocPaid.isDebit = 1,1,-1) PayAmount, 0.00 RetentionSetAmount, IIF(pcl.RefDocTypeId = 64,1.00,NULLIF(pcl.Amount/DocPaid.SubTotal,0.00))*DocPaid.DeductAmount DeductAmount, IIF(pcl.RefDocTypeId = 64,1.00,NULLIF(pcl.Amount/DocPaid.SubTotal,0.00))*DocPaid.WHT WHT
		from CommittedCostLines ccl
		LEFT JOIN BudgetLines bl ON bl.Id = ccl.BudgetLineId
		LEFT JOIN PaidCostLines pcl ON pcl.CommittedCostLineId = ccl.Id
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (107) GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				where opl.guid = ccl.RefDocLineGuid --opl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 43 

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal
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
				WHERE wel.guid = ccl.RefDocLineGuid --wel.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,129 VatTypeId,'IncVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal
						, 1 CalcVat, isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = ccl.RefDocLineGuid --jvl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) Doc
		OUTER APPLY (
			SELECT op.Id DocId,opl.Id DocLineId,opl.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(op.WhtAmount,0) WHT,ISNULL(dd.DeductAmount,0) DeductAmount,ISNULL(st.StAmount,0) SubTotal
					,opl.CalcVat,isDebit
				from OtherPayments op
				LEFT JOIN OtherPaymentLines opl ON opl.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SystemCategoryId VatTypeId, SystemCategory VatType FROM OtherPaymentLines WHERE SystemCategoryId IN (123,129,131) GROUP BY OtherPaymentId,SystemCategoryId,SystemCategory
					) vat ON vat.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) DeductAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (176) GROUP BY OtherPaymentId
					) dd ON dd.OtherPaymentId = op.Id
				LEFT JOIN ( SELECT OtherPaymentId,SUM(Amount) STAmount FROM OtherPaymentLines WHERE SystemCategoryId IN (107) GROUP BY OtherPaymentId
					) st ON st.OtherPaymentId = op.Id
				where opl.guid = pcl.RefDocLineGuid--opl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 43 

				UNION ALL

				SELECT wel.WorkerExpenseId DocId,wel.Id DocLineId,wel.guid,ISNULL(vat.VatTypeId,131) VatTypeId,ISNULL(vat.VatType,'NoVat') VatType,ISNULL(wht.WHT,0) WHT,0.00 DeductAmount,ISNULL(st.SubTotal,0) SubTotal
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
				WHERE wel.guid = pcl.RefDocLineGuid--wel.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64

				UNION ALL

				SELECT jvl.JournalVoucherId DocId ,jvl.Id DocLineId,jvl.guid,129 VatTypeId,'IncVat' VatType,0.00 WHT,0.00 DeductAmount,0.00 SubTotal
						, 1 CalcVat,isDebit
				FROM journalvouchers jv
				LEFT JOIN JVLines jvl ON jv.Id = jvl.JournalVoucherId
				WHERE jvl.guid = pcl.RefDocLineGuid--jvl.Id = ccl.RefDocLineId AND ccl.RefDocTypeId = 64 AND jvl.IsDebit = 1
		) DocPaid
		WHERE ccl.RefDocTypeId IN (64,43,97)
) cost
	WHERE cost.[Date] <= @Todate AND cost.LocationId IN (select ncode from dbo.fn_listCode(@ProjectId))
	option(recompile);
CREATE INDEX IX_TempCost_LocationId ON #TempCost(LocationId)
CREATE INDEX IX_TempCost_CommitLineId ON #TempCost(CommitLineId)


-- Drop the table if it already exists	
IF OBJECT_ID('tempDB..#PoRemain', 'U') IS NOT NULL
DROP TABLE #PoRemain
-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'
	SELECT LocationId,(SUM(POAmount)-ISNULL(SUM(AdjustPOAmount),0)-ISNULL(SUM(InvoiceAdjustAmount),0)) - ISNULL(SUM(PayAmount)-ISNULL(nonRef.NonRefPayAmount,0),0) PORemain
	,SUM(POAmount) POAmount,SUM(POTaxBase) POTaxBase,SUM(POTaxAmount) POTaxAmount,SUM(PODepositAmount) PODepositAmount
	,SUM(PORetentionAmount) PORetentionAmount,SUM(POWHT) POWHT
	,ISNULL(SUM(AdjustPOAmount),0) AdjustPOAmount,ISNULL(SUM(AdjustPOTaxBase),0) AdjustPOTaxBase,ISNULL(SUM(AdjustPOTaxAmount),0) AdjustPOTaxAmount
	,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
	,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount
	,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
	,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
	,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
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
					,SUM(il.Invpt*pv.PayAmount) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN #TempPV pv ON il.Id = pv.IvId
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
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,RetentionSetAmount,DeductAmount,WHT
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
	SELECT LocationId,(SUM(SCAmount)-ISNULL(SUM(AdjustSCAmount),0)-ISNULL(SUM(InvoiceAdjustAmount),0)) - ISNULL(SUM(PayAmount),0)-ISNULL(nonRef.NonRefPayAmount,0) SCRemain
		,SUM(SCAmount) SCAmount,SUM(SCTaxBase) SCTaxBase,SUM(SCTaxAmount) SCTaxAmount,SUM(SCDepositAmount) SCDepositAmount
		,SUM(SCRetentionAmount) SCRetentionAmount,SUM(SCWHT) SCWHT
		,ISNULL(SUM(AdjustSCAmount),0) AdjustSCAmount,ISNULL(SUM(AdjustSCTaxBase),0) AdjustSCTaxBase,ISNULL(SUM(AdjustSCTaxAmount),0) AdjustSCTaxAmount
		,ISNULL(SUM(InvoiceAmount),0) InvoiceAmount,ISNULL(SUM(InvoiceTaxBase),0) InvoiceTaxBase,ISNULL(SUM(InvoiceTaxAmount),0) InvoiceTaxAmount
		,ISNULL(SUM(InvoiceDPAmount),0) InvoiceDPAmount,ISNULL(SUM(InvoiceRTAmount),0) InvoiceRTAmount
		,ISNULL(SUM(InvoiceAdjustAmount),0) InvoiceAdjustAmount,ISNULL(SUM(InvoiceAdjustTaxBase),0) InvoiceAdjustTaxBase,ISNULL(SUM(InvoiceAdjustTaxAmount),0) InvoiceAdjustTaxAmount
		,ISNULL(SUM(NetPayAmount),0) + (ISNULL(nonRef.NonRefPayAmount,0)+ISNULL(nonRef.NonRefDeductAmount,0)-ISNULL(nonRef.NonRefRetentionSetAmount,0)-ISNULL(nonRef.NonRefWHT,0)) NetPayAmount
		,ISNULL(SUM(PayAmount),0) PayAmount,ISNULL(SUM(RetentionSetAmount),0) RetentionSetAmount,ISNULL(SUM(DeductAmount),0) DeductAmount,ISNULL(SUM(WHT),0) WHT
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
					,SUM(il.Invpt*pv.PayAmount) + SUM(il.Invpt*pv.DeductAmount) - SUM(il.Invpt*pv.RetentionSetAmount) - SUM(il.Invpt*pv.WHT) NetPayAmount
					,SUM(il.Invpt*pv.PayAmount) PayAmount
					,SUM(il.Invpt*pv.RetentionSetAmount) RetentionSetAmount,SUM(il.Invpt*pv.DeductAmount) DeductAmount
					,SUM(il.Invpt*pv.WHT) WHT
				from #TempInvoice il
				LEFT JOIN #TempPV pv ON il.Id = pv.IvId
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
			,PayAmount + DeductAmount - RetentionSetAmount - WHT [NetPayAmount],PayAmount,RetentionSetAmount,DeductAmount,WHT
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

-- select * from #TempInvoice where refdocId2 = 6752
select * from #TempPV where IvId  = 12125

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

/*#Tempbudget*/
IF OBJECT_ID(N'tempdb..#Tempbudget') IS NOT NULL
BEGIN
    DROP TABLE #Tempbudget;
END;