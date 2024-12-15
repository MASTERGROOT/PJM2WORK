/*==> Ref:i:\pjm2\scon\content\printing\documentcommands\ar_re_receipt.sql ==>*/
 
/*==> Ref:f:\pjm2\kokoro\content\printing\documentcommands\ar_re_receipt.sql ==>*/
 
/*  form   : AR_RE
	Rev.   : JEY.11.04.2018
	Rev.V2 : BANK.28.11.2018
*/

DECLARE @p0 NUMERIC(18) = 24
DECLARE @p1 NUMERIC(18) = 44 /*44 : OtherReceives | 51 : Receipt | 151 : TaxInvoice&Receive*/

DECLARE @DocId NUMERIC(18) = @p0
DECLARE @TypeId NUMERIC(18) = @p1


DECLARE @DocOrgid INT = (case when @TypeId = 44 then (select Locationid from dbo.otherreceives where id = @docid)
						   when @TypeId = 51 then (select Locationid from dbo.Receipts where id = @docid)
						   when @TypeId = 151 then (select orgid from dbo.Taxitems where id = @docid)	
					  end
					 )

/**************** 1-Info **************************************************/


-- /*Receipt*/

-- SELECT	r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date],r.TaxItemId,r.TaxItemCode
--         ,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
-- 		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
-- 		,Ex.Address ExtOrgAddress,Ex.Tel ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
--         ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
--         ,cp.ConName ExtOrgContact
-- 		,ISNULL(rl.ReceiptAmount,0) SubTotal
-- 		,ISNULL(IIF(rl.TaxBase = 0,rl.ReceiptAmount,rl.TaxBase),0) TaxBase
-- 		,ISNULL(rl.VatAmount,0) VatAmount
-- 		,ISNULL(rl.RetentionAmount,0) RetentionAmount
-- 		,((IIF(rl.TaxBase = 0,rl.ReceiptAmount,(rl.TaxBase+rl.VatAmount)) - ISNULL(rl.RetentionAmount,0))) GrandTotal
-- 		,NULL RefDocCode
-- 		,'ใบเสร็จ' HeaderTH
-- 		,'RECEIPT' HeaderEN
--         , N'收据' HeaderCN
-- 		,r.DocCurrency, r.DocCurrencyRate
--         ,FORMAT(ISNULL(rl.TaxRate,0),'N0')+'%' TaxRate
-- 		,0.00 WHTAmount
-- 		,0.00 WHTRate
-- 		,IIF(rl.TaxBase = 0,rl.ReceiptAmount,(rl.TaxBase+rl.VatAmount)) NetAmount
-- 		,0.00 DiscountAmount
-- 		,0.00 DepositAmount
--      /*คูณ DocCurrencyRate ข้างในแล้ว*/    
-- FROM	dbo.Receipts r WITH (NOLOCK)
-- 		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
-- 		LEFT JOIN (SELECT MAX(
-- 										CONCAT(
-- 											Con.Name,IIF(NULLIF(Con.Tel,'') IS NULL,NULL,' : '),IIF(NULLIF(Con.Tel,'') IS NULL,NULL,Con.Tel)
-- 											  ) 
-- 										  ) ConName
-- 									  ,Con.ExtOrganizationId
-- 							   FROM dbo.ContactPersons Con WITH (NOLOCK)
-- 							   GROUP BY Con.ExtOrganizationId
-- 							   ) Cp ON Ex.Id = Cp.ExtOrganizationId
-- 		LEFT JOIN (	SELECT	el.ReceiptId
-- 		                    ,SUM(ISNULL(el.RemainAmount,0)*re.DocCurrencyRate)ReceiptAmount
-- 							,SUM(ISNULL(el.TaxAmount*re.DocCurrencyRate,0))VatAmount
-- 							,SUM(ISNULL(el.RetentionSetDocAmount*re.DocCurrencyRate,0))RetentionAmount 
-- 							,SUM(ISNULL(el.TaxBase*re.DocCurrencyRate,0)) TaxBase
--                             ,el.TaxRate
-- 								FROM		dbo.ReceiptLines el WITH (NOLOCK)
-- 												INNER JOIN dbo.Receipts re ON re.Id = el.ReceiptId 
-- 								WHERE		ISNULL(el.SystemCategoryId,0) <> 111 
-- 												AND el.ReceiptId = @DocId AND @TypeId = 51
-- 												GROUP BY el.ReceiptId ,el.TaxRate
-- 												) rl ON rl.ReceiptId = r.Id
-- 	    LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = r.SubDocTypeId


-- WHERE	r.Id = @DocId AND @TypeId = 51

-- UNION ALL


-- /* Other Receives */

-- SELECT	
-- 		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
-- 		,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
-- 		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
-- 		,Ex.Address ExtOrgAddress,Ex.Tel ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
--         ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
--         ,cp.ConName ExtOrgContact
-- 		,ISNULL(sb.Amount,0) SubTotal
-- 		,(ISNULL(vt.TaxBase*ro.DocCurrencyRate,0)) TaxBase
-- 		,ISNULL(vt.TaxAmount*ro.DocCurrencyRate,0) VatAmount,0.00 RetentionAmount
-- 		,ISNULL(gt.Amount*ro.DocCurrencyRate,0) GrandTotal 
-- 		,ro.Code RefDocCode
-- 		,'ใบเสร็จ' HeaderTH
-- 		,'RECEIPT' HeaderEN
--         , N'收据' HeaderCN
-- 		,ro.DocCurrency
-- 		,ro.DocCurrencyRate
--         ,FORMAT(ISNULL(vt.TaxRate,0),'N0')+'%' TaxRate
-- 		,ISNULL(wt.TaxAmount,0.00) WHTAmount
-- 		,ISNULL(wt.TaxRate,0) WHTRate
--         ,(ISNULL(vt.TaxBase,0) + ISNULL(vt.TaxAmount,0)) * ISNULL(ro.DocCurrencyRate,0) NetAmount
-- 		,0.00 DiscountAmount
-- 		,0.00 DepositAmount
-- FROM	dbo.OtherReceives ro WITH (NOLOCK)
-- 			LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 44
-- 			LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
-- 			LEFT JOIN (SELECT MAX(
-- 										CONCAT(
-- 											Con.Name,IIF(NULLIF(Con.Tel,'') IS NULL,NULL,' : '),IIF(NULLIF(Con.Tel,'') IS NULL,NULL,Con.Tel)
-- 											  ) 
-- 										  ) ConName
-- 									  ,Con.ExtOrganizationId
-- 							   FROM dbo.ContactPersons Con WITH (NOLOCK)
-- 							   GROUP BY Con.ExtOrganizationId
-- 							   ) Cp ON Ex.Id = Cp.ExtOrganizationId
-- 			LEFT JOIN dbo.TaxItems t WITH (NOLOCK) ON t.SetDocId = ro.Id AND t.SetDocTypeId = 44 AND t.SystemCategoryId = 151		
-- 			LEFT JOIN (select ti.SetDocId,til.TaxBase, til.TaxAmount, til.TaxRate from TaxItemLines til 
-- 						INNER JOIN Taxitems ti ON til.TaxItemId = ti.Id 
-- 						WHERE ti.SetDocTypeId = 44 AND ti.SystemCategoryId = 36 ) wt ON wt.SetDocId = ro.Id 
-- 			LEFT JOIN dbo.OtherReceiveLines gt WITH (NOLOCK) ON gt.SystemCategoryId = 111 AND gt.OtherReceiveId = ro.Id
-- 			LEFT JOIN dbo.OtherReceiveLines sb WITH (NOLOCK) ON sb.SystemCategoryId = 107 AND sb.OtherReceiveId = ro.Id
-- 			LEFT JOIN dbo.OtherReceiveLines vt WITH (NOLOCK) ON vt.SystemCategoryId IN (123,129,131,199) AND vt.OtherReceiveId = ro.Id
-- 			LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = ro.SubDocTypeId
-- WHERE	ro.Id = @DocId AND @TypeId = 44

-- UNION ALL

-- /* TaxInvoiceAndReceipts */

-- SELECT	
-- 		r.Id,r.Code,FORMAT(r.Date,'dd/MM/yyyy') [Date], t.Id TaxItemId, t.Code TaxItemCode
-- 		,r.DocTypeId,r.DocType,r.Remarks,r.LocationId,r.LocationCode,r.LocationName
-- 		,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
-- 		,Ex.Address ExtOrgAddress,Ex.Tel ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
--         ,CASE WHEN ISNULL(Ex.BranchName,'') = '' THEN Ex.BranchCode ELSE Ex.BranchName END ExtOrgBranch
--         ,cp.ConName ExtOrgContact
-- 		,ISNULL(rl.SubTotal,0) SubTotal
-- 		,ISNULL((rl.ReceiptAmount+ rl.RetentionAmount-rl.VatAmount),0) TaxBase
-- 		,ISNULL(rl.VatAmount,0) VatAmount,ISNULL(rl.RetentionAmount,0) RetentionAmount,ISNULL(rl.ReceiptAmount,0) GrandTotal
-- 		,NULL RefDocCode
-- 		,'ใบกำกับภาษี & ใบเสร็จ' HeaderTH
-- 		,'TAX INVOICE & RECEIPT' HeaderEN 
--         , N'税务发票 & 收据' HeaderCN
-- 		,t.DocCurrency
-- 		,t.DocCurrencyRate
--         ,FORMAT(ISNULL(t.TaxRate,0),'N0')+'%' TaxRate
-- 		,0.00 WHTAmount
-- 		,0.00 WHTRate
-- 		,ISNULL((rl.ReceiptAmount+ rl.RetentionAmount-rl.VatAmount),0) + ISNULL(rl.VatAmount,0) NetAmount
-- 		,0.00 DiscountAmount
-- 		,0.00 DepositAmount
-- 		 /*คูณ DocCurrencyRate ข้างในแล้ว*/ 
-- FROM	dbo.TaxItems t WITH (NOLOCK)
-- 		LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = t.Id AND r.DocTypeId = 151
-- 		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON ex.Id = r.ExtOrgId
-- 		LEFT JOIN (SELECT MAX(
-- 										CONCAT(
-- 											Con.Name,IIF(NULLIF(Con.Tel,'') IS NULL,NULL,' : '),IIF(NULLIF(Con.Tel,'') IS NULL,NULL,Con.Tel)
-- 											  ) 
-- 										  ) ConName
-- 									  ,Con.ExtOrganizationId
-- 							   FROM dbo.ContactPersons Con WITH (NOLOCK)
-- 							   GROUP BY Con.ExtOrganizationId
-- 							   ) Cp ON Ex.Id = Cp.ExtOrganizationId		
-- 		LEFT JOIN (	SELECT	tl.TaxItemId,SUM(IIF(tl.SystemCategoryId = 49,tl.Amount,0)*ti.DocCurrencyRate)RetentionAmount
-- 										,SUM(IIF(tl.SystemCategoryId IN (123,129),tl.TaxAmount,0)*ti.DocCurrencyRate) VatAmount
-- 										,SUM(IIF(tl.SystemCategoryId = 111,tl.Amount,0)*ti.DocCurrencyRate) ReceiptAmount 
-- 										,SUM(IIF(tl.SystemCategoryId = 107,tl.Amount,0)*ti.DocCurrencyRate) SubTotal
-- 								FROM		dbo.TaxItemLines tl WITH (NOLOCK)
-- 												INNER JOIN dbo.TaxItems ti WITH (NOLOCK) ON ti.Id = tl.TaxItemId 
-- 								WHERE		tl.TaxItemId = @DocId AND @TypeId = 151
-- 												GROUP BY tl.TaxItemId 
-- 												) rl ON rl.TaxItemId = t.Id
-- 		LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = t.SubDocTypeId

-- WHERE	t.Id = @DocId AND @TypeId = 151



-- --/*2-Line*/
-- ------------------------------------------------------------------------------------------------------------------------------------------------------:)

-- /* OtherReceives */

-- SELECT	rl.LineNumber,rl.Description,ro.Code RefIVCode
-- 		,1 Qty
-- 		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) UnitPrice
-- 		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) ReceiptAmount
-- 		,r.DocCurrencyRate
-- FROM		dbo.OtherReceives ro WITH (NOLOCK)
-- 				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = ro.Id AND r.DocTypeId = 44
-- 				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
-- WHERE		ro.Id = @DocId AND @TypeId = 44


-- UNION ALL


-- /*Receipt*/

-- SELECT	rl.LineNumber,rl.Description,rl.RefIVCode,1 Qty
-- 		,ISNULL(rl.RemainAmount * r.DocCurrencyRate,0) UnitPrice
-- 		,ISNULL(rl.RemainAmount * r.DocCurrencyRate,0) ReceiptAmount
-- 		,r.DocCurrencyRate
-- FROM		dbo.ReceiptLines rl WITH (NOLOCK)
--             INNER JOIN dbo.Receipts r WITH (NOLOCK) ON r.Id = rl.ReceiptId
-- WHERE		rl.ReceiptId = @DocId AND @TypeId = 51
-- 				AND ISNULL(rl.SystemCategoryId,0) <> 111

-- UNION ALL

-- /* TaxInvoiceAndReceipts */

-- SELECT	rl.LineNumber,rl.Description,rl.RefIVCode,1 Qty
-- 		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) UnitPrice
-- 		,ISNULL(rl.ReceiptAmount * r.DocCurrencyRate,0) ReceiptAmount
-- 		,r.DocCurrencyRate
-- FROM		dbo.TaxItems t WITH (NOLOCK)
-- 				LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = t.Id AND r.DocTypeId = 151
-- 				LEFT JOIN dbo.ReceiptLines rl WITH (NOLOCK) ON rl.ReceiptId = r.Id AND rl.SystemCategoryId <> 111
-- WHERE		t.Id = @DocId AND @TypeId = 151


-- /*3-Other*/
-- -----------------------------------------------------------------------------------------------------------------------------------------------
-- SELECT @TypeId DocTypeId

-- /*4-Payment*/
-- -----------------------------------------------------------------------------------------------------------------------------------------------
-- SELECT  
--                 pa.LineNumber
--                 ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.LocalBankName,b.LocalBankName) BankCode
--                 ,IIF(ISNULL(pa.FiscalItemCode,'') = '',CONCAT(pa.BankCode,' : ',pa.LocalBankName),CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
-- 				,pa.Branch,pa.AcctNumber
--                 ,FORMAT(IIF(ISNULL(pa.FiscalDueDate,'')='' AND ISNULL(pa.Amount,0) <> 0,j.MadeByDocDate,pa.FiscalDueDate),'dd/MM/yy') FiscalDueDate
--                 ,pa.FiscalItemCode,FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n')ReceiveAmt
-- 				,IIF(ISNULL(pa.FiscalItemCode,'') = '',0,1) isCheck
-- 				,IIF(ISNULL(pa.FiscalItemCode,'') = '',1,0) isBank
-- 				,0 isCash

--         FROM    dbo.JournalVouchers j WITH (NOLOCK)
-- 				LEFT JOIN OtherReceivelines orl ON orl.OtherReceiveId = j.MadeByDocId AND orl.SystemCategoryId = 58
-- 				LEFT JOIN dbo.Banks b WITH (NOLOCK) ON b.localBankCode = orl.FiscalItemCheckBank AND b.RegionalCode = 'TH'
--                 LEFT JOIN ( 
--                             SELECT  ROW_NUMBER() OVER (PARTITION BY jl.JournalVoucherId ORDER BY jl.Id)LineNumber
-- 																		,jl.JournalVoucherId,jl.isDebit
--                                     ,IIF(jl.FiscalMetaCode = 'Deduct',jl.FiscalMetaCode,ba.BankCode) BankCode
--                                     ,IIF(jl.FiscalMetaCode = 'Deduct',jl.Description,ba.AcctNumber) AcctNumber
--                                     ,jl.FiscalItemCode,jl.FiscalDueDate,jl.Amount,ba.Branch,b.LocalBankName
--                             FROM    dbo.JVLines jl WITH (NOLOCK)
--                                     LEFT JOIN dbo.BankAccts ba WITH (NOLOCK) ON ba.Id = jl.BankAcctId 
-- 									LEFT JOIN dbo.Banks b WITH (NOLOCK) ON b.localBankCode = ba.BankCode AND b.RegionalCode = 'TH'
--                             WHERE   (ISNULL(jl.BankAcctId,0) <> 0 OR jl.FiscalMetaCode = 'Deduct')
--                                     ) pa ON pa.JournalVoucherId = j.Id
		
--         WHERE   j.MadeByTypeId = @TypeId AND j.MadeByDocId = @DocId
--                 AND j.MadeByTypeId IN (44,52) AND pa.LineNumber = 1
-- 		Union ALL
-- 		Select pa.LineNumber,pa.BankCode,pa.BankCodeFull,pa.Branch,pa.AcctNumber,pa.FiscalDueDate,pa.FiscalItemCode,pa.ReceiveAmt,pa.isCheck,pa.isBank,pa.isCash
-- 		From ReceiveVoucherLines rvl
-- 		LEFT JOIN (
-- 					Select	rvl.ReceiveVoucherId,rvl.LineNumber
--                             ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',b.LocalBankName,b.LocalBankName) BankCode
--                             ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',CONCAT(ba.BankCode,' : ',b.LocalBankName),CONCAT(rvl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
-- 							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') Branch,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') AcctNumber
-- 							,FORMAT(IIF(ISNULL(rvl.FiscalDueDate,'')='' /*AND ISNULL(rvl.Amount,0) <> 0*/,rv.Date,rvl.FiscalDueDate),'dd/MM/yy') FiscalDueDate
-- 							,rvl.FiscalItemCode,FORMAT(rvl.PayAmount,'n')ReceiveAmt
-- 							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',0,1) isCheck
-- 							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',1,0) isBank
-- 							,0 isCash
-- 					From ReceiveVouchers rv
-- 					LEFT JOIN ReceiveVoucherLines rvl ON rvl.ReceiveVoucherId = rv.Id
-- 					LEFT JOIN BankAccts ba WITH (NOLOCK) ON ba.Id = rvl.BankAcctId 
-- 					LEFT JOIN Banks b WITH (NOLOCK) ON b.localBankCode = ba.BankCode AND b.RegionalCode = 'TH'
-- 					Where rvl.FiscalMetaId IS NOT NULL --rvl.SystemCategoryId = 51
-- 		) pa ON pa.ReceiveVoucherId = rvl.ReceiveVoucherId
-- 		Where rvl.SystemCategoryId = 51 AND rvl.ReceiptId = @DocId
-- 				AND @TypeId IN (51,151);

-- /*5-Company*/
-- -----------------------------------------------------------------------------------------------------------------------------------------------
-- EXEC [dbo].[CompanyInfoByOrg] @DocOrgid 
-----------------------------------------------------------------------------------------------------------------------------------------------
/*6-Receive Method*/
-----------------------------------------------------------------------------------------------------------------------------------------------
-- IF (@typeId = 44)
    SELECT r.LineNumber,IIF(r.isCheck = 1,r.BankCode,Null) BankCode,r.BankCodeFull,IIF(isCheck = 1,r.Branch,NULL) Branch
        ,IIF(isBank = 1,r.AcctNumber,NULL) AcctNumber
        ,IIF(isCheck = 1,r.FiscalDueDate,NULL) FiscalDueDate,IIF(isCheck = 1,r.FiscalItemCode,NULL) FiscalItemCode
        ,IIF(isBank = 1,r.ReceiveAmt,NULL) ReceiveAmt
        ,r.isCheck,r.isBank,r.isCash
FROM
(
    SELECT  
            pa.LineNumber
            ,IIF(ISNULL(pa.FiscalItemCode,'') = '',b.LocalBankName,pa.LocalBankName) BankCode
			,IIF(ISNULL(pa.FiscalItemCode,'') = '',CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName),CONCAT(pa.BankCode,' : ',pa.LocalBankName)) BankCodeFull
            ,pa.Branch,pa.AcctNumber
            ,FORMAT(IIF(ISNULL(pa.FiscalDueDate,'')='' AND ISNULL(pa.Amount,0) <> 0,j.MadeByDocDate,pa.FiscalDueDate),'dd/MM/yyyy') FiscalDueDate
            ,pa.FiscalItemCode,FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n')ReceiveAmt
            ,IIF(ISNULL(pa.FiscalItemCode,'') = '',0,1) isCheck
            ,IIF(ISNULL(pa.FiscalItemCode,'') = '',1,0) isBank
            ,0 isCash

        FROM    dbo.JournalVouchers j WITH (NOLOCK)
				LEFT JOIN OtherReceivelines orl ON orl.OtherReceiveId = j.MadeByDocId AND orl.SystemCategoryId = 59
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
		Select pa.LineNumber,pa.BankCode,pa.BankCodeFull,pa.Branch,pa.AcctNumber,pa.FiscalDueDate,pa.FiscalItemCode,pa.ReceiveAmt,pa.isCheck,pa.isBank,pa.isCash
		From ReceiveVoucherLines rvl
		LEFT JOIN (
					Select	rvl.ReceiveVoucherId,rvl.LineNumber
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',b.LocalBankName,b.LocalBankName) BankCode
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',CONCAT(ba.BankCode,' : ',b.LocalBankName),CONCAT(rvl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') Branch,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') AcctNumber
							,FORMAT(IIF(ISNULL(rvl.FiscalDueDate,'')='' /*AND ISNULL(rvl.Amount,0) <> 0*/,rv.Date,rvl.FiscalDueDate),'dd/MM/yyyy') FiscalDueDate
							,rvl.FiscalItemCode,FORMAT(rvl.PayAmount,'n')ReceiveAmt
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',0,1) isCheck
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',1,0) isBank
							,0 isCash
					From ReceiveVouchers rv
					LEFT JOIN ReceiveVoucherLines rvl ON rvl.ReceiveVoucherId = rv.Id
					LEFT JOIN BankAccts ba WITH (NOLOCK) ON ba.Id = rvl.BankAcctId 
					LEFT JOIN Banks b WITH (NOLOCK) ON b.localBankCode = ba.BankCode AND b.RegionalCode = 'TH'
					Where rvl.FiscalMetaId IS NOT NULL --rvl.SystemCategoryId = 51
		) pa ON pa.ReceiveVoucherId = rvl.ReceiveVoucherId
		Where rvl.SystemCategoryId = 51 AND rvl.ReceiptId = @DocId
				AND @TypeId IN (51,151)
) r;

-- ELSE
    SELECT  
                pa.LineNumber
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '',b.LocalBankName,pa.LocalBankName) BankCode
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '',CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName),CONCAT(pa.BankCode,' : ',pa.LocalBankName)) BankCodeFull
				,pa.Branch,pa.AcctNumber
                ,FORMAT(IIF(ISNULL(pa.FiscalDueDate,'')='' AND ISNULL(pa.Amount,0) <> 0,j.MadeByDocDate,pa.FiscalDueDate),'dd/MM/yyyy') FiscalDueDate
                ,pa.FiscalItemCode,FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n')ReceiveAmt
				,IIF(ISNULL(pa.FiscalItemCode,'') = '',0,1) isCheck
				,IIF(ISNULL(pa.FiscalItemCode,'') = '',1,0) isBank
				,0 isCash

        FROM    dbo.JournalVouchers j WITH (NOLOCK)
				LEFT JOIN OtherReceivelines orl ON orl.OtherReceiveId = j.MadeByDocId AND orl.SystemCategoryId = 59
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
		Select pa.LineNumber,pa.BankCode,pa.BankCodeFull,pa.Branch,pa.AcctNumber,pa.FiscalDueDate,pa.FiscalItemCode,pa.ReceiveAmt,pa.isCheck,pa.isBank,pa.isCash
		From ReceiveVoucherLines rvl
		LEFT JOIN (
					Select	rvl.ReceiveVoucherId,rvl.LineNumber
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',b.LocalBankName,b.LocalBankName) BankCode
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',CONCAT(ba.BankCode,' : ',b.LocalBankName),CONCAT(rvl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') Branch,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') AcctNumber
							,FORMAT(IIF(ISNULL(rvl.FiscalDueDate,'')='' /*AND ISNULL(rvl.Amount,0) <> 0*/,rv.Date,rvl.FiscalDueDate),'dd/MM/yyyy') FiscalDueDate
							,rvl.FiscalItemCode,FORMAT(rvl.PayAmount,'n')ReceiveAmt
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',0,1) isCheck
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',1,0) isBank
							,0 isCash
					From ReceiveVouchers rv
					LEFT JOIN ReceiveVoucherLines rvl ON rvl.ReceiveVoucherId = rv.Id
					LEFT JOIN BankAccts ba WITH (NOLOCK) ON ba.Id = rvl.BankAcctId 
					LEFT JOIN Banks b WITH (NOLOCK) ON b.localBankCode = ba.BankCode AND b.RegionalCode = 'TH'
					Where rvl.FiscalMetaId IS NOT NULL --rvl.SystemCategoryId = 51
		) pa ON pa.ReceiveVoucherId = rvl.ReceiveVoucherId
		Where rvl.SystemCategoryId = 51 AND rvl.ReceiptId = @DocId
				AND @TypeId IN (51,151);