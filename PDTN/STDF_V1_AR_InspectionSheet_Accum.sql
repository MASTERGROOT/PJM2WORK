/*==> Ref:c:\web\prototype-fcd\notpublish\customprinting\documentcommands\stdf_v1_ar_inspectionsheet_accum.sql ==>*/
 
 
--DECLARE @p0 Numeric(10) = 1105
--DECLARE @p1 Numeric(10) = 127

DECLARE @InspectionSheetId Numeric(10) =@p0
DECLARE @TypeId Numeric(10) = @p1
DECLARE @DocOrgid INT = (select orgid from dbo.InspectionSheets where id = @InspectionSheetId)

/*1-Info*/
---------------------------------------------------------------------------------------------------------------------------------------------------------------------:)
SELECT	ISS.Id ,ISS.Code ,CAST(ISS.Date AS DATE) [Date],IR.Code InterimCode ,IR.OriginalContractNO
	    ,CAST(IR.OriginalContractStartDate AS DATE) OriginalContractStartDate, CAST(IR.OriginalContractEndDate AS DATE) OriginalContractEndDate
        ,ISS.OrgCode ,ISS.OrgName ,ISS.ExtOrgCode, ISS.ExtOrgName, Ext.Address ExtOrgAddress, Ext.Tel ExtOrgTel
		,Ext.Fax ExtOrgFax, Ext.TaxId ExtOrgTaxId
		,CASE WHEN ISNULL(Ext.BranchName,'') !='' AND Ext.BranchCode != '00000' THEN Ext.BranchName
			  WHEN Ext.BranchCode ='00000' THEN 'สำนักงานใหญ่' 
			  ELSE Ext.BranchCode END [ExtOrgBranch]
		,Con.Name ExtOrgContract, Con.Tel ExtOrgConTel ,ISS.Remarks
		,ISNULL(TOT.LineAmount,0) SubTotal ,ISNULL(SUB.Discount,0) SpecialDiscount ,ISNULL(SUB.Deposit,0) Deposit
		,CASE WHEN ISNULL(Vat.Taxbase,0) = 0 THEN (ISNULL(TOT.LineAmount,0)- ISNULL(SUB.Discount,0))- ISNULL(SUB.Deposit,0) ELSE Vat.Taxbase END Taxbase
		,Vat.SystemCategory ,CONCAT(FORMAT(ISNULL(VAT.Taxrate,0),'N0'),'%') VatRate ,ISNULL(Vat.TaxAmount,0) VatAmount
		,CONCAT(FORMAT(ISNULL(ir.RetentionRate,0),'N0'),'%')  RetentionRate
		,ISNULL(SUB.Retention,0) Retention ,ISNULL(SUB.Penalty,0) Penalty 
		,CASE WHEN ISNULL(Vat.Taxbase,0) = 0 THEN (ISNULL(TOT.LineAmount,0)- ISNULL(SUB.Discount,0))- ISNULL(SUB.Deposit,0) ELSE Vat.Taxbase END
			+ISNULL(Vat.TaxAmount,0)
			-ISNULL(SUB.Retention,0) 
			GrandTotal 
		,ISS.DocCurrency
		--,REPLACE(cl1.DataValues,',','                                              ') Remarks
		,'ส่งงวดงาน' HeaderTH
	    ,'INSPECTION SHEET' HeaderEN
FROM	dbo.InspectionSheets ISS WITH (NOLOCK)
		LEFT JOIN dbo.ExtOrganizations Ext WITH (NOLOCK) ON Ext.Id = ISS.ExtOrgId
		LEFT JOIN dbo.ContactPersons Con WITH (NOLOCK) ON Con.ExtOrganizationId = ISS.ExtOrgId
		LEFT JOIN dbo.InterimPayments  IR WITH (NOLOCK) ON IR.Id = ISS.InterimPaymentApplicationId
		LEFT JOIN (SELECT IL.InspectionSheetId, IL.LineAmount FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId = 107 )TOT ON TOT.InspectionSheetId = ISS.Id
		LEFT JOIN (SELECT IL.InspectionSheetId, IL.LineAmount FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId = 111 ) GAN ON GAN.InspectionSheetId = ISS.Id
		LEFT JOIN (SELECT IL.InspectionSheetId, IL.SystemCategory, IL.TaxBase, IL.TaxAmount, IL.TaxRate FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (123,129,131,152) )VAT ON VAT.InspectionSheetId = ISS.Id
		LEFT JOIN (SELECT	ISL.InspectionSheetId ,SUM(ISNULL(ISL.SubtractDeposit,0)) Deposit ,SUM(ISNULL(ISL.SubtractPenalty,0)) Penalty ,
						    SUM(ISNULL(ISL.SubtractRetention,0)) Retention, SUM(ISNULL(ISL.SubtractDiscount,0)) Discount
			        FROM	dbo.InspectionSheetLines ISL WITH (NOLOCK) GROUP BY ISL.InspectionSheetId )SUB ON SUB.InspectionSheetId= ISS.Id
		LEFT JOIN dbo.SubDocTypes se WITH (NOLOCK) ON se.Id = ISS.SubDocTypeId
		--LEFT JOIN dbo.CustomNoteLines cl1 ON cl1.DocGuid = iss.guid AND cl1.KeyName = 'รายละเอียดเพิ่มเติม'
WHERE	ISS.Id = @InspectionSheetId


/*This Payment*/
-----------------------------------------------------------------------------------------------------------------------------------------------
Select	iss.OrgName,iss.Code
		,Format(pj.ContractAmount,'N2') ContractAmount
		,isl.SystemCategory TypeVat
		,FORMAT(pj.StartDate,'dd MMMM yyyy') StartDate
		,FORMAT(pj.EndDate,'dd MMMM yyyy') EndDate
		,FORMAT(iss.Date,'dd MMMM yyyy') DocDate
		,Format((pj.ContractAmount +(pj.ContractAmount*7/100)),'N2') ContractAmountIncludeVat
		,ISNULL(vo.ContractAmount,0) VOAmount
		,(pj.ContractAmount+ISNULL(vo.ContractAmount,0)) TotalContractAmount
		,Format(im.Deposit,'N2') TotalDepositAmount
		,isl.Subtotal
		,isl.DepositAmount
		,isl.Retention
		,isl.TotalAmount
		,isl.TaxAmount
		,isl.GrandTotal
		,isl.WHT
		,Format(isl.GrandTotal-isl.WHT,'N2') TotalPayment
		,iss.ExtOrgName
		,Format(im.RetentionRate,'N0') RetentionRate
From dbo.InspectionSheets iss
Left Join dbo.Organizations_ProjectConstruction pj ON pj.Id = iss.OrgId
Left Join dbo.InterimPayments im ON im.Id = iss.InterimPaymentApplicationId
Left Join (Select SUM(ContractAmount) ContractAmount,ProjectConstructionId From dbo.ProjectVOes Group By ProjectConstructionId) vo ON vo.ProjectConstructionId = iss.OrgId
Left Join (
			Select	iss.Id,iss.Code,iss.OrgId,iss.OrgCode,iss.OrgName,TOT.LineAmount Subtotal,sub.Retention,TOT.LineAmount-ISNULL(sub.Retention,0)-ISNULL(dp.LineAmount,0) TotalAmount,vat.SystemCategory
					,vat.TaxRate,vat.TaxAmount,GT.LineAmount GrandTotal,ISNULL(CAST(cl.DataValues AS int),0) WHT,dp.LineAmount DepositAmount
			From dbo.InspectionSheets iss
			Left Join (Select IL.InspectionSheetId, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId = 107 AND InspectionSheetId = @InspectionSheetId) TOT ON TOT.InspectionSheetId = iss.Id
			Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.TaxBase, IL.TaxAmount, IL.TaxRate From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (123,129,131,152) AND InspectionSheetId = @InspectionSheetId)VAT ON VAT.InspectionSheetId = ISS.Id
			Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (111) AND InspectionSheetId = @InspectionSheetId) GT ON GT.InspectionSheetId = ISS.Id
			Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (55) AND InspectionSheetId = @InspectionSheetId ) DP ON DP.InspectionSheetId = ISS.Id
			Left Join (
								SELECT	ISL.InspectionSheetId ,SUM(ISNULL(ISL.SubtractDeposit,0)) Deposit ,SUM(ISNULL(ISL.SubtractPenalty,0)) Penalty ,
										SUM(ISNULL(ISL.SubtractRetention,0)) Retention, SUM(ISNULL(ISL.SubtractDiscount,0)) Discount
								FROM	dbo.InspectionSheetLines ISL WITH (NOLOCK) GROUP BY ISL.InspectionSheetId 
								) sub ON sub.InspectionSheetId = iss.Id
			Left Join dbo.CustomNoteLines cl ON cl.DocGuid = iss.guid AND cl.KeyName = 'WHT'
					) isl ON isl.Id = iss.Id
Where iss.id = @InspectionSheetId


/*Cumulative Value*/
-----------------------------------------------------------------------------------------------------------------------------------------------
Select	iss.OrgId
		,iss.OrgCode
		,iss.OrgName
		,pj.ContractAmount+ISNULL(vo.ContractAmount,0) ContractSum
		,SUM(TOT.LineAmount)+ISNULL(Itr.LineAmount,0) Subtotal
		,SUM(DP.LineAmount) DepositAmount
		,SUM(sub.Retention)+ISNULL(Itr.SubtractRetention,0) Retention
		,SUM(TOT.LineAmount)+ISNULL(Itr.LineAmount,0)-SUM(sub.Retention)-SUM(DP.LineAmount)+ISNULL(Itr.SubtractRetention,0) TotalAmount
		,SUM(vat.TaxAmount)+ISNULL(Itr.TaxAmount,0) TaxAmount
		,SUM(GT.LineAmount)+ISNULL(Itr.BalAmount,0) GrandTotal
		,ISNULL((pj.ContractAmount+ISNULL(vo.ContractAmount,0))-(SUM(TOT.LineAmount)+ISNULL(Itr.LineAmount,0)-SUM(sub.Retention)-SUM(DP.LineAmount)+ISNULL(Itr.SubtractRetention,0)),0) BalanceInHand
From dbo.InspectionSheets iss
Left Join dbo.Organizations_ProjectConstruction pj ON pj.Id = iss.OrgId
Left Join (Select SUM(ContractAmount) ContractAmount,ProjectConstructionId From dbo.ProjectVOes Group By ProjectConstructionId) vo ON vo.ProjectConstructionId = iss.OrgId
Left Join (SELECT IL.InspectionSheetId, IL.LineAmount FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId = 107) TOT ON TOT.InspectionSheetId = iss.Id
Left Join (SELECT IL.InspectionSheetId, IL.SystemCategory, IL.TaxBase, IL.TaxAmount, IL.TaxRate FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (123,129,131,152) )VAT ON VAT.InspectionSheetId = ISS.Id
Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (111) ) GT ON GT.InspectionSheetId = ISS.Id
Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (55) AND IL.LineNumber = 0 ) DP ON DP.InspectionSheetId = ISS.Id
Left Join (
			SELECT	ISL.InspectionSheetId ,SUM(ISNULL(ISL.SubtractDeposit,0)) Deposit ,SUM(ISNULL(ISL.SubtractPenalty,0)) Penalty ,
						    SUM(ISNULL(ISL.SubtractRetention,0)) Retention, SUM(ISNULL(ISL.SubtractDiscount,0)) Discount
			        FROM	dbo.InspectionSheetLines ISL WITH (NOLOCK) GROUP BY ISL.InspectionSheetId ) sub ON sub.InspectionSheetId = iss.Id
Left Join (Select	InterimPaymentId,ProjectId,
					SUM(ISNULL(LineAmount,0)) LineAmount,
					SUM(ISNULL(SubtractDeposit,0)) SubtractDeposit,
					SUM(ISNULL(SubtractRetention,0)) SubtractRetention,
					SUM(ISNULL(SubtractPenalty,0)) SubtractPenalty,
					SUM(ISNULL(SubtractDiscount,0)) SubtractDiscount,
					SUM(ISNULL(BalAmount,0)) BalAmount,
					SUM(ISNULL(TaxBase,0)) TaxBase,
					SUM(ISNULL(TaxAmount,0)) TaxAmount
			From dbo.InterimPaymentLines Where  SystemCategoryId = 169
			Group By	InterimPaymentId,
						ProjectId) Itr ON Itr.ProjectId = iss.OrgId

Where iss.OrgId =  @DocOrgid AND iss.id <= @InspectionSheetId and iss.DocStatus <> -1
Group By	iss.OrgId
			,iss.OrgCode
			,iss.OrgName
			,pj.ContractAmount
			,vo.ContractAmount
			,Itr.LineAmount
			,Itr.SubtractRetention
			,Itr.TaxAmount
			,Itr.BalAmount



/*Previous Value*/
-----------------------------------------------------------------------------------------------------------------------------------------------
Select	iss.OrgId
		,iss.OrgCode
		,iss.OrgName
		,SUM(TOT.LineAmount)+ISNULL(Itr.LineAmount,0) Subtotal
		,SUM(DP.LineAmount) DepositAmount
		,SUM(sub.Retention)+ISNULL(Itr.SubtractRetention,0) Retention
		,SUM(TOT.LineAmount)+ISNULL(Itr.LineAmount,0)-SUM(sub.Retention)+ISNULL(Itr.SubtractRetention,0) TotalAmount
		,vat.SystemCategory
		,vat.TaxRate
		,SUM(vat.TaxAmount)+ISNULL(Itr.TaxAmount,0) TaxAmount
		,SUM(GT.LineAmount)+ISNULL(Itr.BalAmount,0) GrandTotal
From dbo.InspectionSheets iss
Left Join (SELECT IL.InspectionSheetId, IL.LineAmount FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId = 107) TOT ON TOT.InspectionSheetId = iss.Id
Left Join (SELECT IL.InspectionSheetId, IL.SystemCategory, IL.TaxBase, IL.TaxAmount, IL.TaxRate FROM dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (123,129,131,152) )VAT ON VAT.InspectionSheetId = ISS.Id
Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (111) ) GT ON GT.InspectionSheetId = ISS.Id
Left Join (Select IL.InspectionSheetId, IL.SystemCategory, IL.LineAmount From dbo.InspectionSheetLines IL WITH (NOLOCK) WHERE IL.SystemCategoryId IN (55) AND IL.LineNumber = 0 ) DP ON DP.InspectionSheetId = ISS.Id
Left Join (
SELECT	ISL.InspectionSheetId ,SUM(ISNULL(ISL.SubtractDeposit,0)) Deposit ,SUM(ISNULL(ISL.SubtractPenalty,0)) Penalty ,
						    SUM(ISNULL(ISL.SubtractRetention,0)) Retention, SUM(ISNULL(ISL.SubtractDiscount,0)) Discount
			        FROM	dbo.InspectionSheetLines ISL WITH (NOLOCK) GROUP BY ISL.InspectionSheetId ) sub ON sub.InspectionSheetId = iss.Id
Left Join (Select	InterimPaymentId,ProjectId,
					SUM(ISNULL(LineAmount,0)) LineAmount,
					SUM(ISNULL(SubtractDeposit,0)) SubtractDeposit,
					SUM(ISNULL(SubtractRetention,0)) SubtractRetention,
					SUM(ISNULL(SubtractPenalty,0)) SubtractPenalty,
					SUM(ISNULL(SubtractDiscount,0)) SubtractDiscount,
					SUM(ISNULL(BalAmount,0)) BalAmount,
					SUM(ISNULL(TaxBase,0)) TaxBase,
					SUM(ISNULL(TaxAmount,0)) TaxAmount
			From dbo.InterimPaymentLines Where  SystemCategoryId = 169
			Group By	InterimPaymentId,
						ProjectId) Itr ON Itr.ProjectId = iss.OrgId

Where iss.Id < @InspectionSheetId AND OrgId = @DocOrgid and iss.DocStatus <> -1
Group By	iss.OrgId
			,iss.OrgCode
			,iss.OrgName
			,vat.SystemCategory
			,vat.TaxRate
			,Itr.LineAmount
			,Itr.SubtractRetention
			,Itr.TaxAmount
			,Itr.BalAmount

/*5-Company*/
-----------------------------------------------------------------------------------------------------------------------------------------------
EXEC [dbo].[CompanyInfoByOrg] @DocOrgid

/*Inspection Periodic*/
-----------------------------------------------------------------------------------------------------------------------------------------------
Select Count(id) Periodic From dbo.InspectionSheets Where id <= @InspectionSheetId AND OrgId = @DocOrgid
