
/*==> Ref:d:\pjm2\pjmdemo\content\printing\documentcommands\ar_tre_taxinvoicereceipt.sql ==>*/
/* TaxinvoiceAndReceipt, Taxinvoice */
-- declare @p0 numeric(18) = 1
-- declare @p1 numeric(18) = 52

declare @docid numeric(18) = @p0
declare @TaxItemId numeric(18) = (CASE WHEN @p1 IN (44,38) THEN (SELECT id FROM TaxItems WHERE SetDocId =@p0 AND SetDocTypeId = @p1 AND SystemCategoryId <> 36 AND SystemCategoryId <> 136)
									   WHEN @p1 = 438 THEN (SELECT id FROM TaxItems WHERE SetDocId =@p0 AND SetDocTypeId = 438 AND SystemCategoryId =151)
									   WHEN @p1 = 52 THEN (SELECT id FROM TaxItems WHERE SetDocId =@p0 AND SetDocTypeId = 151 AND SystemCategoryId =151)
									   ELSE @p0 END
									)

DECLARE @type numeric(18) = @p1
DECLARE @Deposit AS decimal(18,2)
DECLARE @DocOrgId int = (case when  @type = 151 then (select OrgId from dbo.TaxItems where Id = @DocId)
                              when  @type = 44 then (select LocationId from dbo.OtherReceives where id = @DocId)
                              when  @type = 38 then (select LocationId from dbo.Invoicears where id = @DocId)
                              when  @type = 51 then (select LocationId from dbo.Receipts where Id = @DocId)
                              when  @type = 438 then (select LocationId from dbo.ProductInvoiceARs where Id = @DocId)
                              when  @type = 52 then (select OrgId from dbo.ReceiveVouchers where Id = @DocId)
                              end )

--------------------------------------------------------------------------------------------------------------------
/*TaxInvoice&Receipts*/

SELECT @Deposit = (SELECT amount FROM dbo.TaxItemLines WHERE TaxItemId = @TaxItemId AND SystemCategory = 'DepositReceive')
-- SELECT * from taxitemlines where taxitemid = @docid

-- SELECT TaxItemId,SetDocId,SetDocGuid,[WHT Rate],[WHT Amount]
-- FROM (
-- 	SELECT til.TaxItemId,til.SetDocId,til.SetDocGuid,clwht.KeyName,clwht.DataValues
-- 	from taxitemlines til
-- 	INNER JOIN CustomNoteLines clwht ON til.SetDocGuid = clwht.DocGuid AND clwht.KeyName IN ('WHT Rate','WHT Amount')
-- 	where til.TaxitemId = @Docid 
-- ) AS Stable
-- PIVOT (
-- MAX(DataValues) FOR KeyName IN ([WHT Rate],[WHT Amount])
-- ) as Pivoted;


SELECT TT.Code ,TT.Date  ,TT.SetDocCode [RVcode] ,TT.SetDocDate ,TT.Remarks
			,Ext.id                          [ExtId]
			,Ext.Code						 [ExtCode]
			,Ext.Name						 [ExtName] 
			,IIF(@type IN (151,44),TT.ExtOrgAddress,Ext.Address)					 [Address]
			,ISNULL(Cont.tel, Ext.Tel)       [Tel]
			,Ext.Fax                         [Fax]
			,Cont.name                       [Contract]
			,tr.ContractNO							 [ContractNO]
			,IIF(@type IN (151,44),TT.ExtOrgTaxID,Ext.TaxId)                           [ExtTaxId]  
			,IIF(@type IN (151,44),TT.ExtOrgBranchCode,Ext.BranchName) 			     [BranchName]
			,Rc.Code						 [ReceiptCode]             
			,Rc.Date					     [ReceiptDate]
			,TT.OrgCode				 [OrgCode]
			,TT.OrgName				 [OrgName]
			,TT.TaxAmount + TT.TaxBase		 [ReceiptSumAmount]
			,CAST(ISNULL(@Deposit,0) as money	)					 [SumDeposit]
			,CAST(ISNULL(Ret.Amount	,0) as money	)					 [SumRetention]
			,CAST(ISNULL(Dep.Amount		,0) as money	)						 [SumDeposit]
			,CAST(IIF(@type = 44 ,TT.TaxBase ,Sub.Amount ) as money)						 [SubTotal]
			,(FORMAT(ISNULL(tr.RetentionRate,0),'N0')+'%') RetRate /* เพิ่ม Retention Rate 26/05/2025 By Good */
			,CAST(IIF(@type = 44 ,TT.TaxAmount + TT.TaxBase - ISNULL(orwht.WhtAmount,0)	 ,Gra.Amount	 ) as money) - IIF(@type = 44,ISNULL(Ret.Amount	,0),0) 
				-ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(Vat.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0)
                /* CASE WHEN @type = 44
						THEN
						(CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
							THEN ISNULL(orwht.WhtAmount,0)
						ELSE ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(TT.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0) END
						)
				ELSE clwhtset.WHTAmount END */
					[GrandTotal]
			,CAST(IIF(@type = 44 ,TT.TaxBase,Vat.TaxBase)as money ) [TaxBase]
			,CAST(IIF(@type = 44 ,TT.TaxAmount,Vat.TaxAmount)as money) [Vat] 
			,IIF(ISNULL(IIF(@type = 44 ,TT.taxrate,Vat.TaxRate) ,0) = 0,(FORMAT(ISNULL(IIF(@type = 44 ,TT.taxrate,Vat.TaxRate),0),'N0')+'%'),(FORMAT(ISNULL(IIF(@type = 44 ,TT.taxrate,Vat.TaxRate) ,0),'N0')+'%')) [VatRate]
			,IIF(@type = 44, tror.RefDocCode,tr.IvCode)			 [InvoiceCode]
			,Dco.ContractNO					 [ProJCon]
			,RV.PayAmount                    [ReceivePay]
			,RV.DocDate                      [ReceivePayDate]
			,@Type							 [DocTypeId]
			,ISNULL(Spe.Amount,0)                      [SpecialDiscount]
			,Pen.amount                      [Penalty]
			-- ,py.BankCode,py.AcctName,py.AcctNumber /* ไปใช้ query ข้างล่าง */
			,IIF(@type = 44 ,TT.setdoccode,tr.IvCode) RefDocCode
			,CASE WHEN @type = 44
            		THEN CONCAT(
            LEFT(JSON_VALUE(IIF(clor.DataValues = '',NULL,clor.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clor.DataValues = '',NULL,clor.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clor.DataValues = '',NULL,clor.DataValues),'$.text')) + 1) - 1)
            ,'',JSON_VALUE(IIF(clor.DataValues = '',NULL,clor.DataValues),'$.obj.BookName')
            )
            ELSE CONCAT(
            LEFT(JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text')) + 1) - 1)
            ,'',JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.obj.BookName')
            ) END  Bank_receive /* ใช้ custom note เเบบ ConboboxSingle สำหรับ Query นี้ */
            
			,CASE WHEN @type = 44
						THEN 
						(CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
							THEN IIF(ISNULL(orwht.WHTRate,0) = 0,'0.00%',CONCAT(FORMAT(orwht.WHTRate,'#.#'),'%'))
						ELSE IIF(ISNULL(IIF(clwht.DataValues= '',0,clwht.DataValues),0) = 0,'0.00%',CONCAT(FORMAT(IIF(clwht.DataValues= '',0,clwht.DataValues),'#.#'),'%')) END
						)
				ELSE CONCAT(FORMAT(clwhtset.WHT,'#.#'),'%')
				/* IIF(ISNULL(IIF(clwhtset.DataValues= '',0,clwhtset.DataValues),0) = 0,'0.00%',CONCAT(FORMAT(IIF(clwhtset.DataValues= '',0,clwhtset.DataValues),'#.#'),'%')) */
			END WHTRate
			,CASE WHEN @type = 44
						THEN
						(CASE WHEN EXISTS (select 1 FROM OtherReceiveLines where OtherReceiveId = @DocId AND SystemCategoryId = 36)
							THEN ISNULL(orwht.WhtAmount,0)
						ELSE ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(TT.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0) END
						)
				ELSE clwhtset.WHTAmount
			END WHTamount
FROM  dbo.TaxItems TT
LEFT JOIN (
			SELECT tr.TaxItemId,STRING_AGG(tr.IVID,',') IVID, STRING_AGG(tr.IVGuid,',') IVGuid, STRING_AGG(tr.IvCode,',') IvCode, STRING_AGG(tr.ContractNO,',') ContractNO, STRING_AGG(tr.InterimCode,',') InterimCode,tr.RetentionRate
            FROM (SELECT til.TaxItemId,til.SetDocId IVID,til.SetDocGuid IVGuid,IIF(til.SetDocCode = '',iar.Code,til.setDocCode) IvCode,iarl.ContractNO ContractNO ,ipp.code InterimCode
                   ,MAX(ipp.RetentionRate) RetentionRate
					FROM dbo.TaxItemLines til 
					LEFT JOIN InvoiceARLines iarl ON iarl.Id = til.SetDocLineId
					LEFT JOIN InvoiceARs iar ON iar.Id = til.SetDocId
					LEFT JOIN InterimPayments ipp ON ipp.Code =til.ProjectCode
					WHERE til.SetDocTypeid IN (38,44) AND taxitemid= @TaxItemId 
					GROUP BY TaxItemId,til.SetDocId,til.SetDocGuid,til.SetDocCode,iar.Code,til.setDocCode,iarl.ContractNO,ipp.code) tr GROUP BY tr.TaxItemId,tr.RetentionRate
		  ) tr ON tr.TaxItemId =tt.id
Left Join dbo.ExtOrganizations Ext on Ext.Code = TT.ExtOrgCode
Left join dbo.ContactPersons Cont on Cont.ExtOrganizationId = Ext.id
Left Join dbo.Receipts Rc on TT.Code = Rc.TaxItemCode
LEFT JOIN dbo.ReceiveVoucherLines RV ON RV.SystemCategoryId = 51 and TT.Code = RV.TaxItemCode
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 49  and TTL.TaxItemId = @TaxItemId)Ret ON TT.Id = Ret.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 55  and TTL.TaxItemId = @TaxItemId AND TTL.GeneralAccountCode = 'DepositReceive')Dep ON TT.Id = Dep.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 107 and TTL.TaxItemId = @TaxItemId)Sub ON TT.Id = Sub.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 111 and TTL.TaxItemId = @TaxItemId)Gra ON TT.Id = Gra.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId IN (129,123) and TTL.TaxItemId = @TaxItemId)Vat ON TT.Id = Vat.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 148 and TTL.TaxItemId = @TaxItemId)Pen ON TT.Id = Pen.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where LineNumber = 1         and TTL.TaxItemId = @TaxItemId)Dco ON TT.Id = Dco.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 124 and TTL.TaxItemId = @TaxItemId)Spe ON TT.Id = Spe.TaxItemId   
-- LEFT JOIN dbo.PayeeBankAccts py ON py.PayeeId = ext.id 
LEFT JOIN OtherReceives ot ON ot.id = tt.SetDocId AND tt.SetDocTypeId = 44
LEFT JOIN (
			SELECT tror.OtherReceiveId,STRING_AGG(tror.RefDocId,',') RefDocId, STRING_AGG(tror.RefDocCode,',') RefDocCode
FROM (
                select ol.OtherReceiveId, ol.RefDocId,ol.RefDocCode
                FROM OtherReceiveLines ol WHERE SystemCategoryId = @type AND ol.OtherReceiveId = @docid 
                GROUP BY ol.OtherReceiveId, ol.RefDocId,ol.RefDocCode
                    ) tror GROUP BY tror.OtherReceiveId
		  ) tror ON tror.OtherReceiveId =tt.SetDocId 
LEFT JOIN (
		SELECT ti.SetDocId,ti.SetDocType,til.TaxItemId,SUM(til.TaxAmount)/SUM(til.TaxBase)*100 [WHTRate],SUM(til.TaxAmount) [WhtAmount]
		FROM taxitems ti 
		LEFT JOIN taxitemlines til ON ti.Id = til.TaxItemId
		WHERE ti.SystemCategoryId = 36 AND ti.SetDocTypeId = @type
		GROUP BY ti.SetDocId,til.TaxRate,til.TaxItemId,ti.SetDocType
) orwht ON orwht.SetDocId = ot.Id
LEFT JOIN CustomNoteLines clt ON clt.DocGuid =tt.guid AND clt.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clor ON clor.DocGuid =ot.guid AND clor.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clwht ON clwht.DocGuid = ot.guid AND clwht.KeyName = 'WHT Rate'
LEFT JOIN CustomNoteLines clawht ON clawht.DocGuid = ot.guid AND clawht.KeyName = 'WHT Amount'
LEFT JOIN (
	SELECT TaxItemId,SUM(TaxBase) TotalTaxBase, SUM(whtAmount) WHTAmount,SUM(whtAmount)*100/SUM(TaxBase) WHT
FROM(
	SELECT til.TaxItemId,til.TaxBase
	,CASE WHEN IIF(clwht.DataValues= '',0,clwht.DataValues) != 0
		THEN til.TaxBase * IIF(clwht.DataValues= '',0,clwht.DataValues)/100
		ELSE CAST(IIF(clamtwht.DataValues= '',0,clamtwht.DataValues) AS DECIMAL(18,2))
	END whtAmount
from taxitemlines til
LEFT JOIN CustomNoteLines clwht ON til.SetDocGuid = clwht.DocGuid AND clwht.KeyName = 'WHT Rate'
LEFT JOIN CustomNoteLines clamtwht ON til.SetDocGuid = clamtwht.DocGuid AND clamtwht.KeyName = 'WHT Amount'
where til.TaxitemId = @TaxItemId  AND til.SetDocTypeId IN (438,38)
) wht GROUP BY TaxItemId
) clwhtset ON clwhtset.TaxItemId = @TaxItemId

WHERE  TT.Id = @TaxItemId  AND @Type NOT IN (438,38,52)


UNION ALL


SELECT TT.Code ,TT.Date  ,TT.SetDocCode [RVcode] ,TT.SetDocDate ,TT.Remarks
			,Ext.id                          [ExtId]
			,Ext.Code						 [ExtCode]
			,Ext.Name						 [ExtName] 
			,/* IIF(@type = 52,TT.ExtOrgAddress,Ext.Address) */TT.ExtOrgAddress					 [Address]
			,ISNULL(Cont.tel, Ext.Tel)       [Tel]
			,Ext.Fax                         [Fax]
			,Cont.name                       [Contract]
			,tr.ContractNO							 [ContractNO]
			,IIF(@type = 52,TT.ExtOrgTaxID,Ext.TaxId)                           [ExtTaxId]  
			,IIF(@type = 52,TT.ExtOrgBranchCode,Ext.BranchName) 			     [BranchName]
			,Rc.Code						 [ReceiptCode]             
			,Rc.Date					     [ReceiptDate]
			,TT.OrgCode				 [OrgCode]
			,TT.OrgName				 [OrgName]
			,TT.TaxAmount + TT.TaxBase		 [ReceiptSumAmount]
			,CAST(ISNULL(@Deposit,0) as money	)					 [SumDeposit]
			,CAST(ISNULL(Ret.Amount	,0) as money	)					 [SumRetention]
			,CAST(ISNULL(Dep.Amount		,0) as money	)						 [SumDeposit]
			,CAST(Sub.Amount  as money)						 [SubTotal]
			,(FORMAT(ISNULL(tr.RetentionRate,0),'N0')+'%') RetRate  /* เพิ่ม Retention Rate 26/05/2025 By Good */
			,CAST(TT.TaxAmount + TT.TaxBase	 	  as money)- CAST(ISNULL(Ret.Amount	,0) as money) 	- CAST(ISNULL(Ret.Amount,0) as money)-ISNULL(WHT.WHTamount,0) [GrandTotal]
			,IIF(ISNULL(Vat.TaxBase,0)=0,TT.TaxBase,Vat.TaxBase) [TaxBase]
			,IIF(ISNULL(Vat.TaxAmount,0)=0,TT.TaxAmount,Vat.TaxAmount) [Vat] 
			,IIF(ISNULL(Vat.TaxRate ,0) = 0,(FORMAT(ISNULL(IIF(@type = 52 ,TT.taxrate,Vat.TaxRate),0),'N0')+'%'),(FORMAT(ISNULL(IIF(@type = 52 ,TT.taxrate,Vat.TaxRate) ,0),'N0')+'%')) [VatRate]
			,Dco.SetDocCode					 [InvoiceCode]
			,Dco.ContractNO					 [ProJCon]
			,RV.PayAmount                    [ReceivePay]
			,RV.DocDate                      [ReceivePayDate]
			,@Type							 [DocTypeId]
			,ISNULL(Spe.Amount,0)                      [SpecialDiscount]
			,Pen.amount                      [Penalty]
			-- ,py.BankCode,py.AcctName,py.AcctNumber  /* ไปใช้ query ข้างล่าง */
			,IIF(@type = 438 ,rp.RefDocCode,tr.IvCode) RefDocCode
			,CONCAT(
            LEFT(JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text')) + 1) - 1)
            ,'',JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.obj.BookName')
            ) Bank_receive /* ใช้ custom note เเบบ ConboboxSingle สำหรับ Query นี้ */
			,CONCAT(FORMAT(ISNULL(WHT.WHTRate,0),'#.#'),'%') WHTRate
			,ISNULL(WHT.WHTamount,0) WHTamount
FROM  dbo.TaxItems TT
LEFT JOIN (
			SELECT til.TaxItemId,dbo.GROUP_CONCAT_D(til.SetDocId,' ,')IVID,dbo.GROUP_CONCAT_D(til.SetDocGuid,' ,')IVGuid,dbo.GROUP_CONCAT_D(IIF(til.SetDocCode = '',iar.Code,til.setDocCode),' ,') IvCode,dbo.GROUP_CONCAT_D( iarl.ContractNO,' ,') ContractNO ,dbo.GROUP_CONCAT_D(ipp.code,' ,') InterimCode
                   ,MAX(ipp.RetentionRate) RetentionRate
					FROM dbo.TaxItemLines til 
					LEFT JOIN InvoiceARLines iarl ON iarl.Id = til.SetDocLineId
					LEFT JOIN InvoiceARs iar ON iar.Id = til.SetDocId
					LEFT JOIN InterimPayments ipp ON ipp.Code =til.ProjectCode
					WHERE til.SetDocTypeid IN (38,44) AND taxitemid= @TaxItemId 
					GROUP BY TaxItemId
		  ) tr ON tr.TaxItemId =tt.id
Left Join dbo.ExtOrganizations Ext on Ext.Code = TT.ExtOrgCode
Left join dbo.ContactPersons Cont on Cont.ExtOrganizationId = Ext.id
Left Join dbo.Receipts Rc on TT.Code = Rc.TaxItemCode
LEFT JOIN dbo.ReceiveVoucherLines RV ON RV.SystemCategoryId = 51 and TT.Code = RV.TaxItemCode
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 49  and TTL.TaxItemId = @TaxItemId)Ret ON TT.Id = Ret.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 55  and TTL.TaxItemId = @TaxItemId)Dep ON TT.Id = Dep.TaxItemId  
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 107 and TTL.TaxItemId = @TaxItemId)Sub ON TT.Id = Sub.TaxItemId  
LEFT JOIN (Select * From dbo.ProductInvoiceARLines TTL Where SystemCategoryId IN (111) and TTL.ProductInvoiceARId = @docid)Gra ON TT.SetDocId =Gra.ProductInvoiceARId   AND TT.SetDocTypeId =438
LEFT JOIN (Select * From dbo.ProductInvoiceARLines TTL Where SystemCategoryId IN (129,123) and TTL.ProductInvoiceARId = @docid)Vat ON TT.SetDocId = Vat.ProductInvoiceARId   AND TT.SetDocTypeId =438
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 148 and TTL.TaxItemId = @TaxItemId)Pen ON TT.Id = Pen.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where LineNumber = 1         and TTL.TaxItemId = @TaxItemId)Dco ON TT.Id = Dco.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 124 and TTL.TaxItemId = @TaxItemId)Spe ON TT.Id = Spe.TaxItemId   
-- LEFT JOIN dbo.PayeeBankAccts py ON py.PayeeId = ext.id 
LEFT JOIN ProductInvoiceARs ot ON ot.id = tt.SetDocId AND tt.SetDocTypeId = 438
LEFT JOIN (
					  SELECT ProductInvoiceARId
							,dbo.GROUP_CONCAT_D(DISTINCT(RefDocCode),' ,') RefDocCode
					  FROM ProductInvoiceARLines
					  WHERE ProductInvoiceARId = @docid AND ISNULL(RefDocCode,'') <> ''
					  GROUP BY ProductInvoiceARId

		  ) rp ON rp.ProductInvoiceARId = ot.id
LEFT JOIN (
			SELECT ti.SetDocId,ti.SetDocType,til.TaxItemId,SUM(til.TaxAmount)/SUM(til.TaxBase)*100 [WHTRate],SUM(til.TaxAmount) [WhtAmount]
		FROM taxitems ti 
		LEFT JOIN taxitemlines til ON ti.Id = til.TaxItemId
		WHERE ti.SystemCategoryId = 36 AND ti.SetDocTypeId = @type
		GROUP BY ti.SetDocId,til.TaxRate,til.TaxItemId,ti.SetDocType
) WHT ON WHT.SetDocId = TT.SetDocId
LEFT JOIN CustomNoteLines clt ON clt.DocGuid =tt.guid AND clt.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clor ON clor.DocGuid =ot.guid AND clor.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clwht ON clwht.DocGuid = ot.guid AND clwht.KeyName = 'WHT Rate'
LEFT JOIN CustomNoteLines clawht ON clawht.DocGuid = ot.guid AND clawht.KeyName = 'WHT Amount'
WHERE  TT.Id = @TaxItemId  AND @Type IN (438,52)

UNION ALL


SELECT TT.Code ,TT.Date  ,TT.SetDocCode [RVcode] ,TT.SetDocDate ,TT.Remarks
			,Ext.id                          [ExtId]
			,Ext.Code						 [ExtCode]
			,Ext.Name						 [ExtName] 
			,Ext.Address					 [Address]
			,ISNULL(Cont.tel, Ext.Tel)       [Tel]
			,Ext.Fax                         [Fax]
			,Cont.name                       [Contract]
			,tr.ContractNO							 [ContractNO]
			,TaxId                           [ExtTaxId]  
			,Ext.BranchName 			     [BranchName]
			,Rc.Code						 [ReceiptCode]             
			,Rc.Date					     [ReceiptDate]
			,TT.OrgCode				 [OrgCode]
			,TT.OrgName				 [OrgName]
			,TT.TaxAmount + TT.TaxBase		 [ReceiptSumAmount]
			,CAST(ISNULL(@Deposit,0) as money	)					 [SumDeposit]
			,CAST(ISNULL(Ret.Amount	,0) as money	)					 [SumRetention]
			,CAST(ISNULL(Dep.Amount		,0) as money	)						 [SumDeposit]
			,CAST(Sub.Amount  as money)						 [SubTotal]
			,(FORMAT(ISNULL(tr.RetentionRate,0),'N0')+'%') RetRate  /* เพิ่ม Retention Rate 26/05/2025 By Good */
			,CAST(TT.TaxAmount + TT.TaxBase	 	  as money)-CAST(ISNULL(Ret.Amount	,0) as money)-ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(Vat.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0)[GrandTotal]
			,CAST(Vat.TaxBase as money ) [TaxBase]
			,CAST(Vat.TaxAmount as money) [Vat] 
			,IIF(ISNULL(Vat.TaxRate ,0) = 0,(FORMAT(ISNULL(IIF(@type = 44 ,TT.taxrate,Vat.TaxRate),0),'N0')+'%'),(FORMAT(ISNULL(IIF(@type = 44 ,TT.taxrate,Vat.TaxRate) ,0),'N0')+'%')) [VatRate]
			,Dco.SetDocCode					 [InvoiceCode]
			,Dco.ContractNO					 [ProJCon]
			,RV.PayAmount                    [ReceivePay]
			,RV.DocDate                      [ReceivePayDate]
			,@Type							 [DocTypeId]
			,ISNULL(Spe.Amount,0)                      [SpecialDiscount]
			,Pen.amount                      [Penalty]
			-- ,py.BankCode,py.AcctName,py.AcctNumber  /* ไปใช้ query ข้างล่าง */
			,IIF(@type = 38 ,rp.RefDocCode,tr.IvCode) RefDocCode
			,CONCAT(
            LEFT(JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text'), CHARINDEX(':', JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.text')) + 1) - 1)
            ,'',JSON_VALUE(IIF(clt.DataValues = '',NULL,clt.DataValues),'$.obj.BookName')
            ) Bank_receive /* ใช้ custom note เเบบ ConboboxSingle สำหรับ Query นี้ */
			,CASE WHEN ISNULL(IIF(clwht.DataValues= '',0,clwht.DataValues),0) = 0 AND ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) !=0 /* ใส่ wht amount เเต่ไม่ได้ใส่ % */
					THEN CONCAT(FORMAT(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0)*100/Vat.TaxBase,'#.#'),'%')
				WHEN ISNULL(IIF(clwht.DataValues= '',0,clwht.DataValues),0) != 0  /* ใส่ % เเต่ไม่ได้ใส amount */
					THEN CONCAT(FORMAT(IIF(clwht.DataValues= '',0,clwht.DataValues),'#.#'),'%')
				ELSE '0.00%'
			END WHTRate
			,ISNULL(IIF(ISNULL(IIF(clawht.DataValues= '',0,clawht.DataValues),0) = 0,CAST(Vat.TaxBase as money )*IIF(clwht.DataValues= '',0,clwht.DataValues)/100,IIF(clawht.DataValues= '',0,clawht.DataValues)),0)WHTamount
FROM  dbo.TaxItems TT
LEFT JOIN (
			SELECT til.TaxItemId,dbo.GROUP_CONCAT_D(til.SetDocId,' ,')IVID,dbo.GROUP_CONCAT_D(til.SetDocGuid,' ,')IVGuid,dbo.GROUP_CONCAT_D(IIF(til.SetDocCode = '',iar.Code,til.setDocCode),' ,') IvCode,dbo.GROUP_CONCAT_D( iarl.ContractNO,' ,') ContractNO ,dbo.GROUP_CONCAT_D(ipp.code,' ,') InterimCode
                   ,MAX(ipp.RetentionRate) RetentionRate
					FROM dbo.TaxItemLines til 
					LEFT JOIN InvoiceARLines iarl ON iarl.Id = til.SetDocLineId
					LEFT JOIN InvoiceARs iar ON iar.Id = til.SetDocId
					LEFT JOIN InterimPayments ipp ON ipp.Code =til.ProjectCode
					WHERE til.SetDocTypeid IN (38,44) AND taxitemid= @TaxItemId 
					GROUP BY TaxItemId
		  ) tr ON tr.TaxItemId =tt.id
Left Join dbo.ExtOrganizations Ext on Ext.Code = TT.ExtOrgCode
Left join dbo.ContactPersons Cont on Cont.ExtOrganizationId = Ext.id
Left Join dbo.Receipts Rc on TT.Code = Rc.TaxItemCode
LEFT JOIN dbo.ReceiveVoucherLines RV ON RV.SystemCategoryId = 51 and TT.Code = RV.TaxItemCode
LEFT JOIN (Select * From dbo.InvoiceARLines TTL Where SystemCategoryId = 49  and TTL.InvoiceARId = @docid)Ret ON TT.SetDocId = Ret.InvoiceARId   AND TT.SetDocTypeId = 38
LEFT JOIN (Select * From dbo.InvoiceARLines TTL Where SystemCategoryId = 55  and TTL.InvoiceARId = @docid)Dep ON TT.SetDocId = Dep.InvoiceARId  AND TT.SetDocTypeId = 38
LEFT JOIN (Select * From dbo.InvoiceARLines TTL Where SystemCategoryId = 107 and TTL.InvoiceARId = @docid)Sub ON TT.SetDocId = Sub.InvoiceARId  AND TT.SetDocTypeId = 38
LEFT JOIN (Select * From dbo.InvoiceARLines TTL Where SystemCategoryId IN (111) and TTL.InvoiceARId = @docid)Gra ON TT.SetDocId =Gra.InvoiceARId   AND TT.SetDocTypeId = 38
LEFT JOIN (Select * From dbo.InvoiceARLines TTL Where SystemCategoryId IN (129,123) and TTL.InvoiceARId = @docid)Vat ON TT.SetDocId = Vat.InvoiceARId   AND TT.SetDocTypeId = 38
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 148 and TTL.TaxItemId = @TaxItemId)Pen ON TT.Id = Pen.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where LineNumber = 1         and TTL.TaxItemId = @TaxItemId)Dco ON TT.Id = Dco.TaxItemId
LEFT JOIN (Select * From dbo.TaxItemLines TTL Where SystemCategoryId = 124 and TTL.TaxItemId = @TaxItemId)Spe ON TT.Id = Spe.TaxItemId   
-- LEFT JOIN dbo.PayeeBankAccts py ON py.PayeeId = ext.id 
LEFT JOIN InvoiceARs ot ON ot.id = tt.SetDocId AND tt.SetDocTypeId = 38
LEFT JOIN (
					  SELECT InvoiceARId
							,dbo.GROUP_CONCAT_D(DISTINCT(RefDocCode),' ,') RefDocCode
					  FROM InvoiceARLines
					  WHERE InvoiceARId = @docid AND ISNULL(RefDocCode,'') <> ''
					  GROUP BY InvoiceARId

		  ) rp ON rp.InvoiceARId = ot.id
LEFT JOIN CustomNoteLines clt ON clt.DocGuid =tt.guid AND clt.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clor ON clor.DocGuid =ot.guid AND clor.KeyName = 'Bank_receive'
LEFT JOIN CustomNoteLines clwht ON clwht.DocGuid = ot.guid AND clwht.KeyName = 'WHT Rate'
LEFT JOIN CustomNoteLines clawht ON clawht.DocGuid = ot.guid AND clawht.KeyName = 'WHT Amount'
WHERE  TT.Id = @TaxItemId  AND @Type = 38
----------------------------------------------------------------------------------------------------------------------
/*TaxInvoice&ReceiptLines*/


-------------------------------------------------------Set TaxInvoice&Receipt to 1 Line----------------------------------------------------------------:)
--
--DECLARE @description AS NVARCHAR(MAX)
--
--SELECT @description = (SELECT   TaxItemLines.Description 
--					   FROM     dbo.TaxItemLines 
--	                   WHERE    TaxItemId = @TaxInvoiceAndReceiptId  AND id = (SELECT MIN(id) 
--				                                                               FROM  dbo.TaxItemLines 
--								                                               WHERE TaxItemId = @TaxInvoiceAndReceiptId AND ISNULL(SetDocId,0) <>0 ))
--
--
--------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT 
   *
FROM
(

SELECT     ROW_NUMBER() OVER(ORDER BY linenumber) Line_No
		   ,LineNumber 
		   ,IIF(@type = 44,tx.setdoccode, ttl.SetDoccode) [IVcode] 
		   ,ttl.SetDocType     [RefDocType]
           ,ttl.description        [Description]
           ,DocQty                          [DocQty]
           ,DocUnitName                      [DocUnitName]
		   ,CAST(DiscountAmount as money)                            [Discount]
		   ,UnitPrice                                        [UnitPrice]
		   ,Amount								 [AmountReceipt] 
		   ,InterimPaymentLineId
		   		     
FROM TaxItemLines TTL
lEFT JOIN TaxItems tx ON tx.id = ttl.TaxItemId
WHERE   TTL.TaxItemId = @TaxItemId AND ISNULL(ttl.SetDocId,0) <> 0 
AND @type NOT IN (438,38)

UNION ALL

SELECT     NULL Line_No
		   ,LineNumber 
		   ,NULL [IVcode] 
		   ,NULL     [RefDocType]
           ,description        [Description]
           ,NULL                          [DocQty]
           ,NULL                      [DocUnitName]
		   ,NULL                            [Discount]
		   ,NULL                                        [UnitPrice]
		   ,NULL								 [AmountReceipt] 
		   ,NULL   InterimPaymentLineId
		   		     
FROM TaxItemLines TTL
WHERE   TTL.TaxItemId = @TaxItemId AND SystemCategoryId =-2
AND @type NOT IN (438,38)

UNION ALL

SELECT     ROW_NUMBER() OVER(ORDER BY ttl.linenumber) Line_No
		   ,ttl.LineNumber 
		   ,pl.RefDocCode [IVcode] 
		   ,ttl.SetDocType     [RefDocType]
           ,ttl.description        [Description]
           ,ttl.DocQty                          [DocQty]
           ,ttl.DocUnitName                      [DocUnitName]
		   ,CAST(ttl.DiscountAmount as money)                            [Discount]
		   ,ttl.UnitPrice                                        [UnitPrice]
		   ,(ttl.DocQty * ttl.UnitPrice) - CAST(ttl.DiscountAmount as money)     					 [AmountReceipt] 
		   ,ttl.InterimPaymentLineId
		   
		   		     
FROM TaxItemLines TTL
lEFT JOIN TaxItems tx ON tx.id = ttl.TaxItemId
LEFT JOIN ProductInvoiceARLines pl ON pl.id = ttl.SetDocLineId
WHERE   TTL.TaxItemId = @TaxItemId AND ISNULL(ttl.SetDocId,0) <> 0
		AND TTL.SystemCategoryId NOT IN  (-2,107,124)
		AND @type = 438

UNION ALL

SELECT     NULL Line_No
		   ,LineNumber 
		   ,NULL [IVcode] 
		   ,NULL     [RefDocType]
           ,description        [Description]
           ,NULL                          [DocQty]
           ,NULL                      [DocUnitName]
		   ,NULL                            [Discount]
		   ,NULL                                        [UnitPrice]
		   ,NULL								 [AmountReceipt] 
		   ,NULL   InterimPaymentLineId
		   		     
FROM TaxItemLines TTL
WHERE   TTL.TaxItemId = @TaxItemId AND SystemCategoryId =-2
		AND @type = 438

UNION ALL

SELECT     ROW_NUMBER() OVER(ORDER BY ttl.linenumber) Line_No
		   ,ttl.LineNumber 
		   ,pl.RefDocCode [IVcode] 
		   ,ttl.SetDocType     [RefDocType]
           ,ttl.description        [Description]
           ,ttl.DocQty                          [DocQty]
           ,ttl.DocUnitName                      [DocUnitName]
		   ,CAST(ttl.DiscountAmount as money)                            [Discount]
		   ,ttl.UnitPrice                                        [UnitPrice]
		   ,(ttl.DocQty * ttl.UnitPrice) - CAST(ttl.DiscountAmount as money)     					 [AmountReceipt] 
		   ,ttl.InterimPaymentLineId
		   
		   		     
FROM TaxItemLines TTL
lEFT JOIN TaxItems tx ON tx.id = ttl.TaxItemId
LEFT JOIN InvoiceARLines pl ON pl.id = ttl.SetDocLineId
WHERE   TTL.TaxItemId = @TaxItemId AND ISNULL(ttl.SetDocId,0) <> 0
		AND TTL.SystemCategoryId NOT IN  (-2,107,124,55)
		AND @type = 38

UNION ALL

SELECT     NULL Line_No
		   ,LineNumber 
		   ,NULL [IVcode] 
		   ,NULL     [RefDocType]
           ,description        [Description]
           ,NULL                          [DocQty]
           ,NULL                      [DocUnitName]
		   ,NULL                            [Discount]
		   ,NULL                                        [UnitPrice]
		   ,NULL								 [AmountReceipt] 
		   ,NULL   InterimPaymentLineId
		   		     
FROM TaxItemLines TTL
WHERE   TTL.TaxItemId = @TaxItemId AND SystemCategoryId =-2
		AND @type = 38
 ) x
 ORDER BY x.LineNumber
/*5-Company Info*/
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
       
       


-- 4-Receive Method
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT   /* เพิ่ม Receive Method ถ้าดึงไปทำ RV เเล้ว 26/05/2025 By Good */
                pa.LineNumber
                /* IIF(ISNULL(pa.FiscalItemCode,'') = '',b.LocalBankNameCONCAT(b.LocalBankCode,' : ',b.LocalBankName),b.LocalBankName,CONCAT(orl.FiscalItemCheckBank,' : ',b.LocalBankName)) */
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',NULL,pa.BankCode) BankCodeCheck
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.BankCode,NULL) BankCode
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',NULL,pa.LocalBankName) BankNameCheck
        ,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.LocalBankName,NULL) BankName
				,IIF(ISNULL(pa.FiscalItemCode,'') = '',pa.Branch,NULL) Branch,pa.AcctNumber
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
		
        WHERE   j.MadeByTypeId = @Type AND j.MadeByDocId = @DocId
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
					LEFT JOIN Banks b WITH (NOLOCK) ON b.LocalBankCode = ba.BankCode AND b.RegionalCode = 'TH'
					Where rvl.FiscalMetaId IS NOT NULL --rvl.SystemCategoryId = 51
		) pa ON pa.ReceiveVoucherId = rvl.ReceiveVoucherId
		Where rvl.SystemCategoryId IN (51,58) AND ((rvl.TaxItemId = @DocId AND @Type = 151) OR (rvl.DocId = @DocId AND @Type = 51))