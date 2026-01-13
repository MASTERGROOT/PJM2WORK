/* FORM : AR_IV_Invoice */
 /*@typeId = 44 ; OtherReceives // @typeId = 38 ; InvoiceARs*/

DECLARE @p0 INT = 8
DECLARE @p1 INT = 38

DECLARE @DocId INT = @p0
DECLARE @typeId INT = @p1
DECLARE @DocOrgid INT = (case when @TypeId = 44 then (select Locationid from dbo.OtherReceives where id = @docid)
						   when @TypeId = 38 then (select Locationid from dbo.InvoiceARs where id = @docid)
                         when @TypeId = 438 then (select Locationid from dbo.ProductInvoiceARs where id = @docid)
					  end
					 )
DECLARE @LSName TABLE (UnitName NVARCHAR(20))
INSERT INTO @LSName (UnitName)
    SELECT value FROM STRING_SPLIT((SELECT aliasName FROM unitmeasurements WHERE QuantityName LIKE 'LS'), ',')

/* 1-Info */

SELECT		i.Id,i.Code,FORMAT(i.Date,'dd/MM/yyyy') [Date],i.Remarks,i.CreateBy,i.CreateTimestamp,38 InvTypeId
	        ,Ex.Id ExtOrgId,Ex.Code ExtOrgCode,Ex.Name ExtOrgName
			,Ex.Address ExtOrgAddress,Ex.Tel ExtOrgTel,Ex.Fax ExtOrgFax,Ex.TaxId ExtOrgTaxId
			,CASE WHEN ISNULL(Ex.BranchCode,'') = '00000' THEN 'สำนักงานใหญ่'
				  WHEN ISNULL(Ex.BranchName,'') <> '' THEN Ex.BranchName 
				  ELSE ex.BranchCode END ExtOrgBranch
			,Con.ConName ContractName, ISNULL(con.Contel,ex.tel) ContractTel,ISNULL(con.ConEmail,ex.Mail) ContractEmail
			,i.LocationId,i.LocationCode,i.LocationName  
			,l.ContractNo, l.QuotationNo, /*l.PaymentCondition,*/ l.CreditTerms, l.SubTotal
			, l.SPDiscount


			,l.DepositAR, l.TaxBase, l.TaxRate, l.TaxAmount
			,FORMAT((ISNULL(inp.RetentionRate,0)),'N0')+'%' RetentionRate 
			,l.RetentionAR,l.GrandTotal
			,'ใบแจ้งหนี้' HeaderTH
		    ,'INVOICE AR' HeaderEN
			/*,IIF(se.Description NOT LIKE '%[a-z]%',se.Description,IIF(se.Name NOT LIKE '%[a-z]%',se.Name,'ใบแจ้งหนี้')) HeaderTH
			,IIF(se.Description LIKE '%[a-z]%',se.Description,IIF(se.Name LIKE '%[a-z]%',se.Name,'Invoice AR')) HeaderEN*/
			--,l.TaxBase + l.TaxAmount ContractBalance
			,IIF(ISNULL(l.CNLwhtRate,0) = 0 ,null,CONCAT(FORMAT(l.CNLwhtRate,'#.#'),'%'))CNLwhtRate
		,IIF(ISNULL(l.CNLwhtRate,0) = 0,0, (ISNULL(l.TaxBase,0)*l.CNLwhtRate)/100 )WHTamount
		--,IIF(ISNULL(l.CNLwhtRate,0) = 0,ISNULL(l.GrandTotal,0),  isnull(l.TaxBase,0) + isnull(l.TaxAmount,0) -isnull(l.RetentionAR,0) - Round(isnull((ISNULL(l.TaxBase,0)*l.CNLwhtRate)/100 ,0),2 ) )FinalPay
		--,ReferenceCretificateNo
		--,(ISNULL(l.JOBNO,ISNULL(IIF(l.ContractNo ='',NULL,l.ContractNo),l.quotationNo))) JOBNO ---- ภูมิ 22-02-2022 เพิ่มเงื่อนไขแสดง 
		--,pb.BankCode AcctCode
		--,pb.AcctNumber
		,ISNULL(wk.name,i.createby) SellerName
		,ISNULL(wk.Telephone,wk2.Telephone) SellerTel
		,ISNULL(wk.Email,wk2.Email) SellerEmail
		,cl2.DataValues BankReceive
FROM	dbo.InvoiceARs i WITH (NOLOCK)
				LEFT JOIN CustomNoteLines Cl ON cl.DocGuid =i.guid AND cl.KeyName = 'Seller_info'
				LEFT JOIN CustomNoteLines Cl2 ON cl2.DocGuid =i.guid AND cl2.KeyName = 'Bank_receive'
				LEFT JOIN workers wk ON wk.id = JSON_VALUE(cl.DataValues,'$.id')
                LEFT JOIN workers wk2 ON wk2.Name = i.createby
				LEFT JOIN dbo.ExtOrganizations Ex WITH (NOLOCK) ON i.ExtOrgId = Ex.Id
				LEFT JOIN ContactPersons cp ON cp.ExtOrganizationId = i.ExtOrgId
				LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = i.SubDocTypeId
				LEFT JOIN (SELECT MAX(Con.Name ) ConName ,con.Tel Contel,con.Mail ConEmail
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId,con.Tel,con.Mail 
							   ) Con ON Ex.Id = Con.ExtOrganizationId
				LEFT JOIN (SELECT ia.InvoiceARId,dbo.GROUP_CONCAT(DISTINCT i.ReferenceCretificateNo)ReferenceCretificateNo
							FROM dbo.InvoiceARLines ia 
							LEFT JOIN dbo.InspectionSheets i ON i.id =ia.RefDocId
							WHERE ia.InvoiceARId = @DocId AND ia.RefDocTypeId = 127
							GROUP BY ia.InvoiceARId) c ON c.InvoiceARId = i.id
				LEFT JOIN PayeeBankAccts pb ON pb.PayeeId =ex.id
				LEFT JOIN ( 
										SELECT	il.InvoiceARId
														,MAX(ISNULL(il.ContractNO,isl.ContractNo)) ContractNo
														,MAX(IIF(il.RefDocTypeId = 73,il.RefDocCode,'')) QuotationNo
														/*,MAX(IIF(il.SystemCategoryId = 47,il.Description,'')) PaymentCondition*/
														/*,MAX(IIF(il.SystemCategoryId = 47,il.CreditPeriod+' Days','')) CreditTerms*/
														,MAX(CASE WHEN il.SystemCategoryId = 47
														            THEN CONCAT(il.CreditPeriod,' Days',il.Description)
																  WHEN il.SystemCategoryId = 46 
																    THEN 'Immediate'
																  ELSE '' END) CreditTerms
														,SUM(IIF(il.SystemCategoryId = 107,il.Amount * i.DocCurrencyRate,0)) SubTotal
														,SUM(IIF(il.SystemCategoryId = 124,il.Amount * i.DocCurrencyRate,0)) SPDiscount
														--,SUM(IIF(il.SystemCategoryId = 55 AND ISNULL(il.DocQty,0) = 0,il.Amount * i.DocCurrencyRate,0)) DepositAR		
                  										,SUM(IIF(il.SystemCategoryId = 55 AND ISNULL(il.DocQty,0) = 0,IIF(ISNULL(il2.Vatinc,0) = 1, il.Amount + il.taxamount, il.Amount )* i.DocCurrencyRate,0)) DepositAR	
														,SUM(IIF(il.SystemCategoryId IN (123,129),il.TaxBase * i.DocCurrencyRate,0)) TaxBase
														,FORMAT(MAX(ISNULL(il.TaxRate,0)),'N0')+'%' TaxRate
														,SUM(IIF(il.SystemCategoryId IN (123,129),il.TaxAmount * i.DocCurrencyRate,0)) TaxAmount
														,SUM(IIF(il.SystemCategoryId = 49,il.Amount * i.DocCurrencyRate,0)) RetentionAR
														,SUM(IIF(il.SystemCategoryId = 111,il.Amount * i.DocCurrencyRate,0)) GrandTotal	
														,ISNUll (cnl.CNLwhtRate,0)CNLwhtRate
														,ISNUll (cn2.JOBNO,Null) JOBNO ---- ภูมิ 22-02-2022 เพิ่มเงื่อนไขแสดง 
														
															
										FROM		dbo.InvoiceARLines il WITH (NOLOCK)
														INNER JOIN dbo.InvoiceARs i WITH (NOLOCK) ON i.Id = il.InvoiceARId
                                                        LEFT JOIN (SELECT InvoiceARId,COUNT(SystemCategory) Vatinc FROM InvoiceARLines WHERE SystemCategoryId = 129 AND InvoiceARId = @docid GROUP BY InvoiceARId) il2 ON  il2.InvoiceARId = il.InvoiceARId
														LEFT JOIN (SELECT isl.InspectionSheetId
														                  ,isl.id
																		  ,ISNULL(ipl.ContractNO,ip.OriginalContractNO) ContractNo
															       FROM dbo.InspectionSheetLines isl WITH (NOLOCK)
																		INNER JOIN dbo.InterimPaymentLines ipl WITH (NOLOCK) ON ipl.id = isl.InterimPaymentLineId
																		INNER JOIN dbo.InterimPayments ip WITH (NOLOCK) ON ip.Id = ipl.InterimPaymentId
																  ) isl ON il.RefDocTypeId = 127 AND isl.InspectionSheetId = il.RefDocId AND isl.id = il.RefDocLineId
														LEFT JOIN (SELECT cnl.DocGuid
																		,MAX(IIF(keyname ='ภาษีหัก ณ ที่จ่าย',CAST (CASE WHEN cnl.DataValues ='1' THEN 1 
																											  WHEN cnl.DataValues ='1.5' THEN 1.5
																											   WHEN cnl.DataValues ='2' THEN 2
																											  WHEN cnl.DataValues ='3' THEN 3
																											  WHEN cnl.DataValues ='5' THEN 5
																											  ELSE 0
																										 END AS money)
						
																										,NULL )) CNLwhtRate
																		--,MAX(IIF(keyname ='contractNo',datavalues,NULL))contractNo
		
																	FROM dbo.CustomNoteLines cnl  
																	where cnl.KeyName IN ('ภาษีหัก ณ ที่จ่าย'/*,'contractNo' */)
																	GROUP BY cnl.DocGuid
																	)cnl ON cnl.DocGuid = i.guid

																	-----------------

                                            

											LEFT JOIN ( SELECT ctn.DocGuid 
											 ,MAX(CASE WHEN (CustomNoteMetaId) = '679' THEN ctn.DataValues ELSE NULL END) JOBNO
											FROM CustomNoteLines ctn
											WHERE ctn.DocGuid IS NOT NULL  
											GROUP BY ctn.DocGuid
								
										  ) cn2 ON cnl.DocGuid = cn2.DocGuid 

										  	---- ภูมิ 22-02-2022 




										WHERE		il.InvoiceARId = @DocId	AND @typeId = 38 
														GROUP BY cn2.JOBNO,il.InvoiceARId ,ISNUll (cnl.CNLwhtRate,0)) l ON l.InvoiceARId = i.Id
					LEFT JOIN (SELECT  DISTINCT(a.InvoiceARId) InvoiceARId, b.InterimPaymentApplicationId ,c.RetentionRate FROM InvoiceARLines a
								LEFT JOIN InspectionSheets b ON b.id = a.RefDocId AND a.RefDocTypeId =127
								LEFT JOIN InterimPayments c ON c.id =b.InterimPaymentApplicationId
								WHERE   ISNULL(a.RefDocId,0) <> 0 ) inp ON inp.InvoiceARId = i.Id
WHERE		I.Id = @DocId
				AND @typeId = 38

UNION ALL

Select		i.Id
				,i.Code
				,FORMAT(i.Date,'dd/MM/yyyy') [Date]
				,i.Remarks
				,i.CreateBy
				,i.CreateTimestamp
				,38 InvTypeId
			    ,Ex.Id ExtOrgId
				,Ex.Code ExtOrgCode
				,Ex.Name ExtOrgName
				,Ex.Address ExtOrgAddress
				,Ex.Tel ExtOrgTel
				,Ex.Fax ExtOrgFax
				,Ex.TaxId ExtOrgTaxId
				,CASE WHEN ISNULL(Ex.BranchCode,'') = '00000' THEN 'สำนักงานใหญ่'
				  WHEN ISNULL(Ex.BranchName,'') <> '' THEN Ex.BranchName 
				  ELSE ex.BranchCode END ExtOrgBranch
				,Con.ConName ContractName
				,Con.Tel
				,con.Email
				,i.LocationId
				,i.LocationCode
				,i.LocationName  
				,l.ContractNo
				, l.QuotationNo, /*l.PaymentCondition,*/ 
				l.CreditTerms
				, l.SubTotal
				, l.SPDiscount
				,l.DepositAR
				, l.TaxBase
				, l.TaxRate
				, l.TaxAmount
				,NULL  RetentionRate
				, l.RetentionAR
				,l.GrandTotal
				,CASE WHEN i.SubDocTypeId IN (200,202) THEN 'ใบแจ้งหนี้/ใบกำกับภาษี'
					  WHEN i.SubDocTypeId IN (199,201) THEN 'ใบแจ้งหนี้/ใบวางบิล' ELSE 'ใบแจ้งหนี้' END HeaderTH
			    ,CASE WHEN i.SubDocTypeId IN (200,202) THEN 'INVOICE/TAX INVOICE'
					  WHEN i.SubDocTypeId IN (199,201) THEN 'INVOICE/BILLING' ELSE 'INVOICE AR' END HeaderEN
--			,(ISNULL(l.SubTotal,0)-ISNULL(l.SPDiscount,0)-ISNULL(l.DepositAR,0))*ISNULL(Convert(Decimal(18,6),cl.DataValues),0)/100 WHT
--			,ISNULL(Convert(Decimal(18,6),cl.DataValues),0) WHTRate
				,CASE WHEN cwht.CountWht = 1 THEN IIF(CONCAT(FORMAT(ISNULL(whtr.WHTrate,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(whtr.WHTrate,0),'N0'),'%'))
					ELSE NULL END  WHTPercent 
				,l.WHTAmount WHTAmt
				,ISNULL(wk.name,i.createby) SellerName
				,ISNULL(wk.Telephone,wk2.Telephone) SellerTel
				,ISNULL(wk.Email,wk2.Email) SellerEmail
				,cl2.DataValues BankReceive
From ProductInvoiceARs i
				LEFT JOIN CustomNoteLines Cl ON cl.DocGuid =i.guid AND cl.KeyName = 'Seller_info'
				LEFT JOIN CustomNoteLines Cl2 ON cl2.DocGuid =i.guid AND cl2.KeyName = 'Bank_receive'
				LEFT JOIN workers wk ON wk.id = JSON_VALUE(cl.DataValues,'$.id')
                LEFT JOIN workers wk2 ON wk2.Name = i.createby
				LEFT JOIN dbo.ProductInvoiceARLines il WITH (NOLOCK) ON il.ProductInvoiceARId = i.Id AND il.SystemCategoryId IN (46,47)
				LEFT JOIN dbo.TaxItems t WITH (NOLOCK) ON t.SetDocId = i.Id AND t.SetDocTypeId = 438
				LEFT JOIN dbo.ExtOrganizations Ex WITH (NOLOCK) ON i.ExtOrgId = Ex.Id
				LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = i.SubDocTypeId
				--INNER JOIN dbo.Workers wk ON i.CreateBy = wk.Name
				LEFT JOIN (
							SELECT COUNT(DISTINCT(b.TaxRate )) CountWht,a.SetDocId,a.SetDocCode FROM TaxItems a
							LEFT JOIN TaxItemLines b ON b.TaxItemId = a.id
							WHERE a.SetDocId = @DocId AND a.SystemCategoryId =36 and a.SetDocTypeId IN (438)
							GROUP BY a.SetDocId,a.SetDocCode 

					) Cwht ON cwht.SetDocId =i.Id
			    LEFT JOIN (
							SELECT a.id Taxid,a.SetDocId,a.SetDocCode,b.TaxRate WHTrate FROM TaxItems a
							LEFT JOIN TaxItemLines b ON b.TaxItemId = a.id
							WHERE a.SetDocId = @DocId AND a.SystemCategoryId =36 and a.SetDocTypeId IN (438)
						) whtr ON whtr.SetDocId =i.Id
				LEFT JOIN (SELECT MAX(
										Con.Name
										  ) ConName
									  ,MAX(con.tel) Tel
									  ,MAX(con.Mail) Email
									  ,Con.ExtOrganizationId
							   FROM dbo.ContactPersons Con WITH (NOLOCK)
							   GROUP BY Con.ExtOrganizationId
							   ) Con ON Ex.Id = Con.ExtOrganizationId
				LEFT JOIN ( 
										SELECT	il.ProductInvoiceARId
														--,MAX(ISNULL(il.ContractNO,isl.ContractNo)) ContractNo
														,NULL ContractNo
														,MAX(IIF(il.RefDocTypeId = 73,il.RefDocCode,'')) QuotationNo
														/*,MAX(IIF(il.SystemCategoryId = 47,il.Description,'')) PaymentCondition*/
														/*,MAX(IIF(il.SystemCategoryId = 47,il.CreditPeriod+' Days','')) CreditTerms*/
														,MAX(CASE WHEN il.SystemCategoryId = 47
														            THEN CONCAT(il.CreditPeriod,' Days',il.Description)
																  WHEN il.SystemCategoryId = 46 
																    THEN 'Immediate'
																  ELSE '' END) CreditTerms
														,SUM(IIF(il.SystemCategoryId = 107,il.Amount * i.DocCurrencyRate,0)) SubTotal
														,SUM(IIF(il.SystemCategoryId = 124,il.Amount * i.DocCurrencyRate,0)) SPDiscount
														,SUM(IIF(il.SystemCategoryId = 55 AND ISNULL(il.DocQty,0) = 0,il.Amount * i.DocCurrencyRate,0)) DepositAR		
														,SUM(IIF(il.SystemCategoryId IN (123,129),il.TaxBase * i.DocCurrencyRate,0)) TaxBase
														,FORMAT(MAX(ISNULL(il.TaxRate,0)),'N0')+'%' TaxRate
														,SUM(IIF(il.SystemCategoryId IN (123,129),il.TaxAmount * i.DocCurrencyRate,0)) TaxAmount
														,SUM(IIF(il.SystemCategoryId IN (36),il.Amount * i.DocCurrencyRate,0)) WHTAmount
														,SUM(IIF(il.SystemCategoryId = 49,il.Amount * i.DocCurrencyRate,0)) RetentionAR
														,SUM(IIF(il.SystemCategoryId = 111,il.Amount * i.DocCurrencyRate,0)) GrandTotal		
										FROM		dbo.ProductInvoiceARLines il WITH (NOLOCK)
														INNER JOIN dbo.ProductInvoiceARs i WITH (NOLOCK) ON i.Id = il.ProductInvoiceARId
														LEFT JOIN (SELECT isl.InspectionSheetId
														                  ,isl.id
																		  ,ISNULL(ipl.ContractNO,ip.OriginalContractNO) ContractNo
															       FROM dbo.InspectionSheetLines isl WITH (NOLOCK)
																		INNER JOIN dbo.InterimPaymentLines ipl WITH (NOLOCK) ON ipl.id = isl.InterimPaymentLineId
																		INNER JOIN dbo.InterimPayments ip WITH (NOLOCK) ON ip.Id = ipl.InterimPaymentId
																  ) isl ON il.RefDocTypeId = 127 AND isl.InspectionSheetId = il.RefDocId AND isl.id = il.RefDocLineId
										WHERE		il.ProductInvoiceARId = @DocId AND @typeId = 438
										GROUP BY	il.ProductInvoiceARId	) l ON l.ProductInvoiceARId = i.Id
WHERE		I.Id = @DocId
				AND @typeId = 438

/* 2-Line */


SELECT x. Line_No
	  ,x.DocId
	  ,x.ItemCode
	  ,x.Description
	  ,x.DocQty
	  ,x.DocUnitName
	  ,x.UnitPrice
	  ,x.Discount
	  ,x.Amount
	  ,x.RefDocCode

FROM (

SELECT	PL.Line_No,PL.DocId,PL.ItemCode,PL.Description,PL.DocQty,PL.DocUnitName,PL.UnitPrice,PL.Discount,PL.Amount,pl.RefDocCode

FROM	(	

				
				SELECT ROW_NUMBER() OVER (ORDER BY a.Description) Line_No,a.DocId
                        ,a.[Description]
                        ,CASE WHEN a.DocUnitName IN (SELECT * FROM @LSName) THEN 1 ELSE SUM(a.DocQty) END DocQty
                        ,a.DocUnitName,AVG(a.UnitPrice)*a.DocCurrencyRate UnitPrice,SUM(a.Discount) Discount,SUM(a.Amount) Amount
                        ,STRING_AGG(a.RefDocCode,',') RefDocCode
                        ,STRING_AGG(a.ItemCode,',') ItemCode
                FROM
                (SELECT	il.LineNumber,il.InvoiceARId DocId
                                --,CONCAT(il.ItemMetaName + ' ',REPLACE(il.Description,il.ItemMetaName,''))Description

                                ,COALESCE(IIF(cldes.DataValues = '',NULL,cldes.DataValues),il.Description) Description
                                ,il.DocQty,il.DocUnitName,(il.UnitPrice*i.DocCurrencyRate)UnitPrice
                                ,ISNULL(il.DiscountAmount,0)Discount
                                ,(il.Amount) Amount
                                ,il.RefDocCode
                                ,il.ItemMetaCode ItemCode,i.DocCurrencyRate
                FROM		dbo.InvoiceARLines il WITH (NOLOCK)
                                LEFT JOIN dbo.InvoiceARs i WITH (NOLOCK) ON i.Id = il.InvoiceARId
                                LEFT JOIN dbo.CustomNoteLines cldes WITH (NOLOCK) ON cldes.DocGuid = i.guid AND cldes.DocLineGuid = il.guid AND cldes.KeyName = 'Description'
                WHERE		il.InvoiceARId = @DocId 
                                AND ISNULL(il.DocQty,0) <> 0 
                                AND ISNULL(il.SystemCategoryId,0) <> -2
                                AND @typeId = 38 ) a
                GROUP BY a.[Description],a.DocUnitName,a.DocCurrencyRate,a.DocId

				UNION	 ALL
																
				SELECT NULL Line_No,il.InvoiceARId DocId,il.Description,NULL DocQty,NULL DocUnitName
								,NULL UnitPrice,NULL Discount,NULL Amount
								,NULL refdoccode
								,NULL ItemCode
				FROM		dbo.InvoiceARLines il WITH (NOLOCK)
				WHERE		il.InvoiceARId = @DocId AND il.SystemCategoryId IN (-2)
								AND @typeId = 38

				UNION ALL
                SELECT ROW_NUMBER() OVER (ORDER BY a.Description) Line_No,a.DocId
                        ,a.[Description]
                        ,CASE WHEN a.DocUnitName IN (SELECT * FROM @LSName) THEN 1 ELSE SUM(a.DocQty) END DocQty
                        ,a.DocUnitName,AVG(a.UnitPrice)*a.DocCurrencyRate UnitPrice,SUM(a.Discount) Discount,SUM(a.Amount) Amount
                        ,STRING_AGG(a.RefDocCode,',') RefDocCode
                        ,STRING_AGG(a.ItemCode,',') ItemCode
                FROM
                (SELECT	il.LineNumber,il.ProductInvoiceARId DocId
                                --,CONCAT(il.ItemMetaName + ' ',REPLACE(il.Description,il.ItemMetaName,''))Description

                                ,COALESCE(IIF(cldes.DataValues = '',NULL,cldes.DataValues),il.Description) Description
                                ,il.DocQty,il.DocUnitName,(il.UnitPrice*i.DocCurrencyRate)UnitPrice
								/*,NULLIF(il.Discount,'0')Discount*/
								,ISNULL(il.DiscountAmount,0)Discount
								,(il.Amount*i.DocCurrencyRate)Amount
								,il.RefDocCode
								,il.ItemMetaCode ItemCode,i.DocCurrencyRate
				FROM		dbo.ProductInvoiceARLines il WITH (NOLOCK)
								LEFT JOIN dbo.ProductInvoiceARs i WITH (NOLOCK) ON i.Id = il.ProductInvoiceARId
                                LEFT JOIN dbo.CustomNoteLines cldes WITH (NOLOCK) ON cldes.DocGuid = i.guid AND cldes.DocLineGuid = il.guid AND cldes.KeyName = 'Description'
				WHERE		il.ProductInvoiceARId = @DocId 
								AND ISNULL(il.DocQty,0) <> 0
								AND ISNULL(il.SystemCategoryId,0) <> -2
								AND @typeId = 438 ) a
                GROUP BY a.[Description],a.DocUnitName,a.DocCurrencyRate,a.DocId

  				UNION ALL

				SELECT	NULL Line_No
  								,il.ProductInvoiceARId DocId

                                  ,il.Description
								,NULL DocQty
  								,NULL DocUnitName
  								,NULL UnitPrice
								/*,NULLIF(il.Discount,'0')Discount*/
								,NULL Discount
								,NULL Amount
								,NULL RefDocCode
								,NULL ItemMetaCode
				FROM		dbo.ProductInvoiceARLines il WITH (NOLOCK)
								LEFT JOIN dbo.ProductInvoiceARs i WITH (NOLOCK) ON i.Id = il.ProductInvoiceARId
				WHERE		il.ProductInvoiceARId = @DocId 
								AND ISNULL(il.SystemCategoryId,0) = -2
								AND @typeId = 438
	) pl

) x
				ORDER BY x.Line_No
/*3-Other*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT '3-Other' TableMappingName;

/*4-Payment*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT '4-Payment' TableMappingName;

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @DocOrgid;

-----------------------------------------------------------------------------------------------------------------------------------------------