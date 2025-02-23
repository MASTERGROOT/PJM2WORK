/*==> Ref:i:\pjm2\scon\content\printing\documentcommands\ar_tiv_taxinvoice.sql ==>*/
 
/*==> Ref:f:\pjm2\kokoro\content\printing\documentcommands\ar_tiv_taxinvoice.sql ==>*/
 
/*==> Ref:f:\pjm2\kokoro\content\printing\documentcommands\ar_tiv_taxinvoice.sql ==>*/
 
/*44 = OtherReceive | 51 = Receipt | 151 = TaxInvoiceAndReceipt | 41 = CreditNote | 42 = DerbitNote | 38 = InvoiceAR*/

DECLARE @p0 INT = 6--(Select id From dbo.TaxItems Where SetDocCode = 'SSi-IV202208010')
DECLARE @p1 INT = 44

DECLARE @DocId INT = @p0
DECLARE @typeId INT = @p1
DECLARE @TaxItemId INT = (CASE WHEN @typeId = 51 THEN (SELECT	TaxItemId FROM	dbo.Receipts WHERE Id = @DocId AND DocTypeId = @typeId AND SystemCategoryId NOT IN (138,36))
                               WHEN @typeId IN (38,44,41,42) THEN (SELECT Id FROM	dbo.TaxItems WHERE SetDocId = @DocId AND SetDocTypeId = @typeId AND SystemCategoryId NOT IN (138,36))
                               ELSE (SELECT Id FROM	dbo.TaxItems WHERE Id = @DocId AND SetDocTypeId = @typeId  AND SystemCategoryId NOT IN (138,36)) END)

DECLARE @DocOrgid INT = (CASE WHEN @typeId = 51 THEN (SELECT Locationid FROM	dbo.Receipts WHERE Id = @DocId AND DocTypeId = @typeId AND SystemCategoryId NOT IN (138,36))
                               WHEN @typeId IN (38,44,41,42) THEN (SELECT Orgid FROM	dbo.TaxItems WHERE SetDocId = @DocId AND SetDocTypeId = @typeId AND SystemCategoryId NOT IN (138,36))
                               ELSE (SELECT Orgid FROM	dbo.TaxItems WHERE Id = @DocId AND SetDocTypeId = @typeId  AND SystemCategoryId NOT IN (138,36)) END)


/*1-Info*/
------------------------------------------------------------------------------------------------------------------------------------------------:)
SELECT  
					i.Id,i.Code,FORMAT(i.Date,'dd/MM/yyyy') Date,i.CreateBy,i.CreateTimestamp
					,i.ExtOrgId, ISNULL(i.ExtOrgCode,Ex.Code) ExtOrgCode, ISNULL(i.ExtOrgName,Ex.Name) ExtOrgName
					,ISNULL(i.ExtOrgAddress,Ex.Address) ExtOrgAddress, ISNULL(NULLIF(i.ExtOrgTaxID,''),Ex.TaxId) ExtOrgTaxId
					,Ex.Tel ExtOrgTel,Ex.Fax ExtOrgFax
					,CASE WHEN ISNULL(NULLIF(i.ExtOrgBranchCode,''),Ex.BranchCode) = '00000' THEN 'สำนักงานใหญ่'
								WHEN ISNULL(Ex.BranchName,'') != '' THEN Ex.BranchName 
								ELSE ISNULL(NULLIF(i.ExtOrgBranchCode,''),Ex.BranchCode) END ExtOrgBranch
					,Con.ConName ContractName
					,CASE WHEN @typeId = 151 THEN r.LocationId
					      WHEN @typeId = 44  THEN OrOrg.Id
					 ELSE s.OrgId END LocationId
					,CASE WHEN @typeId = 151 THEN r.LocationCode
					      WHEN @typeId = 44  THEN OrOrg.Code
					 ELSE s.OrgCode END LocationCode
					,CASE WHEN @typeId = 151 THEN r.LocationName  
					      WHEN @typeId = 44  THEN OrOrg.Name  
					 ELSE s.OrgName   END LocationName     
					,ISNULL(IIF(@typeId = 151,R.Code,s.DocCode),i.SetDocCode) SetDocCode
					,(ISNULL(i.TaxBase,0)*i.DocCurrencyRate) + (ISNULL(de.DepositAmount,0)*i.DocCurrencyRate) SubTotal
					,ISNULL(de.DepositAmount,0)*i.DocCurrencyRate DepositAmount,ISNULL(ds.DiscountAmount,0)*i.DocCurrencyRate DiscountAmount
					,ISNULL(i.TaxBase,0)*i.DocCurrencyRate TaxBase,FORMAT(ISNULL(i.TaxRate,0),'N0')+'%' TaxRate
					,ISNULL(i.TaxAmount,0)*i.DocCurrencyRate TaxAmount,ISNULL(tl.SubtractRetention*i.DocCurrencyRate,0) RetentionAmount
					,(ISNULL(i.TaxBase,0)+ISNULL(i.TaxAmount,0)-ISNULL(tl.SubtractRetention,0)-ISNULL(wht.TaxAmount,ISNULL(Convert(Decimal(18,6),cl2.DataValues),ISNULL(i.TaxBase,0)*ISNULL(wht.TaxRate,ISNULL(Convert(Decimal(18,6),cl.DataValues),0))/100)))*i.DocCurrencyRate GrandTotal

					,CONCAT(IIF(se.Description NOT LIKE '%[a-z]%',se.Description,IIF(se.Name NOT LIKE '%[a-z]%',se.Name,'ใบกำกับภาษี'))
					        ,'  ('
							,IIF(se.Description LIKE '%[a-z]%',se.Description,'TaxInvoice')
							,')'
						    ) Header 
					/*,CASE WHEN se.DocTypeId IN (140,146,151,153,155,156) THEN IIF(se.Description NOT LIKE '%[a-z]%',se.Description,IIF(se.Name NOT LIKE '%[a-z]%',se.Name,'ใบกำกับภาษี'))
					      ELSE 'ใบกำกับภาษี' END HeaderTH */
					/*,CASE WHEN se.DocTypeId IN (140,146,151,153,155,156) THEN IIF(se.Description LIKE '%[a-z]%',se.Description,IIF(se.Name LIKE '%[a-z]%',se.Name,'TaxInvoice'))
					      ELSE 'TaxInvoice' END HeaderEN*/
					,CASE	WHEN @typeId = 38 THEN 'ใบเสร็จรับเงิน/ใบกำกับภาษี'
							WHEN @typeId = 44 AND ISNULL(IIF(@typeId = 151,R.Code,s.DocCode),i.SetDocCode) LIKE 'ORAR%' THEN 'ใบแจ้งหนี้/ใบกำกับภาษี' 
							WHEN @typeId IN (151,44) THEN 'ใบเสร็จรับเงิน/ใบกำกับภาษี' 
                            ELSE 'ใบเสร็จรับเงิน/ใบกำกับภาษี' 
                            END HeaderTH
					,CASE	WHEN @typeId = 38 THEN 'RECEIPT/TAX INVOICE'
							WHEN @typeId = 44 AND ISNULL(IIF(@typeId = 151,R.Code,s.DocCode),i.SetDocCode) LIKE 'ORAR%' THEN 'INVOICE/TAX INVOICE' 
							WHEN @typeId IN (151,44) THEN 'RECEIPT/TAX INVOICE' 
                            ELSE 'RECEIPT/TAX INVOICE' 
                            END HeaderEN
                    ,CASE	WHEN @typeId = 38 THEN N'收据/税务发票'
							WHEN @typeId = 44 AND ISNULL(IIF(@typeId = 151,R.Code,s.DocCode),i.SetDocCode) LIKE 'ORAR%' THEN N'请款单/税务发票' 
							WHEN @typeId IN (151,44) THEN N'收据/税务发票' 
                            ELSE N'收据/税务发票' 
                            END HeaderCN
					,IIF(@typeId NOT IN (41,42),i.Remarks,aia.Remarks) Remarks
					,ISNULL(wht.TaxAmount,ISNULL(Convert(Decimal(18,6),cl2.DataValues),ISNULL(i.TaxBase,0)*ISNULL(wht.TaxRate,ISNULL(Convert(Decimal(18,6),cl.DataValues),0))/100))*i.DocCurrencyRate WHTAmount 
                    ,ISNULL(wht.TaxRate,ISNULL(Convert(Decimal(18,6),cl.DataValues)/100,0)) WHTRate
                    ,((ISNULL(i.TaxBase,0)+ISNULL(i.TaxAmount,0))*i.DocCurrencyRate) NetAmount
					,ISNULL(tl.SetDocCode,'-') RefDocCode
					
					
     			
FROM			dbo.TaxItems i WITH (NOLOCK)
					LEFT JOIN (SELECT TaxItemId, SUM(ISNULL(Amount,0)) DepositAmount 
					           FROM dbo.TaxItemLines WITH (NOLOCK) 
							   WHERE SystemCategoryId = 55 AND Description = 'DepositReceive' AND TaxItemId = @TaxItemId 
							   GROUP BY TaxItemId) de ON de.TaxItemId = i.Id
					LEFT JOIN (SELECT TaxItemId, SUM(ISNULL(Amount,0)) DiscountAmount 
					           FROM dbo.TaxItemLines WITH (NOLOCK) 
							   WHERE SystemCategoryId = 124 AND Description = 'Discount' AND TaxItemId = @TaxItemId 
							   GROUP BY TaxItemId) ds ON ds.TaxItemId = i.Id
					LEFT JOIN dbo.ExtOrganizations Ex WITH (NOLOCK) ON i.ExtOrgId = Ex.Id
					LEFT JOIN (SELECT [or].guid, o.Id, o.Code, o.Name, o.Address, o.SubDocTypeId
							   FROM	dbo.OtherReceives [or] WITH (NOLOCK)
									INNER JOIN dbo.Organizations o WITH (NOLOCK) ON o.id = [or].LocationId
					          ) OrOrg ON i.SetDocTypeId = 44 AND OrOrg.guid = i.SetDocGuId
					LEFT JOIN (SELECT MAX(
										CONCAT(
											Con.Name,IIF(NULLIF(Con.Tel,'') IS NULL,NULL,' : '),IIF(NULLIF(Con.Tel,'') IS NULL,NULL,Con.Tel)
											  ) 
										  ) ConName
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Con ON Ex.Id = Con.ExtOrganizationId
					LEFT JOIN dbo.AcctElementSets s WITH (NOLOCK) ON s.DocId = i.SetDocId AND s.DocTypeId = i.SetDocTypeId AND s.GeneralAccount IN (111,119) AND ISNULL(s.Canceled,0) != 1
					LEFT JOIN dbo.Receipts r WITH (NOLOCK) ON r.TaxItemId = i.Id AND r.DocTypeId = 151
					LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = i.SubDocTypeId
					LEFT JOIN dbo.AdjustInvoiceARs aia WITH (NOLOCK) ON aia.id = i.SetDocId AND aia.DocTypeId = i.SetDocTypeId
					LEFT JOIN (	Select t.Id,t.SetDocId,t.TaxBase,t.TaxAmount,tl.TaxRate From dbo.TaxItems t
								Left Join dbo.TaxItemLines tl ON tl.TaxItemId = t.Id
								Where t.SetDocId = @DocId AND t.SetDocTypeId = @typeId AND t.SystemCategoryId = 36) wht ON wht.SetDocId = i.SetDocId
					LEFT JOIN TaxItemLines tl ON tl.TaxItemId = i.Id AND tl.LineNumber = 1
                    LEFT JOIN dbo.CustomNoteLines cl ON cl.DocGuid = i.SetDocGuId AND cl.KeyName = 'WHTRate'
                    LEFT JOIN dbo.CustomNoteLines cl2 ON cl.DocGuid = i.SetDocGuId AND cl.KeyName = 'WHTAmount'


WHERE			i.Id = @TaxItemId

                                   

/*2-Line*/
----------------------------------------------------------------------------------------------------------------------------------------------------:)

SELECT	PL.Line_No,PL.DocId,PL.Description,PL.DocQty,PL.DocUnitName,PL.UnitPrice,PL.Discount,PL.Amount,PL.Code

FROM	(	

				SELECT	ROW_NUMBER() OVER (ORDER BY il.Id) Line_No
								,ROW_NUMBER() OVER (ORDER BY il.Id) LineNumber,IIF(@typeId = 151,t.Id,il.SetDocId) DocId
								,il.Description,il.DocQty,il.DocUnitName,(il.UnitPrice*ISNULL(t.DocCurrencyRate,1))UnitPrice
								,NULLIF(il.Discount,'0')Discount,(il.Amount*ISNULL(t.DocCurrencyRate,1))Amount
								,t.Code
				FROM		dbo.TaxItemLines il WITH (NOLOCK)
								INNER JOIN dbo.TaxItems t WITH (NOLOCK) ON il.TaxItemId = t.Id
				WHERE		t.SystemCategoryId IN (146,151)
								AND IIF(@typeId = 151,t.Id,t.SetDocId) = @DocId 
								AND t.SetDocTypeId = @typeId
								AND ISNULL(il.DocQty,0) != 0
								AND @typeId IN (44,151)

				UNION ALL

				SELECT	NULL Line_No
								,ROW_NUMBER() OVER (ORDER BY il.Id) LineNumber
								,IIF(@typeId = 151,t.Id,il.SetDocId) DocId
								,il.Description
								,NULL DocQty
								,NULL DocUnitName
								,NULL UnitPrice
								,NULL Discount,NULL Amount
								,t.Code
				FROM		dbo.TaxItemLines il WITH (NOLOCK)
								INNER JOIN dbo.TaxItems t WITH (NOLOCK) ON il.TaxItemId = t.Id
				WHERE		t.SystemCategoryId IN (146,151)
								AND IIF(@typeId = 151,t.Id,t.SetDocId) = @DocId 
								AND t.SetDocTypeId = @typeId
								AND il.SystemCategoryId = -2
								AND @typeId IN (44,151)

				UNION ALL

				SELECT	ROW_NUMBER() OVER (ORDER BY il.LineNumber) Line_No
								,il.LineNumber,il.InvoiceARId DocId
								,CONCAT(il.ItemMetaName + ' ',ISNULL(il.Description,il.ItemMetaName))Description
								,il.DocQty,il.DocUnitName,(il.UnitPrice*ISNULL(i.DocCurrencyRate,1))UnitPrice
								,NULLIF(il.Discount,'0')Discount,(il.Amount*ISNULL(i.DocCurrencyRate,1))Amount
								,i.Code
				FROM		dbo.InvoiceARLines il WITH (NOLOCK)
								LEFT JOIN dbo.InvoiceARs i WITH (NOLOCK) ON i.Id = il.InvoiceARId
				WHERE		il.InvoiceARId = @DocId 
								AND ISNULL(il.DocQty,0) != 0
								AND ISNULL(il.SystemCategoryId,0) != -2
								AND @typeId = 38

				UNION	 ALL
																
				SELECT	NULL Line_No,il.LineNumber,il.InvoiceARId DocId,il.Description,NULL DocQty,NULL DocUnitName
								,NULL UnitPrice,NULL Discount,NULL Amount, NULL Code
				FROM		dbo.InvoiceARLines il WITH (NOLOCK)
				WHERE		il.InvoiceARId = @DocId AND il.SystemCategoryId IN (-2)
								AND @typeId = 38
				UNION ALL

				SELECT	ROW_NUMBER() OVER (ORDER BY il.Id) Line_No
								,ROW_NUMBER() OVER (ORDER BY il.Id) LineNumber
								,IIF(@typeId = 151,t.Id,il.SetDocId) DocId
								,il.Description,il.DocQty,il.DocUnitName
								,(il.TaxBase*ISNULL(t.DocCurrencyRate,1))UnitPrice
								,NULLIF(il.Discount,'0')Discount
								,(il.TaxBase*ISNULL(t.DocCurrencyRate,1)) - (il.DiscountAmount*ISNULL(t.DocCurrencyRate,1))Amount
								,t.Code
				FROM		dbo.TaxItemLines il WITH (NOLOCK)
								INNER JOIN dbo.TaxItems t WITH (NOLOCK) ON il.TaxItemId = t.Id
				WHERE		t.SystemCategoryId = 151
								AND IIF(@typeId = 151,t.Id,t.SetDocId) = @DocId 
								AND t.SetDocTypeId = @typeId
								AND ISNULL(il.DocQty,0) != 0
								AND @typeId IN (41,42)

				
	) pl
				ORDER BY pl.LineNumber

/*3-Other*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT '3-Other' TableMappingName;

/*4-Receive Method*/
-----------------------------------------------------------------------------------------------------------------------------------------------

    SELECT  
                pa.LineNumber
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.LocalBankName,b.LocalBankName) BankCode
                ,IIF(ISNULL(pa.FiscalItemCode,'') = '',CONCAT(pa.BankCode,' : ',pa.LocalBankName),CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
				,pa.Branch,pa.AcctNumber
                ,FORMAT(IIF(ISNULL(pa.FiscalDueDate,'')='' AND ISNULL(pa.Amount,0) <> 0,j.MadeByDocDate,pa.FiscalDueDate),'dd/MM/yy') FiscalDueDate
                ,pa.FiscalItemCode,FORMAT(IIF(pa.isDebit = 1,pa.Amount,pa.Amount*-1),'n')ReceiveAmt
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
		Select pa.LineNumber,pa.BankCode,pa.BankCodeFull,pa.Branch,pa.AcctNumber,pa.FiscalDueDate,pa.FiscalItemCode,pa.ReceiveAmt,pa.isCheck,pa.isBank,pa.isCash
		From ReceiveVoucherLines rvl
		LEFT JOIN (
					Select	rvl.ReceiveVoucherId,rvl.LineNumber
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',b.LocalBankName,b.LocalBankName) BankCode
                            ,IIF(ISNULL(rvl.FiscalItemCode,'') = '',CONCAT(ba.BankCode,' : ',b.LocalBankName),CONCAT(rvl.FiscalItemCheckBank,' : ',b.LocalBankName)) BankCodeFull
							,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') Branch,IIF(ISNULL(rvl.FiscalItemCode,'') = '',ba.Branch,'') AcctNumber
							,FORMAT(IIF(ISNULL(rvl.FiscalDueDate,'')='' /*AND ISNULL(rvl.Amount,0) <> 0*/,rv.Date,rvl.FiscalDueDate),'dd/MM/yy') FiscalDueDate
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

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @DocOrgid
-----------------------------------------------------------------------------------------------------------------------------------------------