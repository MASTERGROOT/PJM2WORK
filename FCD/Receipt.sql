/*==> Ref:i:\pjm2\scon\content\printing\documentcommands\ar_re_receipt.sql ==>*/
 
/*==> Ref:f:\pjm2\kokoro\content\printing\documentcommands\ar_re_receipt.sql ==>*/
 
/*  form   : AR_RE
	Rev.   : JEY.11.04.2018
	Rev.V2 : BANK.28.11.2018
*/


DECLARE @p0 NUMERIC(18) = 234
DECLARE @p1 NUMERIC(18) = 44 /*44 : OtherReceives | 51 : Receipt | 151 : TaxInvoice&Receive*/

DECLARE @DocId NUMERIC(18) = @p0
DECLARE @TypeId NUMERIC(18) = @p1


DECLARE @DocOrgid INT = (case when @TypeId = 44 then (select Locationid from dbo.otherreceives where id = @docid)
						   when @TypeId = 51 then (select Locationid from dbo.Receipts where id = @docid)
						   when @TypeId = 151 then (select orgid from dbo.Taxitems where id = @docid)	
						   when @TypeId = 438 then (select LocationId from dbo.ProductInvoiceARs where id = @docid)	
					  end
					 )

/**************** 1-Info **************************************************/
-- SELECT dbo.GROUP_CONCAT_D((x.IvCode),' ,')  IvCode,x.ReceiptId ,dbo.GROUP_CONCAT_D(( x.ContractNO),' ,') ContractNO ,dbo.GROUP_CONCAT_D(x.InterimCode,' ,') InterimCode
-- 					FROM
-- 					(

-- 					SELECT DISTINCT(ipp.id) Interimpaymentid,til.RefIVCode IvCode,til.ReceiptId ,itp.ContractNO ContractNO ,ipp.code InterimCode
-- 					FROM dbo.ReceiptLines til 
-- 					LEFT JOIN (select InvoiceARId,InterimPaymentLineId from InvoiceARLines where SystemCategoryId IN (128,210) OR SystemCategory = 'Deposit') Inv ON inv.InvoiceARId =til.RefIVId
-- 					LEFT JOIN InterimPaymentLines itp ON itp.id = inv.InterimPaymentLineId 
-- 					LEFT JOIN InterimPayments ipp ON ipp.id =itp.InterimPaymentId 
-- 					WHERE til.SystemCategoryId = 38 AND til.ReceiptId= @DocId
-- 					) x
-- 					GROUP BY x.ReceiptId


/*Receipt*/

SELECT	r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date],r.TaxItemId,r.TaxItemCode
        ,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel)  ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(rl.ReceiptAmount,0) SubTotal
		,ISNULL(IIF(rl.TaxBase = 0,rl.ReceiptAmount,rl.TaxBase),0) TaxBase
		,ISNULL(rl.VatAmount,0) VatAmount
		,ISNULL(rl.RetentionAmount,0) RetentionAmount
		,((IIF(rl.TaxBase = 0,rl.ReceiptAmount,(rl.TaxBase+rl.VatAmount)) - ISNULL(rl.RetentionAmount,0))) GrandTotal
		,NULL RefDocCode
		,'ใบเสร็จ' HeaderTH
		,'RECEIPT' HeaderEN
		,r.DocCurrency, r.DocCurrencyRate
		,NULL TaxRate
		,'0.00' DepositAmount
		,'0.00'  DiscountAmount
		,con.ContractNO ContractNO
		,CONCAT(FORMAT(clwhtset.WHT,'#.#'),'%') WHT
		,clwhtset.WHTAmount WHTAmount
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
				LEFT JOIN (
						SELECT ReceiptId,SUM(TaxBase) TotalTaxBase, SUM(whtAmount) WHTAmount,SUM(whtAmount)*100/SUM(TaxBase) WHT
						FROM(
							SELECT rcl.ReceiptId,rcl.TaxBase
							,CASE WHEN IIF(clwht.DataValues= '',0,clwht.DataValues) != 0
								THEN rcl.TaxBase * IIF(clwht.DataValues= '',0,clwht.DataValues)/100
								ELSE CAST(IIF(clamtwht.DataValues= '',0,clamtwht.DataValues) AS DECIMAL(18,2))
							END whtAmount
						from ReceiptLines rcl
						LEFT JOIN TaxItemLines til ON til.TaxItemId = (select ti.Id from Taxitems ti where ti.guid IN (rcl.TaxItemGuId))
						LEFT JOIN CustomNoteLines clwht ON til.SetDocGuid = clwht.DocGuid AND clwht.KeyName = 'WHT Rate'
						LEFT JOIN CustomNoteLines clamtwht ON til.SetDocGuid = clamtwht.DocGuid AND clamtwht.KeyName = 'WHT Amount'
						where rcl.ReceiptId = @DocId  AND til.SetDocTypeId IN (438,38)
						) wht GROUP BY ReceiptId
				)clwhtset ON clwhtset.ReceiptId = r.Id

WHERE	r.Id = @DocId AND @TypeId = 51

UNION ALL


/* Other Receives */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,ro.Remarks,r.LocationId,r.LocationCode,r.LocationName
		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
		,Ex.Address ExtOrgAddress,ISNULL(cp.tel,Ex.Tel) ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
        ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
        ,cp.ConName ExtOrgContact
		,ISNULL(t.TaxBase,0)*ISNULL(r.DocCurrencyRate,0) SubTotal
		,ISNULL(t.TaxBase,0)*ISNULL(r.DocCurrencyRate,0) TaxBase
		,ISNULL(t.TaxAmount,0)*ISNULL(r.DocCurrencyRate,0) VatAmount
        ,ISNULL(rl.RetentionAmount,0)*ISNULL(r.DocCurrencyRate,0) RetentionAmount
        --,ISNULL(gt.Amount*ro.DocCurrencyRate,0)
        ,ISNULL(rr.ReceiptAmount,0)*ISNULL(r.DocCurrencyRate,0) GrandTotal 
		,ro.Code RefDocCode
		,'ใบเสร็จ' HeaderTH
		,'RECEIPT' HeaderEN
		,ro.DocCurrency
		,ro.DocCurrencyRate
		--,IIF(CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(tx.TaxRate,0),'N0'),'%')) TaxRate
        ,IIF(CONCAT(FORMAT(ISNULL(t.TaxRate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(t.TaxRate,0),'N0'),'%')) TaxRate
		,'0.00' DepositAmount
		,'0.00'  DiscountAmount
         ,NULL ContractNO
		 ,CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
							THEN IIF(ISNULL(orwht.WHTRate,0) = 0,'0.00%',CONCAT(FORMAT(orwht.WHTRate,'#.#'),'%'))
						ELSE IIF(ISNULL(IIF(clwht.DataValues= '',0,clwht.DataValues),0) = 0,'0.00%',CONCAT(FORMAT(IIF(clwht.DataValues= '',0,clwht.DataValues),'#.#'),'%')) 
			END WHT
		,CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
			THEN ISNULL(orwht.WhtAmount,0)
		ELSE ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(t.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0) END
		WHTAmount
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
			LEFT JOIN (	
						SELECT	tl.TaxItemId,SUM(IIF(tl.SystemCategoryId = 49,tl.Amount,0))RetentionAmount
										,SUM(IIF(tl.SystemCategoryId IN (123,129),tl.TaxAmount,0)) VatAmount
										,SUM(IIF(tl.SystemCategoryId = 111,tl.Amount,0)) ReceiptAmount 
										,SUM(IIF(tl.SystemCategoryId = 107,tl.Amount,0)) SubTotal
										,SUM(IIF(tl.SystemCategoryId = 124,tl.Amount,0)) DiscountAmount
										,SUM(IIF(tl.SystemCategory = 'DepositReceive',tl.Amount,0)) DepositAmount
								FROM		dbo.TaxItemLines tl WITH (NOLOCK)
												INNER JOIN dbo.TaxItems ti WITH (NOLOCK) ON ti.Id = tl.TaxItemId 
								WHERE		ti.SetDocId = @DocId AND ti.SetDocTypeId = @TypeId
												GROUP BY tl.TaxItemId 
												) rl ON rl.TaxItemId = t.Id
			LEFT JOIN (
					SELECT otl.OtherReceiveId,til.TaxItemId,til.TaxRate [WHTRate],SUM(til.TaxAmount) [WhtAmount]
					from OtherReceiveLines otl 
					LEFT JOIN taxitems ti ON otl.TaxItemGuid = ti.guid
					LEFT JOIN taxitemlines til ON ti.Id = til.TaxItemId
					WHERE otl.SystemCategoryId = 36 AND otl.OtherReceiveId = @docid
					GROUP BY otl.OtherReceiveId,til.TaxRate,til.TaxItemId
			) orwht ON orwht.OtherReceiveId = ro.Id
			LEFT JOIN CustomNoteLines clwht ON clwht.DocGuid = ro.guid AND clwht.KeyName = 'WHT Rate'
			LEFT JOIN CustomNoteLines clawht ON clawht.DocGuid = ro.guid AND clawht.KeyName = 'WHT Amount'
WHERE	ro.Id = @DocId AND @TypeId = 44

UNION ALL

/* TaxInvoiceAndReceipts */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,t.Remarks,r.LocationId,r.LocationCode,r.LocationName
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
		,CONCAT(FORMAT(clwhtset.WHT,'#.#'),'%') WHT
		,clwhtset.WHTAmount WHTAmount
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
		LEFT JOIN (
				SELECT TaxItemId,SUM(TaxBase) TotalTaxBase, SUM(whtAmount) WHTAmount,SUM(whtAmount)*100/SUM(TaxBase) WHT
			FROM(
				SELECT til.TaxItemId,til.TaxBase
				,CASE WHEN IIF(clwht.DataValues= '',0,clwht.DataValues) != 0
					THEN til.TaxBase * IIF(clwht.DataValues= '',0,clwht.DataValues)
					ELSE CAST(IIF(clamtwht.DataValues= '',0,clamtwht.DataValues) AS DECIMAL(18,2))
				END whtAmount
			from taxitemlines til
			LEFT JOIN CustomNoteLines clwht ON til.SetDocGuid = clwht.DocGuid AND clwht.KeyName = 'WHT Rate'
			LEFT JOIN CustomNoteLines clamtwht ON til.SetDocGuid = clamtwht.DocGuid AND clamtwht.KeyName = 'WHT Amount'
			where til.TaxitemId = @DocId  AND til.SetDocTypeId IN (438,38)
			) wht GROUP BY TaxItemId
			) clwhtset ON clwhtset.TaxItemId = t.Id
WHERE	t.Id = @DocId AND @TypeId = 151


UNION ALL


/* Product Invoice */

SELECT	
		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
		,r.DocTypeId,r.DocType,ro.Remarks,r.LocationId,r.LocationCode,r.LocationName
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
		,CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
							THEN IIF(ISNULL(orwht.WHTRate,0) = 0,'0.00%',CONCAT(FORMAT(orwht.WHTRate,'#.#'),'%'))
						ELSE IIF(ISNULL(IIF(clwht.DataValues= '',0,clwht.DataValues),0) = 0,'0.00%',CONCAT(FORMAT(IIF(clwht.DataValues= '',0,clwht.DataValues),'#.#'),'%')) 
			END WHT
		,CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
			THEN ISNULL(orwht.WhtAmount,0)
		ELSE ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(t.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0) END
		WHTAmount
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
			LEFT JOIN (
					SELECT otl.ProductInvoiceARId,til.TaxItemId,til.TaxRate [WHTRate],SUM(til.TaxAmount) [WhtAmount]
					from ProductInvoiceARLines otl 
					LEFT JOIN taxitems ti ON otl.TaxItemGuid = ti.guid
					LEFT JOIN taxitemlines til ON ti.Id = til.TaxItemId
					WHERE otl.SystemCategoryId = 36 AND otl.ProductInvoiceARId = @docid
					GROUP BY otl.ProductInvoiceARId,til.TaxRate,til.TaxItemId
			) orwht ON orwht.ProductInvoiceARId = ro.Id
			LEFT JOIN CustomNoteLines clwht ON clwht.DocGuid = ro.guid AND clwht.KeyName = 'WHT Rate'
			LEFT JOIN CustomNoteLines clawht ON clawht.DocGuid = ro.guid AND clawht.KeyName = 'WHT Amount'
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

/*4-Payment*/
-----------------------------------------------------------------------------------------------------------------------------------------------

SELECT   /* เพิ่ม Receive Method ถ้าดึงไปทำ RV เเล้ว 26/05/2025 By Good */
                pa.LineNumber
                /* IIF(ISNULL(pa.FiscalItemCode,'') = '',b.LocalBankNameCONCAT(b.LocalBankCode,' : ',b.LocalBankName),b.LocalBankName,CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName)) */
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',NULL,pa.BankCode) BankCodeCheck
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.BankCode,NULL) BankCode
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',NULL,pa.LocalBankName) BankNameCheck
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.LocalBankName,NULL) BankName
				,pa.Branch,pa.AcctNumber
                ,IIF(IIF(ISNULL(pa.FiscalItemCode,'') = '',0,1) = 1 AND ISNULL(pa.Amount,0) <> 0,COALESCE(FORMAT(pa.FiscalDueDate,'dd/MM/yy'),FORMAT(j.MadeByDocDate,'dd/MM/yy')),NULL) FiscalDueDate
                ,pa.FiscalItemCode
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '',FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n'),'')ReceiveAmtBank
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '','',FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n'))ReceiveAmtCheck
				,IIF(ISNULL(pa.FiscalItemCode,'') = '',0,1) isCheck
				,IIF(ISNULL(pa.FiscalItemCode,'') = '',1,0) isBank
				,0 isCash

        FROM    dbo.JournalVouchers j WITH (NOLOCK)
				LEFT JOIN OtherReceivelines orl ON orl.OtherReceiveId = j.MadeByDocId AND orl.SystemCategoryId = 58
				LEFT JOIN dbo.Banks b WITH (NOLOCK) ON b.localBankCode = orl.FiscalItemCheckBank AND b.RegionalCode = 'TH'
                LEFT JOIN ( 
                            SELECT  ROW_NUMBER() OVER (PARTITION BY jl.JournalVoucherId ORDER BY jl.Id)LineNumber
																		,jl.JournalVoucherId,jl.isDebit
                                    ,IIF(jl.FiscalMetaCode = 'Deduct',jl.FiscalMetaCode,ba.BankCode) BankCode
                                    ,IIF(jl.FiscalMetaCode = 'Deduct',jl.Description,ba.AcctNumber) AcctNumber
                                    ,jl.FiscalItemCode,jl.FiscalDueDate,jl.Amount,ba.Branch,b.LocalBankName
                            FROM    dbo.JVLines jl WITH (NOLOCK)
                                    LEFT JOIN dbo.BankAccts ba WITH (NOLOCK) ON ba.Id = jl.BankAcctId 
									LEFT JOIN dbo.Banks b WITH (NOLOCK) ON b.localBankCode = ba.BankCode AND b.RegionalCode = 'TH'
                            WHERE   (ISNULL(jl.BankAcctId,0) <> 0 OR jl.FiscalMetaCode = 'Deduct')
                                    ) pa ON pa.JournalVoucherId = j.Id
		
        WHERE   j.MadeByTypeId = @TypeId AND j.MadeByDocId = @DocId
                AND j.MadeByTypeId IN (44,52) AND pa.LineNumber = 1
		Union ALL
		Select pa.LineNumber,pa.BankCodeCheck,pa.BankCode,pa.BankNameCheck,pa.BankName,pa.Branch,pa.AcctNumber,pa.FiscalDueDate,pa.FiscalItemCode,pa.ReceiveAmtBank,pa.ReceiveAmtCheck,pa.isCheck,pa.isBank,pa.isCash
		From ReceiveVoucherLines rvl
		LEFT JOIN (
					Select	rvl.ReceiveVoucherId,rvl.LineNumber
                            /* IIF(ISNULL(rvl.FiscalItemCode,'') = '',CONCAT(ba.LocalBankCode,' : ',ba.LocalBankName),CONCAT(rvl.FiscalItemCheckBank,' : ',ba.LocalBankName)) */
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',NULL,b.LocalBankCode)BankCodeCheck
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',b.LocalBankCode,NULL) BankCode
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',NULL,ISNULL(b.LocalBankName,ba.BankCode))BankNameCheck
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ISNULL(b.LocalBankName,ba.BankCode),NULL) BankName
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') Branch
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.AcctNumber,'') AcctNumber
							,IIF(IIF(ISNULL(rvl.FiscalItemCode,'') = '',0,1) = 1,FORMAT(rvl.FiscalDueDate,'dd/MM/yy'),'') FiscalDueDate
							,rvl.FiscalItemCode
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',FORMAT(rvl.PayAmount,'n'),'')ReceiveAmtBank
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '','',FORMAT(rvl.PayAmount,'n'))ReceiveAmtCheck
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',0,1) isCheck
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',1,0) isBank
							,0 isCash
					From ReceiveVouchers rv
					LEFT JOIN ReceiveVoucherLines rvl ON rvl.ReceiveVoucherId = rv.Id
					LEFT JOIN BankAccts ba WITH (NOLOCK) ON ba.Id = rvl.BankAcctId 
					LEFT JOIN Banks b WITH (NOLOCK) ON b.LocalBankName = ba.BankCode AND b.RegionalCode = 'TH'
					Where rvl.FiscalMetaId IS NOT NULL --rvl.SystemCategoryId = 51
		) pa ON pa.ReceiveVoucherId = rvl.ReceiveVoucherId
		Where rvl.SystemCategoryId IN (51,58) AND ((rvl.TaxItemId = @DocId AND @TypeId = 151) OR (rvl.DocId = @DocId AND @TypeID = 51))
				

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
			SELECT 
        CASE WHEN x.CompanyName NOT LIKE '%[a-z]%' THEN x.CompanyName
             WHEN x.CompanyAlterName NOT LIKE '%[a-z]%' THEN x.CompanyAlterName
						 WHEN x.CompanyRegisterName NOT LIKE '%[a-z]%' THEN x.CompanyRegisterName
						 WHEN x.CompanyInitialName NOT LIKE '%[a-z]%' THEN x.CompanyInitialName 
             ELSE NULL END CompanyNameTH
       
			 ,CASE WHEN x.CompanyName LIKE '%[a-z]%' AND x.EngStatus ='y'	THEN x.CompanyName
             WHEN x.CompanyAlterName LIKE '%[a-z]%' AND x.EngStatus ='y' THEN x.CompanyAlterName
						 WHEN x.CompanyRegisterName LIKE '%[a-z]%' AND x.EngStatus ='y' THEN x.CompanyRegisterName
						 WHEN x.CompanyInitialName LIKE '%[a-z]%' AND x.EngStatus ='y' THEN x.CompanyInitialName  
             ELSE NULL END CompanyNameEN
       ,
				CASE WHEN x.CompanyAddress NOT LIKE '%[a-z]%' THEN x.CompanyAddress
					 WHEN x.CompanyBillingAddress NOT LIKE '%[a-z]%' THEN x.CompanyBillingAddress 
					 ELSE '' END CompanyAddressTH
       
			 ,IIF(x.EngStatus ='n',NULL,
				CASE	WHEN x.CompanyAddress LIKE '%[a-z]%' THEN x.CompanyAddress
							WHEN x.CompanyBillingAddress LIKE '%[a-z]%' THEN x.CompanyBillingAddress 
							ELSE '' END) CompanyAddressEN
			 
			 ,IIF(NULLIF(x.TaxNumber,'') IS NULL,NULL,CONCAT('เลขประจำตัวผู้เสียภาษี  ', x.TaxNumber)) CompanyTaxTH
			 ,IIF(x.EngStatus ='n',NULL,IIF(NULLIF(x.TaxNumber,'') IS NULL,'',CONCAT('Tax ID. ', x.TaxNumber))) CompanyTaxEN

			 ,CONCAT('โทร.  ',x.PhoneNumber) CompanyTelTH
			 ,IIF(x.EngStatus ='n',NULL,CONCAT('Tel.  ',x.PhoneNumber)) CompanyTelEN

			 ,CONCAT('แฟกซ์.  ',x.FaxNumber) CompanyFaxTH
			 ,IIF(x.EngStatus ='n',NULL,CONCAT('Fax.  ',x.FaxNumber)) CompanyFaxEN
       
			 ,IIF(x.CompanyName LIKE '%สำนักงานใหญ่%','','(สำนักงานใหญ่)') CompanyBranchTH
			 ,IIF(x.EngStatus ='n',NULL,IIF(x.CompanyName LIKE '%OFFICE%','','(HEAD OFFICE)')) CompanyBranchEN

			 ,IIF(x.FaxNumber != '', CONCAT('โทร.  ',x.PhoneNumber,'   แฟกซ์.  ',x.FaxNumber),CONCAT('โทร.  ',x.PhoneNumber)) CompanyTelAndFaxTH
			 ,IIF(x.FaxNumber != '',IIF(x.EngStatus ='n',NULL,CONCAT('Tel.  ',x.PhoneNumber,'   Fax.  ',x.FaxNumber)),IIF(x.EngStatus ='n',NULL,CONCAT('Tel.  ',x.PhoneNumber))) CompanyTelAndFaxEN

			 ,IIF(x.CompanyName LIKE '%สำนักงานใหญ่%',CONCAT('เลขประจำตัวผู้เสียภาษี  '+ x.TaxNumber,''),CONCAT('เลขประจำตัวผู้เสียภาษี  '+ x.TaxNumber,'   (สำนักงานใหญ่)')) CompanyTaxBranchTH
			 ,IIF(x.EngStatus ='n',NULL,IIF(NULLIF(x.TaxNumber,'') IS NULL,'',CONCAT('Tax ID.  '+ x.TaxNumber,'   (HEAD OFFICE)'))) CompanyTaxBranchEN
			 ,x.CompanyBillingAddress 
			 ,x.OtherPhoneNumber CompanyOtherPhoneNumber
             ,x.CompanyEmailAddress
FROM	(
SELECT 
       MIN(CASE WHEN f.ConfigName = 'CompanyName' THEN f.Value ELSE NULL END) CompanyName
       ,MIN(CASE WHEN f.ConfigName = 'CompanyAlterName' THEN f.Value ELSE NULL END) CompanyAlterName
			 ,MIN(CASE WHEN f.ConfigName = 'CompanyRegisterName' THEN f.Value ELSE NULL END) CompanyRegisterName
			 ,MIN(CASE WHEN f.ConfigName = 'CompanyInitialName' THEN f.Value ELSE NULL END) CompanyInitialName
       ,MIN(CASE WHEN f.ConfigName = 'CompanyAddress' THEN f.Value ELSE NULL END) CompanyAddress
       ,MIN(CASE WHEN f.ConfigName = 'CompanyBillingAddress' THEN f.Value ELSE NULL END) CompanyBillingAddress
       ,CASE WHEN MIN(CASE WHEN f.ConfigName = 'CompanyAddress' THEN f.Value ELSE NULL END) LIKE '%[a-z]%'
									OR MIN(CASE WHEN f.ConfigName = 'CompanyBillingAddress' THEN f.Value ELSE NULL END) LIKE '%[a-z]%' 
				 THEN 'y' 
				 ELSE 'n' END EngStatus
       ,MIN(CASE WHEN f.ConfigName = 'PhoneNumber' THEN f.Value ELSE NULL END) PhoneNumber
       ,MIN(CASE WHEN f.ConfigName = 'OtherPhoneNumber' THEN f.Value ELSE NULL END) OtherPhoneNumber
       ,MIN(CASE WHEN f.ConfigName = 'FaxNumber' THEN f.Value ELSE NULL END) FaxNumber
       ,MIN(CASE WHEN f.ConfigName = 'TaxNumber' THEN f.Value ELSE NULL END) TaxNumber
       ,MIN(CASE WHEN f.ConfigName = 'CompanyEmailAddress' THEN f.Value ELSE NULL END) CompanyEmailAddress
FROM	  dbo.CompanyConfigs f WITH (NOLOCK)
 
) x;
-----------------------------------------------------------------------------------------------------------------------------------------------