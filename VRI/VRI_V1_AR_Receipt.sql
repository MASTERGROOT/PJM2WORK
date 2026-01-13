/*  form   : AR_RE
	Rev.   : JEY.11.04.2018
	Rev.V2 : BANK.28.11.2018
*/

DECLARE @p0 NUMERIC(18) = 23
DECLARE @p1 NUMERIC(18) = 51 /*44 : OtherReceives | 51 : Receipt | 151 : TaxInvoice&Receive*/

DECLARE @DocId NUMERIC(18) = @p0
DECLARE @TypeId NUMERIC(18) = @p1


DECLARE @DocOrgid INT = (case when @TypeId = 44 then (select Locationid from dbo.otherreceives where id = @docid)
						   when @TypeId = 51 then (select Locationid from dbo.Receipts where id = @docid)
						   when @TypeId = 151 then (select orgid from dbo.Taxitems where id = @docid)	
						   when @TypeId = 438 then (select LocationId from dbo.ProductInvoiceARs where id = @docid)	
					  end
					 )

/**************** 1-Info **************************************************/


/*Receipt*/

SELECT	r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date],r.TaxItemId,r.TaxItemCode
        ,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel)  ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(rl.ReceiptAmount,0) SubTotal
		-- ,ISNULL(IIF(rl.TaxBase = 0,rl.ReceiptAmount,rl.TaxBase),0) TaxBase
		,ISNULL(IIF(rl.TaxBase = 0,rl.ReceiptAmount,rl.ReceiptAmount *100/107),0) TaxBase /*ให้ form คำนวนใหม่เเทนที่จะดึงมาตรงๆ เนื่องจากยอดที่เก็บ diff กับ DB Receiptline MS-41459*/
		-- ,ISNULL(rl.VatAmount,0) VatAmount
		,ISNULL(rl.ReceiptAmount *7/107,0) VatAmount /*ให้ form คำนวนใหม่เเทนที่จะดึงมาตรงๆ เนื่องจากยอดที่เก็บ diff กับ DB Receiptline MS-41459*/
		,ISNULL(rl.RetentionAmount,0) RetentionAmount
		-- ,((IIF(rl.TaxBase = 0,rl.ReceiptAmount,(rl.TaxBase+rl.VatAmount)) - ISNULL(rl.RetentionAmount,0))) GrandTotal
		,((IIF(rl.TaxBase = 0,rl.ReceiptAmount,((rl.ReceiptAmount *100/107)+(rl.ReceiptAmount *7/107))) - ISNULL(rl.RetentionAmount,0))) GrandTotal /*ให้ form คำนวนใหม่เเทนที่จะดึงมาตรงๆ เนื่องจากยอดที่เก็บ diff กับ DB Receiptline MS-41459*/
		,NULL RefDocCode
		,'ใบเสร็จ' HeaderTH
		,'RECEIPT' HeaderEN
		,r.DocCurrency, r.DocCurrencyRate
		,NULL TaxRate
		,'0.00' DepositAmount
		,'0.00'  DiscountAmount
		,con.ContractNO ContractNO
     /*คูณ DocCurrencyRate ข้างในแล้ว*/    
FROM	dbo.Receipts r WITH (NOLOCK)
		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
		LEFT JOIN (SELECT MAX(Con.Name) ConName
									,MAX(con.Tel) Tel
									,MAX(con.Mail) Email
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Cp ON Ex.Id = Cp.ExtOrganizationId	
		LEFT JOIN (	SELECT	el.ReceiptId
		                    ,SUM(ISNULL(el.RemainAmount,0)*re.DocCurrencyRate)ReceiptAmount
							,SUM(ISNULL(el.TaxAmount*re.DocCurrencyRate,0))VatAmount
							,SUM(ISNULL(el.RetentionSetDocAmount*re.DocCurrencyRate,0))RetentionAmount 
							,SUM(ISNULL(el.TaxBase*re.DocCurrencyRate,0)) TaxBase
								FROM		dbo.ReceiptLines el WITH (NOLOCK)
												INNER JOIN dbo.Receipts re ON re.Id = el.ReceiptId 
								WHERE		ISNULL(el.SystemCategoryId,0) <> 111 
												AND el.ReceiptId = @DocId AND @TypeId = 51
												GROUP BY el.ReceiptId 
												) rl ON rl.ReceiptId = r.Id
	    LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = r.SubDocTypeId
	--	LEFT JOIN (SELECT til.ReceiptId,dbo.GROUP_CONCAT_D(til.RefIVCode,' ,') IvCode,dbo.GROUP_CONCAT_D(( itp.ContractNO),' ,') ContractNO ,dbo.GROUP_CONCAT_D(ipp.code,' ,') InterimCode
				--	FROM dbo.ReceiptLines til 
					--LEFT JOIN InterimPaymentLines itp ON itp.id = til.InterimPaymentLineId
				--	LEFT JOIN InterimPayments ipp ON ipp.id =itp.InterimPaymentId 
					--WHERE til.SystemCategoryId = 38 AND til.ReceiptId= @DocId
					--GROUP BY til.ReceiptId
				--	)con ON con.ReceiptId = r.id
        LEFT JOIN (
          			SELECT dbo.GROUP_CONCAT_D((x.IvCode),' ,')  IvCode,x.ReceiptId ,dbo.GROUP_CONCAT_D(( x.ContractNO),' ,') ContractNO ,dbo.GROUP_CONCAT_D(x.InterimCode,' ,') InterimCode
					FROM
					(

					SELECT DISTINCT(ipp.id) Interimpaymentid,til.RefIVCode IvCode,til.ReceiptId ,itp.ContractNO ContractNO ,ipp.code InterimCode
					FROM dbo.ReceiptLines til 
					LEFT JOIN (select InvoiceARId,InterimPaymentLineId from InvoiceARLines where SystemCategoryId IN (128,210) OR SystemCategory = 'Deposit') Inv ON inv.InvoiceARId =til.RefIVId
					LEFT JOIN InterimPaymentLines itp ON itp.id = inv.InterimPaymentLineId 
					LEFT JOIN InterimPayments ipp ON ipp.id =itp.InterimPaymentId 
					WHERE til.SystemCategoryId = 38 AND til.ReceiptId= @DocId
					) x
					GROUP BY x.ReceiptId
					)con ON con.ReceiptId = r.id


WHERE	r.Id = @DocId AND @TypeId = 51

UNION ALL


/* Other Receives */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel) ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(rr.ReceiptAmount,0) SubTotal
		,0.00 TaxBase
		,0.00 VatAmount
        ,0.00 RetentionAmount
        --,ISNULL(gt.Amount*ro.DocCurrencyRate,0)
        ,ISNULL(rr.ReceiptAmount,0) GrandTotal 
		,ro.Code RefDocCode
		,'ใบเสร็จ' HeaderTH
		,'RECEIPT' HeaderEN
		,ro.DocCurrency
		,ro.DocCurrencyRate
		--,IIF(CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%')) TaxRate
        ,NULL TaxRate
		,'0.00' DepositAmount
		,'0.00'  DiscountAmount
         ,NULL ContractNO
FROM	dbo.OtherReceives ro WITH (NOLOCK)
			LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 44
			--LEFT JOIN ReceiptLines rr ON rr.ReceiptId = r.Id AND rr.SystemCategoryId =111
            LEFT JOIN (SELECT SUM(ReceiptAmount) ReceiptAmount,ReceiptId FROM ReceiptLines WHERE SystemCategoryId <> 111 GROUP BY ReceiptId )rr ON rr.ReceiptId = r.Id 
			LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
			LEFT JOIN (SELECT MAX(Con.Name) ConName
									,MAX(con.Tel) Tel
									,MAX(con.Mail) Email
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Cp ON Ex.Id = Cp.ExtOrganizationId		
			LEFT JOIN dbo.TaxItems t WITH (NOLOCK) ON t.SetDocId = ro.Id AND t.SetDocTypeId = 44 AND t.SystemCategoryId = 151	
			LEFT JOIN dbo.TaxItemLines tx WITH (NOLOCK) ON t.id = tx.TaxItemId AND tx.SetDocTypeId = 44 AND tx.SystemCategoryId IN (151)		
			LEFT JOIN dbo.OtherReceiveLines gt WITH (NOLOCK) ON gt.SystemCategoryId = 111 AND gt.OtherReceiveId = ro.Id
			LEFT JOIN dbo.OtherReceiveLines ol WITH (NOLOCK) ON ol.SystemCategoryId IN (123,129,131,199) AND ol.OtherReceiveId = ro.Id
			LEFT JOIN dbo.OtherReceiveLines st WITH (NOLOCK) ON st.SystemCategoryId IN (107) AND st.OtherReceiveId = ro.Id
			LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = ro.SubDocTypeId
WHERE	ro.Id = @DocId AND @TypeId = 44

UNION ALL

/* TaxInvoiceAndReceipts */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel) ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(rl.SubTotal,0) SubTotal
		,ISNULL((rl.ReceiptAmount+ rl.RetentionAmount-rl.VatAmount),0) TaxBase
		,ISNULL(rl.VatAmount,0) VatAmount,ISNULL(rl.RetentionAmount,0) RetentionAmount,ISNULL(rl.ReceiptAmount,0) GrandTotal
		,NULL RefDocCode
		,'ใบกำกับภาษี & ใบเสร็จ' HeaderTH
		,'TAX INVOICE & RECEIPT' HeaderEN  
		,t.DocCurrency
		,t.DocCurrencyRate
		,IIF(CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%')) TaxRate
		,rl.DepositAmount
		,rl.DiscountAmount
		,con.ContractNO
		 /*คูณ DocCurrencyRate ข้างในแล้ว*/ 
FROM	dbo.TaxItems t WITH (NOLOCK)
		LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = t.Id AND r.DocTypeId = 151
		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
		LEFT JOIN (SELECT MAX(Con.Name) ConName
									,MAX(con.Tel) Tel
									,MAX(con.Mail) Email
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Cp ON Ex.Id = Cp.ExtOrganizationId	
		LEFT JOIN TaxItemLines tx ON tx.TaxItemId =t.id AND tx.SystemCategoryId IN (123,129)
		LEFT JOIN (	SELECT	tl.TaxItemId,SUM(IIF(tl.SystemCategoryId = 49,tl.Amount,0)*ti.DocCurrencyRate)RetentionAmount
										,SUM(IIF(tl.SystemCategoryId IN (123,129),tl.TaxAmount,0)*ti.DocCurrencyRate) VatAmount
										,SUM(IIF(tl.SystemCategoryId = 111,tl.Amount,0)*ti.DocCurrencyRate) ReceiptAmount 
										,SUM(IIF(tl.SystemCategoryId = 107,tl.Amount,0)*ti.DocCurrencyRate) SubTotal
										,SUM(IIF(tl.SystemCategoryId = 124,tl.Amount,0)*ti.DocCurrencyRate) DiscountAmount
										,SUM(IIF(tl.SystemCategory = 'DepositReceive',tl.Amount,0)*ti.DocCurrencyRate) DepositAmount
								FROM		dbo.TaxItemLines tl WITH (NOLOCK)
												INNER JOIN dbo.TaxItems ti WITH (NOLOCK) ON ti.Id = tl.TaxItemId 
								WHERE		tl.TaxItemId = @DocId AND @TypeId = 151
												GROUP BY tl.TaxItemId 
												) rl ON rl.TaxItemId = t.Id
		LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = t.SubDocTypeId
		
		LEFT JOIN (SELECT til.TaxItemId,dbo.GROUP_CONCAT_D(til.SetDocCode,' ,') IvCode,dbo.GROUP_CONCAT_D( til.ContractNO,' ,') ContractNO ,dbo.GROUP_CONCAT_D(ipp.code,' ,') InterimCode
					FROM dbo.TaxItemLines til 
					LEFT JOIN InterimPaymentLines itp ON itp.id = til.InterimPaymentLineId
					LEFT JOIN InterimPayments ipp ON ipp.id =itp.InterimPaymentId 
					WHERE til.SetDocTypeid = 38 AND taxitemid= @DocId 
					GROUP BY TaxItemId
					)con ON con.TaxItemId = t.id
WHERE	t.Id = @DocId AND @TypeId = 151


UNION ALL


/* Other Receives */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel) ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(rr.ReceiptAmount,0) SubTotal
		,ISNULL(txx.TaxBase,0) TaxBase
		,ISNULL(txx.TaxAmount,0) VatAmount
        ,0.00 RetentionAmount
        --,ISNULL(gt.Amount*ro.DocCurrencyRate,0)
        ,ISNULL(rr.ReceiptAmount,0) GrandTotal 
		,ro.Code RefDocCode
		,'ใบเสร็จ' HeaderTH
		,'RECEIPT' HeaderEN
		,ro.DocCurrency
		,ro.DocCurrencyRate
		,IIF(CONCAT(FORMAT(ISNULL(txx.TaxRate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(txx.TaxRate,0),'N0'),'%')) TaxRate
        --,NULL TaxRate
		,ISNULL(dp.Amount,0) DepositAmount
		,ISNULL(ds.Amount,0)  DiscountAmount
         ,NULL ContractNO
FROM	dbo.ProductInvoiceARs ro WITH (NOLOCK)
			LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 438
			--LEFT JOIN ReceiptLines rr ON rr.ReceiptId = r.Id AND rr.SystemCategoryId =111
            LEFT JOIN (SELECT SUM(ReceiptAmount) ReceiptAmount,ReceiptId FROM ReceiptLines WHERE SystemCategoryId <> 111 GROUP BY ReceiptId )rr ON rr.ReceiptId = r.Id 
			LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
			LEFT JOIN (SELECT MAX(Con.Name) ConName
									,MAX(con.Tel) Tel
									,MAX(con.Mail) Email
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Cp ON Ex.Id = Cp.ExtOrganizationId		
			LEFT JOIN dbo.TaxItems t WITH (NOLOCK) ON t.SetDocId = ro.Id AND t.SetDocTypeId = 438 AND t.SystemCategoryId = 151	
			LEFT JOIN dbo.TaxItemLines tx WITH (NOLOCK) ON t.id = tx.TaxItemId AND tx.SetDocTypeId = 438 AND tx.SystemCategoryId IN (151)		
			LEFT JOIN dbo.ProductInvoiceARLines gt WITH (NOLOCK) ON gt.SystemCategoryId = 111 AND gt.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.ProductInvoiceARLines ol WITH (NOLOCK) ON ol.SystemCategoryId IN (123,129,131,199) AND ol.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.ProductInvoiceARLines st WITH (NOLOCK) ON st.SystemCategoryId IN (107) AND st.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.ProductInvoiceARLines dp WITH (NOLOCK) ON dp.SystemCategory = 'DepositReceive' AND dp.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.ProductInvoiceARLines ds WITH (NOLOCK) ON ds.SystemCategoryId IN (124) AND ds.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.ProductInvoiceARLines txx WITH (NOLOCK) ON txx.SystemCategoryId IN (123,129) AND txx.ProductInvoiceARId = ro.Id
			LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = ro.SubDocTypeId
WHERE	ro.Id = @DocId AND @TypeId = 438


--/*2-Line*/
------------------------------------------------------------------------------------------------------------------------------------------------------:)
SELECT * 
FROM
(
/* OtherReceives */

SELECT	ROW_NUMBER() OVER(ORDER BY rl.LineNumber ) LineNumber
		,rl.LineNumber Line_No,rl.Description,ro.Code RefIVCode
		,1 Qty
		,'Unit' DocUnitName
		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) UnitPrice
		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) ReceiptAmount
		,NULL Discount
		,r.DocCurrencyRate
FROM		dbo.OtherReceives ro WITH (NOLOCK)
				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 44
				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
WHERE		ro.Id = @DocId AND @TypeId = 44


UNION ALL


/*Receipt*/

SELECT	ROW_NUMBER() OVER(ORDER BY rl.LineNumber ) LineNumber
		,rl.LineNumber Line_No,rl.Description,rl.RefIVCode,1 Qty
		,'Unit' DocUnitName
		,ISNULL(rl.RemainAmount * r.DocCurrencyRate,0) UnitPrice
		,ISNULL(rl.RemainAmount * r.DocCurrencyRate,0) ReceiptAmount
		,NULL Discount
		,r.DocCurrencyRate
FROM		dbo.ReceiptLines rl WITH (NOLOCK)
            INNER JOIN dbo.Receipts r WITH (NOLOCK) ON r.Id = rl.ReceiptId
WHERE		rl.ReceiptId = @DocId AND @TypeId = 51
				AND ISNULL(rl.SystemCategoryId,0) NOT IN (111,-2)

UNION ALL


SELECT	NULL LineNumber
		,rl.LineNumber Line_No,rl.Description,rl.RefIVCode,NULL Qty
		,NULL DocUnitName
		,NULL UnitPrice
		,NULL ReceiptAmount
		,NULL Discount
		,r.DocCurrencyRate
FROM		dbo.ReceiptLines rl WITH (NOLOCK)
            INNER JOIN dbo.Receipts r WITH (NOLOCK) ON r.Id = rl.ReceiptId
WHERE		rl.ReceiptId = @DocId AND @TypeId = 51
				AND ISNULL(rl.SystemCategoryId,0)  IN (-2)

UNION ALL

/* TaxInvoiceAndReceipts */

SELECT	ROW_NUMBER() OVER(ORDER BY tx.LineNumber ) LineNumber
		,tx.LineNumber Line_No,tx.Description,rl.RefIVCode,tx.DocQty Qty
		,tx.DocUnitName
		,ISNULL(tx.UnitPrice * r.DocCurrencyRate,0) UnitPrice
		,ISNULL(tx.Amount * r.DocCurrencyRate,0) ReceiptAmount
		,tx.DiscountAmount Discount
		,r.DocCurrencyRate
FROM		dbo.TaxItems t WITH (NOLOCK)
				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = t.Id AND r.DocTypeId = 151
				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
				LEFT JOIN TaxItemLines tx ON tx.id =rl.TaxItemLineId
WHERE		t.Id = @DocId AND @TypeId = 151
				AND ISNULL(rl.SystemCategoryId,0) NOT IN (-2)
UNION ALL


SELECT	NULL LineNumber
		,rl.LineNumber Line_No,rl.Description,rl.RefIVCode,NULL Qty
		,NULL DocUnitName
		,NULL UnitPrice
		,NULL ReceiptAmount
		,NULL Discount
		,r.DocCurrencyRate
FROM		dbo.TaxItems t WITH (NOLOCK)
				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = t.Id AND r.DocTypeId = 151
				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
WHERE		t.Id = @DocId AND @TypeId = 151
				AND ISNULL(rl.SystemCategoryId,0)  IN (-2)

UNION ALL


SELECT	ROW_NUMBER() OVER(ORDER BY rl.LineNumber ) LineNumber
		,rl.LineNumber Line_No,rl.Description,ro.Code RefIVCode
		,1 Qty
		,'Unit' DocUnitName
		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) UnitPrice
		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) ReceiptAmount
		,NULL Discount
		,r.DocCurrencyRate
FROM		dbo.ProductInvoiceARs ro WITH (NOLOCK)
				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 438
				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
WHERE		ro.Id = @DocId AND @TypeId = 438
 ) x
 ORDER BY x.Line_No
/*3-Other*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT @TypeId DocTypeId

/*4-ReceiveMethod*/
-----------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @json NVARCHAR(MAX) = (SELECT datavalues FROM CustomNoteLines WHERE id = 18)
SELECT * FROM OPENJSON(@json)
SELECT datavalues FROM CustomNoteLines WHERE id = 18 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER 
-- select JSON_QUERY(datavalues,'$'),JSON_VALUE(datavalues,'$[1]') from CustomNoteLines where id = 18


/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @DocOrgid 
-----------------------------------------------------------------------------------------------------------------------------------------------