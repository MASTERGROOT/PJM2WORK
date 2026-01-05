/*==> Ref:c:\web\prototype-oxygen\notpublish\customprinting\documentcommands\stdfre_v1_sc_progressacceptance.sql ==>*/
 
/*SC_PA_ProgressAcceptance
SC_PA_ProgressAcceptance_DeductionRecord*/

/*EDIT TO VER.2.002 DATE 23-04-2019 BY BANK - แก้เรื่อง Subtotal ที่ Subcontract ไม่ตรงในกณณีที่ดึง VO มาทำ แก้โดยการเอายอด ScDocLineAmount ที่เป็น Systemcat = 105 มา Sum กัน *ยังยังไม่แน่ใจเรื่อง Special Discount ในกรณีเอกสารเป็น VO ตอนนี้เลยใช้ที่ SubContract ไปก่อน*/

DECLARE @p0 NUMERIC(18) = 1 --10818 9650

DECLARE @DocId NUMERIC(18) =@p0
--------------------------------
DECLARE @SubContractId NUMERIC(18) = (SELECT pa.SubContractId FROM dbo.ProgressAcceptances pa WITH (NOLOCK) WHERE pa.Id = @DocId)
DECLARE @Period NUMERIC(18) = (SELECT pa.Period FROM dbo.ProgressAcceptances pa WITH (NOLOCK) WHERE pa.Id = @DocId)

--------------------------------
DECLARE @FormatVat NVARCHAR(5) = 'N2';
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @DocOrgid INT = (select Locationid from dbo.ProgressAcceptances where id = @DocId)
DECLARE @SCId int = (select SubContractId from ProgressAcceptances where id = @DocId);
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#RESubcontracts', 'U') IS NOT NULL
DROP TABLE #RESubcontracts

-- Create the temporary table from a physical table called 'TableName' in schema 'dbo'

SELECT *
INTO #RESubcontracts
FROM (
	SELECT  sc.Id 
        ,sc.Code DocCode
		
		,sc.DocCurrency
		,sc.DocCurrencyRate

		,CAST(ISNULL(st.SubTotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubTotal
		,CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SpecialDiscountDocAmount
		,(CAST(ISNULL(st.SubTotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)) BeforeTax
		,CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) TaxBase
		,CONCAT('7','%')  TaxRate
		,(CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY))*0.07*ISNULL(sc.DocCurrencyRate,1) TaxAmount
		,CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)- CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) 
              + ((CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)- CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY))*0.07*ISNULL(sc.DocCurrencyRate,1))GrandTotal
		,CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)- CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) 
              + ((CAST(ISNULL(st.Subtotal,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY)- CAST(ISNULL(sc.SpecialDiscountDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY))*0.07*ISNULL(sc.DocCurrencyRate,1))
            - ((ISNULL(sc.RetentionAmount,0)+ISNULL(sc.DepositAmount,0)+ISNULL(sc.WHTdocAmount,0))*ISNULL(sc.DocCurrencyRate,1))GrandTotalFooter2
		,FORMAT((ISNULL(sc.RetentionAmount,0)*100/(ISNULL(st.Subtotal,0)-ISNULL(sc.SpecialDiscountDocAmount,0))),'N2') RetentionPercent
		,CAST(ISNULL(sc.RetentionAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) RetentionAmount
		,IIF(FORMAT(ISNULL(sc.DepositPercent,0),'N0') = 0,0,FORMAT(ISNULL(sc.DepositPercent,0),'N0')) DepositPercent
		,CAST(ISNULL(sc.DepositAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) DepositAmount
        ,FORMAT((ISNULL(sc.WHTdocAmount,0)*100/(ISNULL(st.Subtotal,0)-ISNULL(sc.SpecialDiscountDocAmount,0))),'N2') WHTPercent
		--,IIF(CONCAT(FORMAT(ISNULL(sc.WHTPercent,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(sc.WHTPercent,0),'N1'),'%')) WHTPercent
		,CAST(ISNULL(sc.WHTdocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) WHTAmount
		-------------------------------------------------------------------------------------------------------------------------------
		,CAST(ISNULL(st.SubTotal,0) AS MONEY) SubTotalNonFixTH
		,CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY) SpecialDiscountDocAmountNonFixTH
		,(CAST(ISNULL(st.SubTotal,0) AS MONEY) - CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY)) BeforeTaxNonFixTH
		,CAST(ISNULL(st.Subtotal,0) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY) TaxBaseNonFixTH
		,(CAST(ISNULL(st.Subtotal,0) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY))*0.07 TaxAmountNonFixTH
		,(CAST(ISNULL(st.Subtotal,0) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY))+((CAST(ISNULL(st.Subtotal,0) AS MONEY)
			  - CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY))*0.07) GrandTotalNonFixTH
		,CAST(ISNULL(sc.RetentionAmount,0) AS MONEY) RetentionAmountNonFixTH
		,CAST(ISNULL(sc.DepositAmount,0) AS MONEY) DepositAmountNonFixTH
		,CAST(ISNULL(sc.WHTDocAmount,0) AS MONEY) WHTAmountNonFixTH

FROM	dbo.SubContracts sc WITH (NOLOCK)
        LEFT JOIN (
            select SubContractId,SUM(SubTotal) SubTotal
            from (select SubContractId,parent,ROUND(SUM(docqty*(UnitPrice*100/107))-SUM(DiscountAmount),2) SubTotal  
				from SubContractLines scl
            where Path IS NOT NULL AND Parent IS NOT NULL group by SubContractId,parent
			) a group by SubContractId
            ) st ON st.SubContractId = sc.Id



)sc
WHERE	sc.Id = @SCId
select * from #RESubcontracts

IF	OBJECT_ID('tempdb..#Cummulative') IS NOT NULL
	BEGIN													   
	DROP TABLE #Cummulative
    END

SELECT * INTO #Cummulative FROM (
            SELECT cu.SubContractId
			       ,SUM(ISNULL(cu.SubTotal,0)) SubTotal
				   ,SUM(ISNULL(cu.SpecialDiscountDocAmount,0)) SpecialDiscountDocAmount
				   ,SUM(ISNULL(cu.BeforeTax,0)) BeforeTax
				   ,SUM(ISNULL(cu.DepositAmount,0)) DepositAmount
				   ,SUM(ISNULL(cu.TaxBase,0)) TaxBase
				   ,SUM(ISNULL(cu.TaxAmount,0)) TaxAmount
				   ,SUM(ISNULL(cu.RetentionAmount,0)) RetentionAmount
				   ,SUM(ISNULL(cu.WHTAmount,0)) WHTAmount
				   ,SUM(ISNULL(cu.DeductionAmount,0)) DeductionAmount
				   ,SUM(ISNULL(cu.DeductionDiscountAmount,0)) DeductionDiscountAmount
				   ,SUM(ISNULL(cu.GrandTotal,0)) GrandTotal
				   ,SUM(ISNULL(cu.SubTotalNonFixTH,0)) SubTotalNonFixTH
				   ,SUM(ISNULL(cu.SpecialDiscountDocAmountNonFixTH,0)) SpecialDiscountDocAmountNonFixTH
				   ,SUM(ISNULL(cu.BeforeTaxNonFixTH,0)) BeforeTaxNonFixTH
				   ,SUM(ISNULL(cu.DepositAmountNonFixTH,0)) DepositAmountNonFixTH
				   ,SUM(ISNULL(cu.TaxBaseNonFixTH,0)) TaxBaseNonFixTH
				   ,SUM(ISNULL(cu.TaxAmountNonFixTH,0)) TaxAmountNonFixTH
				   ,SUM(ISNULL(cu.RetentionAmountNonFixTH,0)) RetentionAmountNonFixTH
				   ,SUM(ISNULL(cu.WHTAmountNonFixTH,0)) WHTAmountNonFixTH
				   ,SUM(ISNULL(cu.GrandTotalNonFixTH,0)) GrandTotalNonFixTH
			FROM(
                   SELECT pa.Id, CAST(pa.Date AS DATE) DocDate, pa.SubContractId
		                  ,CAST(ISNULL(st.DocSubTotal,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) SubTotal
						  ,CAST(ISNULL(pa.SpecialDiscountDocAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) SpecialDiscountDocAmount
						  ,CAST((ISNULL(st.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) BeforeTax
						  ,CAST(ISNULL(pa.DepositAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) DepositAmount
						  ,CAST((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)TaxBase
						  ,CAST((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0)) * 0.07 * ISNULL(pa.DocCurrencyRate,1) AS MONEY) TaxAmount
						  ,CAST(ISNULL(pa.RetentionAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) RetentionAmount
						  ,CAST(ISNULL(pa.WHTAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) WHTAmount
						  ,CAST(ISNULL(ded.DeductionAmount,0)AS MONEY) DeductionAmount
						  ,CAST(ISNULL(ded.DeductionDiscountAmount,0)AS MONEY) DeductionDiscountAmount
						  ,CAST(((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0))
						  +((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0))*0.07)
						  -ISNULL(pa.RetentionAmount,0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY) GrandTotal
						  ------------------------------------------------------------------------
						  ,CAST(ISNULL(st.DocSubTotal,0) AS MONEY) SubTotalNonFixTH
						  ,CAST(ISNULL(pa.SpecialDiscountDocAmount,0) AS MONEY) SpecialDiscountDocAmountNonFixTH
						  ,CAST((ISNULL(st.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0)) AS MONEY) BeforeTaxNonFixTH
						  ,CAST(ISNULL(pa.DepositAmount,0) AS MONEY) DepositAmountNonFixTH
						  ,CAST((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0)) AS MONEY) TaxBaseNonFixTH
						  ,CAST((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0)) * 0.07 AS MONEY) TaxAmountNonFixTH
						  ,CAST(ISNULL(pa.RetentionAmount,0) AS MONEY) RetentionAmountNonFixTH
						  ,CAST(ISNULL(pa.WHTAmount,0) AS MONEY) WHTAmountNonFixTH
						  ,CAST(((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0))
						  +((ISNULL(st.DocSubTotal,0) - ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(ded.DeductionDiscountAmount,0))*0.07)
						  -ISNULL(pa.RetentionAmount,0)) AS MONEY) GrandTotalNonFixTH
				   FROM dbo.ProgressAcceptances pa WITH (NOLOCK)
						LEFT JOIN (
								select ProgressAcceptanceId,SUM(SCQTY*UnitPrice*100/107) - SUM(SCDiscountDocLineAmount) SCSubTotal
										,SUM(PAQTY*UnitPrice*100/107) - SUM(PADiscountDocLineAmount) PASubTotal
										,SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) DocSubTotal
										,SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) - SUM(SpecialDiscountAmount) MainTaxbase
										,(SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) - SUM(SpecialDiscountAmount))*0.07 MainTaxAmount
									from ProgressAcceptanceLines where  parent IS NOT NULL group by ProgressAcceptanceId
						) st ON st.ProgressAcceptanceId = pa.Id
						INNER JOIN (SELECT  pal.ProgressAcceptanceId, pal.SystemCategoryId, pal.TaxBase, pal.TaxRate, pal.TaxAmount
									FROM    dbo.ProgressAcceptanceLines pal WITH (NOLOCK)
									WHERE   pal.SystemCategoryId IN (123,129,131,199,207)
								   ) vt ON pa.Id = vt.ProgressAcceptanceId

						LEFT JOIN (SELECT pl.ProgressAcceptanceId
									,sum (IIF(pl.SystemCategoryId = 212,doclineamount,0))DeductionAmount  
									,sum (IIF(pl.SystemCategoryId = 214,doclineamount,0))DeductionDiscountAmount  

									FROM dbo.ProgressAcceptancelines pl
									WHERE  pl.SystemCategoryId IN (212,214)
									GROUP BY pl.ProgressAcceptanceId) ded ON ded.ProgressAcceptanceId = pa.id



                   WHERE pa.SubContractId = @SubContractId 
				         AND pa.Period < @Period
						 AND pa.DocStatus NOT IN (-1) 
		   ) cu
		   GROUP BY cu.SubContractId
) Cummulative

        CREATE CLUSTERED INDEX IDX_C_Cummulative_SubContractId ON #Cummulative(SubContractId)
        CREATE INDEX IDX_C_Cummulative_SubTotal_SpecialDiscountDocAmount_BeforeTax_DepositAmount ON #Cummulative(SubTotal,SpecialDiscountDocAmount,BeforeTax,DepositAmount)
		CREATE INDEX IDX_C_Cummulative_TaxBase_TaxAmount_RetentionAmount_WHTAmount_DeductionAmount_GrandTotal ON #Cummulative(TaxBase,TaxAmount,RetentionAmount,WHTAmount,DeductionAmount,GrandTotal)
		CREATE INDEX IDX_C_Cummulative_SubTotalNonFixTH_SpecialDiscountDocAmountNonFixTH_BeforeTaxNonFixTH_DepositAmountNonFixTH ON #Cummulative(SubTotalNonFixTH,SpecialDiscountDocAmountNonFixTH,BeforeTaxNonFixTH,DepositAmountNonFixTH)
		CREATE INDEX IDX_C_Cummulative_TaxBaseNonFixTH_TaxAmountNonFixTH_RetentionAmountNonFixTH_WHTAmountNonFixTH_GrandTotalNonFixTH ON #Cummulative(TaxBaseNonFixTH,TaxAmountNonFixTH,RetentionAmountNonFixTH,WHTAmountNonFixTH,GrandTotalNonFixTH)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT p.DocId, p.DocCode, p.DocDate, p.SubContractCode,p.InvoiceCode,FORMAT(p.InvoiceDate,'dd/MM/yyyy') InvoiceDate, p.SubContractDate, p.PeriodNo, p.LocationId, p.LocationCode, p.LocationName, p.LocationAddress, p.Remarks, p.CreateBy, p.CreateTimestamp
       ,p.HeaderTH, p.HeaderEN, p.DueDateStart, p.DueDateEnd, p.DueDate, p.ExtOrgId, p.ExtOrgCode, p.ExtOrgName, p.ExtOrgAddress, p.ExtOrgTaxId, p.ExtOrgBranch, p.ExtOrgContact,p.ExtOrgTel
	   ,p.DocCurrency, p.DocCurrencyRate, p.WorkerId, p.WorkerCode, p.WorkerName, p.DocStatus
	   ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   ,p.SubContractSubTotal, p.SubContractSpecialDiscount, p.SubContractSpecialDiscountAmount,p.SCDeductionDisAmount SubContractdeductionDis,p.SCDeductionRecord SubContractdeductionRecord, p.SubContractBeforeTax, IIF(p.SubContractTaxRate = '0%',0, p.SubContractTaxBase - p.DeductionDiscountAmount -p.SubContractDepositDocAmount) SubContractTaxBase, p.SubContractTaxRate, p.SubContractTaxAmount,p.SubContractWHTAmount, p.SubContractGrandTotal
	   ,p.SubContractRetentionPercent, p.SubContractRetentionDocAmount, p.SubContractDepositPercent, p.SubContractDepositDocAmount	  
	   ,(p.SubContractGrandTotal +p.SCDeductionRecord  + p.SubContractWHTAmount) SubContractTotalAmount
	   ,p.SubTotal, p.SpecialDiscount, p.SpecialDiscountDocAmount
	   , p.BeforeTax, IIF(p.TaxRate ='0%',0, p.TaxBase) TaxBase
	   ,IIF(p.taxrate ='0%',(p.TaxBase + p.TaxAmount -p.RetentionAmount - p.depositamount ),(p.TaxBase + p.TaxAmount -p.RetentionAmount ) )TotalAmount
	   , p.TaxRate, p.TaxAmount, p.GrandTotal,p.DeductionDisAmount,p.DeductionRecord, p.RetentionPercent, p.RetentionAmount, p.DepositPercent, p.DepositAmount
	   ,p.WHTPercent, p.WHTAmount
	    ,p.DeductionAmount
		   ,p.DeductionDiscountAmount 
		   , p.CuSubTotal, p.CuSpecialDiscountDocAmount, p.CuBeforeTax, p.CuDepositAmount, p.CuTaxBase, p.CuTaxAmount, p.CuRetentionAmount, p.CuWHTAmount, p.CuGrandTotal ,p.CuDeductionAmount,p.CuDeductionDiscountAmount
		   ,( p.CuTaxBase + p.CuTaxAmount -CuRetentionAmount ) CuTotalAmount
	   ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0,(p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) )RemainSubTotal
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0,(p.SubContractSpecialDiscountAmount - p.CuSpecialDiscountDocAmount - p.SpecialDiscountDocAmount) )RemainSpecialDiscountAmount
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0,(p.SubContractBeforeTax - p.CuBeforeTax - p.BeforeTax) )RemainBeforeTax
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0, ((p.SubContractTaxBase - p.DeductionDiscountAmount- p.SubContractDepositDocAmount) - p.CuTaxBase - p.TaxBase) )RemainTaxBase
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractTaxAmount - p.CuTaxAmount - p.TaxAmount)) RemainTaxAmount
	   ,(IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0, ((p.SubContractTaxBase - p.DeductionDiscountAmount- p.SubContractDepositDocAmount) - p.CuTaxBase - p.TaxBase) )
	    +IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractTaxAmount - p.CuTaxAmount - p.TaxAmount))
		-IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractRetentionDocAmount - p.CuRetentionAmount - p.RetentionAmount))) RemainTotalAmount
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractGrandTotal - p.CuGrandTotal - p.GrandTotal)) RemainGrandTotal
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractRetentionDocAmount - p.CuRetentionAmount - p.RetentionAmount)) RemainRetentionDocAmount
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractDepositDocAmount - p.CuDepositAmount - p.DepositAmount)) RemainDepositDocAmount

	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0,0,(p.SubContractWHTAmount-p.CuWHTAmount - p.WHTAmount )) RemainWhtAmount
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0,(p.SCDeductionDisAmount - p.CuDeductionDiscountAmount - p.DeductionDiscountAmount) )RemainDeductionDiscount
	   ,IIF((p.SubContractSubTotal - p.CuSubTotal - p.SubTotal) = 0 ,0,(p.SCDeductionRecord - p.CuDeductionAmount - p.DeductionAmount)) RemainDeductionRecord
	   ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   ,p.SubContractSubTotalNonFixTH, p.SubContractSpecialDiscountAmountNonFixTH, p.SubContractBeforeTaxNonFixTH, p.SubContractTaxBaseNonFixTH, p.SubContractTaxAmountNonFixTH
	   ,p.SubContractGrandTotalNonFixTH, p.SubContractRetentionDocAmountNonFixTH, p.SubContractDepositDocAmountNonFixTH, p.SubTotalNonFixTH, p.SpecialDiscountDocAmountNonFixTH
	   ,p.BeforeTaxNonFixTH, p.TaxBaseNonFixTH, p.TaxAmountNonFixTH, p.GrandTotalNonFixTH, p.RetentionAmountNonFixTH, p.DepositAmountNonFixTH, p.WHTAmountNonFixTH,p.CuSubTotalNonFixTH
	   ,p.CuSpecialDiscountDocAmountNonFixTH, p.CuBeforeTaxNonFixTH, p.CuDepositAmountNonFixTH, p.CuTaxBaseNonFixTH, p.CuTaxAmountNonFixTH, p.CuRetentionAmountNonFixTH, p.CuWHTAmountNonFixTH, p.CuGrandTotalNonFixTH
	   ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   ,(p.SubContractSubTotalNonFixTH - p.CuSubTotalNonFixTH - p.SubTotalNonFixTH) RemainSubTotalNonFixTH
	   ,(p.SubContractSpecialDiscountAmountNonFixTH - p.CuSpecialDiscountDocAmountNonFixTH - p.SpecialDiscountDocAmountNonFixTH) RemainSpecialDiscountAmount
	   ,(p.SubContractBeforeTaxNonFixTH - p.CuBeforeTaxNonFixTH - p.BeforeTaxNonFixTH) RemainBeforeTaxNonFixTH
	   ,(p.SubContractTaxBaseNonFixTH - p.CuTaxBaseNonFixTH - p.TaxBaseNonFixTH) RemainTaxBaseNonFixTH
	   ,IIF((p.SubContractTaxBaseNonFixTH - p.CuTaxBaseNonFixTH - p.TaxBaseNonFixTH) = 0,0,(p.SubContractTaxAmountNonFixTH - p.CuTaxAmountNonFixTH - p.TaxAmountNonFixTH)) RemainTaxAmountNonFixTH
	   ,IIF((p.SubContractTaxBaseNonFixTH - p.CuTaxBaseNonFixTH - p.TaxBaseNonFixTH) = 0,0,(p.SubContractGrandTotalNonFixTH - p.CuGrandTotalNonFixTH - p.GrandTotalNonFixTH)) RemainGrandTotalNonFixTH
	   ,IIF((p.SubContractTaxBaseNonFixTH - p.CuTaxBaseNonFixTH - p.TaxBaseNonFixTH) = 0,0,(p.SubContractRetentionDocAmountNonFixTH - p.CuRetentionAmountNonFixTH - p.RetentionAmountNonFixTH)) RemainRetentionDocAmountNonFixTH
	   ,IIF((p.SubContractTaxBaseNonFixTH - p.CuTaxBaseNonFixTH - p.TaxBaseNonFixTH) = 0,0,(p.SubContractDepositDocAmountNonFixTH - p.CuDepositAmountNonFixTH - p.DepositAmountNonFixTH)) RemainDepositDocAmountNonFixTH

		----------------------------------------------------------------- Cumulative This Period ----------------------------------------------------------------------------------------------------
		,p.CuSubTotal + p.SubTotal CUPsubtotal
		,p.CuSpecialDiscountDocAmount + p.SpecialDiscountDocAmount CUPspecialDiscountAmount
		,p.CuDepositAmount + p.DepositAmount CUPdepositAmount
		,p.CuDeductionDiscountAmount + p.DeductionDiscountAmount CUPdeductionDiscountAmount
		,IIF(p.TaxRate ='0%',0, p.CuTaxBase + p.taxbase )CUPtaxbaseAmount
		,p.CuTaxAmount + p.TaxAmount CUPtaxAmount
		,p.CuRetentionAmount + p.RetentionAmount CUPretentionAmount
		,(p.CuTaxBase+p.CuTaxAmount-p.CuRetentionAmount) + IIF(p.taxrate ='0%',(p.TaxBase + p.TaxAmount -p.RetentionAmount - p.depositamount ),(p.TaxBase + p.TaxAmount -p.RetentionAmount ) ) CUPTotalAmount
		,p.CuDeductionAmount + p.DeductionAmount CUPdeductionRecordAmount
		,p.CuWHTAmount + p.WHTAmount CUPwhtAmount
		,p.CuGrandTotal + p.GrandTotal CUPgrandtotalAmount
		
FROM(
SELECT  pa.Id DocId
        ,pa.Code DocCode
		,FORMAT(pa.Date,'dd/MM/yyyy') DocDate
		,pa.SubContractCode
		,pa.InvoiceCode InvoiceCode
		,pa.InvoiceDate InvoiceDate
		,FORMAT(pa.SubContractDate,'dd/MM/yyyy') SubContractDate
		,pa.Period PeriodNo
		,o.Id LocationId
		,o.Code LocationCode
		,o.Name LocationName
		,o.Address LocationAddress
		,pa.Remarks
		,pa.CreateBy
		,FORMAT(pa.CreateTimestamp,'dd/MM/yyyy HH:mm:ss') CreateTimestamp
		,'ใบส่งผลงาน ผู้รับเหมา' HeaderTH
	    ,'PROGRESS ACCEPTANCE' HeaderEN
		,FORMAT(pa.DateStart,'dd/MM/yyyy') DueDateStart
		,FORMAT(pa.DateEnd,'dd/MM/yyyy') DueDateEnd
		,CONCAT(FORMAT(pa.DateStart,'dd/MM/yyyy'),' - ',FORMAT(pa.DateEnd,'dd/MM/yyyy')) DueDate
		,ex.Id ExtOrgId
		,ex.Code ExtOrgCode
		,ex.Name ExtOrgName
		,ex.Address ExtOrgAddress
		,ex.TaxId ExtOrgTaxId
		,CASE WHEN ex.BranchCode ='00000' THEN 'สำนักงานใหญ่'
			  WHEN NULLIF(ex.BranchName,'') IS NOT NULL THEN ex.BranchName
			  ELSE ex.BranchCode END ExtOrgBranch
		,IIF(NULLIF(pa.ExtOrgContact,'') IS NULL,cp.Contract,pa.ExtOrgContact) ExtOrgContact
		,ISNULL(cp.Tel,ex.Tel) ExtOrgTel
		,pa.DocCurrency
		,pa.DocCurrencyRate
		,w.Id WorkerId
		,w.Code WorkerCode
		,w.Name WorkerName
		,cd.Description DocStatus
		,CAST(ISNULL(PAL.SumSCDocLineAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractSubTotal
		,sc.SpecialDiscount SubContractSpecialDiscount
		,( (ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) - ISNULL(pa.SubContractDepositDocAmount,0) - isnull (dda.DeductionDisAmount,0) ) *resc.WHTPercent/100 SubContractWHTAmount
		,CAST(ISNULL(sc.SpecialDiscountAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractSpecialDiscountAmount
		,CAST((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0))*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractBeforeTax
		,CAST((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0))*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractTaxBase
		,CONCAT('7','%') SubContractTaxRate
		,CAST((((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0) - ISNULL(pa.SubContractDepositDocAmount,0) - ISNULL(dda.DeductionDisAmount,ISNULL(deducp.DeductionDiscountAmount,0)) )*0.07)*ISNULL(sc.DocCurrencyRate,1)) /*Exclude VAT*/
		 AS MONEY) SubContractTaxAmount
		,IIF(CONCAT(FORMAT(ISNULL(pa.SubContractDepositPercent,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(pa.SubContractDepositPercent,0),@FormatVat),'%')) SubContractDepositPercent
		,CAST(ISNULL(pa.SubContractDepositDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractDepositDocAmount
		,CONCAT(resc.RetentionPercent,'%') SubContractRetentionPercent
		,CAST(ISNULL(pa.SubContractRetentionDocAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) SubContractRetentionDocAmount
		,CAST(
		       (
					ROUND((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) ,2)

					+ ROUND(((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0) - isnull (dda.DeductionDisAmount,0) - ISNULL(pa.SubContractDepositDocAmount,0))*7/100),2)
					- ISNULL(dda.DeductionDisAmount,ISNULL(deducp.DeductionDiscountAmount,0))
					- ISNULL(pa.SubContractDepositDocAmount,0)
					- ISNULL(pa.SubContractRetentionDocAmount,0)
					- ISNULL(ddr.DeductionDisRecord,ISNULL(deducp.DeductionAmount,0))
					- 
					((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0))- ISNULL(pa.SubContractDepositDocAmount,0) - isnull (dda.DeductionDisAmount,0) ) *resc.WHTPercent/100 /*WHTAmt*/
			 )*ISNULL(sc.DocCurrencyRate,1) 
		 AS MONEY) SubContractGrandTotal
		-----------------------------------------------------------------------------------------------------------------------------------
		,CAST(ISNULL(pal.DocSubTotal,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) SubTotal
		,pa.SpecialDiscount
		,CAST(ISNULL(pa.SpecialDiscountDocAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) SpecialDiscountDocAmount
		,(CAST(ISNULL(pal.DocSubTotal,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(pa.SpecialDiscountDocAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY)) BeforeTax
		,CAST(ISNULL(pal.DocSubTotal,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY)
			  - CAST(ISNULL(pa.SpecialDiscountDocAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) TaxBase
		,CONCAT('7','%') TaxRate
		,CAST(((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))*0.07)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) TaxAmount
		--,CAST(ISNULL(pa.GrandTotal,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) GrandTotal
		,CAST(((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))+((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))*0.07))*ISNULL(pa.DocCurrencyRate,1) - ISNULL(pa.WHTAmount,0)*ISNULL(pa.DocCurrencyRate,1) - isnull (ded.DeductionAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) GrandTotal
		,IIF(CONCAT(FORMAT(ISNULL(pa.RetentionPercent,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(pa.RetentionAmount,0)*100/(ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0)),@FormatVat),'%')) RetentionPercent
		,CAST(ISNULL(pa.RetentionAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) RetentionAmount
		,IIF(CONCAT(FORMAT(ISNULL(pa.DepositPercent,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(pa.DepositPercent,0),@FormatVat),'%')) DepositPercent
		,CAST(ISNULL(pa.DepositAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) DepositAmount
		,IIF(CONCAT(FORMAT(ISNULL(pa.WHTPercent,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(pa.WHTAmount,0)*100/(ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0)-ISNULL(pa.DepositAmount,0)-ISNULL(dda.DeductionDisAmount,0)),@FormatVat),'%')) WHTPercent
		,CAST(ISNULL(pa.WHTAmount,0)*ISNULL(pa.DocCurrencyRate,1) AS MONEY) WHTAmount
		-----------------------------------------------------------------------------------------------------------------------------------
		,ISNULL(cu.SubTotal,0) CuSubTotal, ISNULL(cu.SpecialDiscountDocAmount,0) CuSpecialDiscountDocAmount, ISNULL(cu.BeforeTax,0) CuBeforeTax, ISNULL(cu.DepositAmount,0) CuDepositAmount, ISNULL(cu.TaxBase,0) CuTaxBase
		,ISNULL(cu.TaxAmount,0) CuTaxAmount, ISNULL(cu.RetentionAmount,0) CuRetentionAmount, ISNULL(cu.WHTAmount,0) CuWHTAmount
		--, ISNULL(cu.GrandTotal,0) CuGrandTotal
		, ISNULL(cu.GrandTotal,0)-ISNULL(cu.WHTAmount,0) - ISNULL(cu.DeductionAmount,0) CuGrandTotal
		,ISNULL(cu.DeductionAmount,0)CuDeductionAmount
		,ISNULL(cu.DeductionDiscountAmount,0)CuDeductionDiscountAmount
		-------------------------------------------------------------------------------------------------------------------------------------

		,CAST(ISNULL(dda.DeductionDisAmount,ISNULL(deducp.DeductionDiscountAmount,0)) AS MONEY) SCDeductionDisAmount
		,CAST(ISNULL(ddr.DeductionDisRecord,ISNULL(deducp.DeductionAmount,0)) AS MONEY) SCDeductionRecord
		,CAST(ISNULL(dda.DeductionDisAmount,0) AS MONEY) DeductionDisAmount
		,CAST(ISNULL(ddr.DeductionDisRecord,0) AS MONEY) DeductionRecord
		,CAST(ISNULL(PAL.SumSCDocLineAmount,0) AS MONEY) SubContractSubTotalNonFixTH
		,sc.SpecialDiscount SubContractSpecialDiscountNonFixTH
		,CAST(ISNULL(sc.SpecialDiscountAmount,0) AS MONEY) SubContractSpecialDiscountAmountNonFixTH
		,CAST((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) AS MONEY) SubContractBeforeTaxNonFixTH
		,CAST((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) AS MONEY) SubContractTaxBaseNonFixTH
		,IIF(CONCAT(FORMAT(ISNULL(scl.TaxRate,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(scl.TaxRate,0),@FormatVat),'%')) SubContractTaxRateNonFixTH
		,CAST((((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) - ((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0))*100/107)))
		 AS MONEY) SubContractTaxAmountNonFixTH
		,IIF(CONCAT(FORMAT(ISNULL(pa.SubContractDepositPercent,0),@FormatVat),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(pa.SubContractDepositPercent,0),@FormatVat),'%')) SubContractDepositPercentNonFixTH
		,CAST(ISNULL(pa.SubContractDepositDocAmount,0) AS MONEY) SubContractDepositDocAmountNonFixTH
		,CONCAT(resc.RetentionPercent,'%') SubContractRetentionPercentNonFixTH
		,CAST(ISNULL(pa.SubContractRetentionDocAmount,0) AS MONEY) SubContractRetentionDocAmountNonFixTH
		,CAST(
		       (
					ROUND((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0)) ,2)

					+ ROUND(((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0) - isnull (dda.DeductionDisAmount,0) - ISNULL(pa.SubContractDepositDocAmount,0))*7/100),2)
					- ISNULL(dda.DeductionDisAmount,ISNULL(deducp.DeductionDiscountAmount,0))
					- ISNULL(pa.SubContractDepositDocAmount,0)
					- ISNULL(pa.SubContractRetentionDocAmount,0)
					- ISNULL(ddr.DeductionDisRecord,ISNULL(deducp.DeductionAmount,0))
					- 
					((ISNULL(PAL.SumSCDocLineAmount,0) - ISNULL(sc.SpecialDiscountAmount,0))- ISNULL(pa.SubContractDepositDocAmount,0) - isnull (dda.DeductionDisAmount,0) ) *resc.WHTPercent/100 /*WHTAmt*/
			 )
		 AS MONEY) SubContractGrandTotalNonFixTH
		-----------------------------------------------------------------------------------------------------------------------------------
		,CAST(ISNULL(pal.DocSubTotal,0) AS MONEY) SubTotalNonFixTH
		,CAST(ISNULL(pa.SpecialDiscountDocAmount,0) AS MONEY) SpecialDiscountDocAmountNonFixTH
		,(CAST(ISNULL(pal.DocSubTotal,0) AS MONEY) - CAST(ISNULL(pa.SpecialDiscountDocAmount,0) AS MONEY)) BeforeTaxNonFixTH
		,CAST(ISNULL(pal.DocSubTotal,0) AS MONEY)- CAST(ISNULL(pa.SpecialDiscountDocAmount,0) AS MONEY) TaxBaseNonFixTH
		,CAST(((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))*0.07) AS MONEY) TaxAmountNonFixTH
		,CAST(((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))+((ISNULL(pal.DocSubTotal,0)-ISNULL(pa.SpecialDiscountDocAmount,0))*0.07)) - ISNULL(pa.WHTAmount,0) - isnull (ded.DeductionAmount,0) AS MONEY) GrandTotalNonFixTH
		,CAST(ISNULL(pa.RetentionAmount,0) AS MONEY) RetentionAmountNonFixTH
		,CAST(ISNULL(pa.DepositAmount,0) AS MONEY) DepositAmountNonFixTH
		,CAST(ISNULL(pa.WHTAmount,0) AS MONEY) WHTAmountNonFixTH
		---------------------------------------------------------------------------------------------------------------------------------
		,ISNULL(cu.SubTotalNonFixTH,0) CuSubTotalNonFixTH, ISNULL(cu.SpecialDiscountDocAmountNonFixTH,0) CuSpecialDiscountDocAmountNonFixTH, ISNULL(cu.BeforeTaxNonFixTH,0) CuBeforeTaxNonFixTH, ISNULL(cu.DepositAmountNonFixTH,0) CuDepositAmountNonFixTH
		,ISNULL(cu.TaxBaseNonFixTH,0) CuTaxBaseNonFixTH, ISNULL(cu.TaxAmountNonFixTH,0) CuTaxAmountNonFixTH, ISNULL(cu.RetentionAmountNonFixTH,0) CuRetentionAmountNonFixTH, ISNULL(cu.WHTAmountNonFixTH,0) CuWHTAmountNonFixTH, ISNULL(cu.GrandTotalNonFixTH,0) CuGrandTotalNonFixTH
		,isnull (ded.DeductionAmount,0)DeductionAmount
		,isnull (ded.DeductionDiscountAmount,0)DeductionDiscountAmount


FROM	dbo.ProgressAcceptances pa WITH (NOLOCK)
		LEFT JOIN ( SELECT  pal.ProgressAcceptanceId, pal.SystemCategoryId, pal.TaxBase, pal.TaxRate, pal.TaxAmount
					FROM    dbo.ProgressAcceptanceLines pal WITH (NOLOCK)
					WHERE   pal.SystemCategoryId IN (123,129,131,199,207) AND pal.ProgressAcceptanceId = @DocId
					) vt ON pa.Id = vt.ProgressAcceptanceId
		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON pa.ExtOrgId = ex.Id
		LEFT JOIN (SELECT dbo.GROUP_CONCAT_D( Code,',') Code,refdocid,RefDocTypeId,date  FROM Invoices GROUP BY refdocid,RefDocTypeId,date )ivv ON ivv.RefDocId = pa.id AND ivv.RefDocTypeId = 209
		LEFT JOIN (SELECT cp.ExtOrganizationId
		                  ,IIF(dbo.GROUP_CONCAT_D(DISTINCT CONCAT(cp.Name,' (Tel.',cp.Tel,')'),N', ') NOT IN ('',',',', ',' (Tel.)'),dbo.GROUP_CONCAT_D(DISTINCT CONCAT(cp.Name,' (Tel.',cp.Tel,')'),N', '),'') [Contract]  
						  ,cp.Tel
		           FROM dbo.ContactPersons cp WITH (NOLOCK)
				   GROUP BY cp.ExtOrganizationId,cp.Tel
				   ) cp ON cp.ExtOrganizationId = ex.Id		
		LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON o.Id = pa.LocationId
		LEFT JOIN dbo.Workers w WITH (NOLOCK) ON w.Id = pa.WorkerId
		LEFT JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = pa.DocStatus
		LEFT JOIN #Cummulative cu ON cu.SubContractId = pa.SubContractId
		LEFT JOIN dbo.SubContracts sc WITH (NOLOCK) ON sc.Id = pa.SubContractId
		LEFT JOIN dbo.SubContractLines scl WITH (NOLOCK) ON scl.SystemCategoryId IN (123,129,131,199,207) AND scl.SubContractId = pa.SubContractId
		LEFT JOIN #RESubcontracts resc ON  resc.Id = pa.SubContractId
		LEFT JOIN (SELECT pal.ProgressAcceptanceId
		                   ,SUM(ISNULL(pal.SCQTY*pal.UnitPrice*100/107,0)) - SUM(pal.SCDiscountDocLineAmount) SumSCDocLineAmount
						   ,SUM(pal.PAQTY*pal.UnitPrice*100/107) - SUM(pal.PADiscountDocLineAmount) PASubTotal
							,SUM(pal.DocQTY*pal.UnitPrice*100/107) - SUM(pal.DiscountDocLineAmount) DocSubTotal
							,SUM(pal.DocQTY*pal.UnitPrice*100/107) - SUM(pal.DiscountDocLineAmount) - SUM(pal.SpecialDiscountAmount) MainTaxbase
							,(SUM(pal.DocQTY*pal.UnitPrice*100/107) - SUM(pal.DiscountDocLineAmount) - SUM(pal.SpecialDiscountAmount))*0.07 MainTaxAmount
		            FROM dbo.ProgressAcceptanceLines pal WITH (NOLOCK)
					WHERE pal.SystemCategoryId IN (99,100,105)
					GROUP BY pal.ProgressAcceptanceId
				   ) PAL ON PAL.ProgressAcceptanceId = pa.Id
		LEFT JOIN (SELECT pl.ProgressAcceptanceId
					,sum (IIF(pl.SystemCategoryId = 212,doclineamount,0))DeductionAmount  
					,sum (IIF(pl.SystemCategoryId = 214,doclineamount,0))DeductionDiscountAmount  

					FROM dbo.ProgressAcceptancelines pl
					WHERE  pl.SystemCategoryId IN (212,214)
					GROUP BY pl.ProgressAcceptanceId) ded ON ded.ProgressAcceptanceId = pa.id

		--LEFT JOIN (SELECT dr.SubContractid,SUM(drl.CostAmount)SUMdeduction  FROM dbo.DeductionRecords dr

		--			LEFT JOIN dbo.DeductionRecordLines drl ON dr.Id = drl.DeductionRecordId			
		--			GROUP BY dr.SubContractid
		--			)d ON d.subcontractid = sc.Id

		LEFT JOIN (
				   SELECT SystemCategoryId,ProgressAcceptanceId,SUM(Amount) DeductionDisAmount FROM ProgressAcceptanceLines WHERE ProgressAcceptanceId =@DocId	 AND SystemCategoryId =214 GROUP BY ProgressAcceptanceId,SystemCategoryId
				  ) dda  ON dda.ProgressAcceptanceId = pa.id
		LEFT JOIN (
				   SELECT SystemCategoryId,ProgressAcceptanceId,SUM(Amount) DeductionDisRecord FROM ProgressAcceptanceLines WHERE ProgressAcceptanceId =@DocId	 AND SystemCategoryId =212 GROUP BY ProgressAcceptanceId,SystemCategoryId
				  ) ddr  ON ddr.ProgressAcceptanceId = pa.id
		LEFT JOIN (	
					 SELECT pl.ProgressAcceptanceId
									,sum (IIF(pl.SystemCategoryId = 212,doclineamount,0))DeductionAmount  
									,sum (IIF(pl.SystemCategoryId = 214,doclineamount,0))DeductionDiscountAmount  
									,pa.SubContractId
									FROM dbo.ProgressAcceptancelines pl
									LEFT JOIN ProgressAcceptances pa ON pa.id =pl.ProgressAcceptanceId
									WHERE  pl.SystemCategoryId IN (212,214)
											AND pa.SubContractId = @SubContractId 
											AND pa.Period < @Period
											AND pa.DocStatus NOT IN (-1) 
									GROUP BY pl.ProgressAcceptanceId,pa.SubContractId
		
					) deducp ON deducp.SubContractId = pa.SubContractId

WHERE	pa.Id = @DocId
) p


/* 2-Line */

SELECT pal.Code
       ,pal.LineNumber
	   ,pal.SystemCategory
	   ,pal.SystemCategoryId
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',ic.Code) ItemCategoryCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',ic.Name) ItemCategoryName
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',im.Code) ItemMetaCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',im.Name) ItemMetaName
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',IIF(im.Code IS NULL,ic.Code,im.Code)) ItemCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',IIF(im.Code IS NULL,ic.Name,im.Name)) ItemName
	   ,IIF(pal.SystemCategoryId IN (-2),'',pal.ClearMethodName) ClearMethodName
	   ,pal.Description
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',pal.DocUnitName) DocUnitName
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,ISNULL(pal.SCQTY,0)) SCQTY
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST((ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) / NULLIF(ISNULL(pal.SCQTY,0),0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) SCUnitPrice
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.SCDiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) SCDiscountAmount
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.SCMainAmount,CAST(ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) SCAmount
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.PAQTY,0) AS MONEY)) PAQTY
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST((ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) / NULLIF(ISNULL(pal.PAQTY,0),0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PAUnitPrice
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PADiscountDocLineAmount
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.PAMainAmount,CAST(ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PADocLineAmount
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.PAMainAmount,CAST(ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PAWorkDone
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,ISNULL(pal.DocQty,0)) DocQty
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.UnitPrice*100/107,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) UnitPrice
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',pal.Discount) Discount
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.DiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) DiscountAmount
	   ,IIF(pal.SystemCategoryId IN (-2),NULL,CAST(IIF(ISNULL(pal.Amount,0) = 0,ISNULL(mr.DocMainAmount,0),ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount,0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) Amount
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,pal.CalcVat) CalcVat
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.UnitCost,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) UnitCost
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.CostAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) CostAmount
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.MainTaxbase,CAST(ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount-pal.SpecialDiscountAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) TaxBase
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',CONCAT('7','%')) TaxRate
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.MainTaxAmount,CAST(ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount-pal.SpecialDiscountAmount,0)* 0.07 * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) TaxAmount
	   -----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,(ISNULL(pal.SCQTY,0) - ISNULL(pal.PAQTY,0) - ISNULL(pal.DocQty,0))) RemainCountQty
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.SCMainAmount-mr.PAMainAmount-mr.DocMainAmount,CAST((ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) - ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) - IIF(ISNULL(pal.Amount,0) = 0,NULL,ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount,0))) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) RemainAmount
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST((ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) / NULLIF(ISNULL(pal.SCQTY,0),0)) AS MONEY)) SCUnitPriceNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.SCDiscountDocLineAmount,0) AS MONEY)) SCDiscountAmount
	   ,IIF(pal.SystemCategoryId IN (-2),NULL,CAST(ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) AS MONEY)) SCAmountNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.PAQTY,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PAQTYNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST((ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) / NULLIF(ISNULL(pal.PAQTY,0),0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PAUnitPriceNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PADiscountDocLineAmountNonFixTH
	   ,IIF(pal.SystemCategoryId IN (-2),NULL,CAST(ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PADocLineAmountNonFixTH
	   ,IIF(pal.SystemCategoryId IN (-2),NULL,CAST(ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) PAWorkDoneNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.UnitPrice*100/107,0) AS MONEY)) UnitPriceNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.DiscountDocLineAmount,0) AS MONEY)) DiscountAmountNonFixTH
	   ,IIF(pal.SystemCategoryId IN (-2),NULL,CAST(IIF(ISNULL(pal.Amount,0) = 0,ISNULL(mr.DocMainAmount,0),ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount,0)) AS MONEY)) AmountNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.UnitCost,0) AS MONEY)) UnitCostNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.CostAmount,0) AS MONEY)) CostAmountNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.MainTaxbase,CAST(ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount-pal.SpecialDiscountAmount,0) AS MONEY)) TaxBaseNonFixTH
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.MainTaxAmount,CAST(ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount-pal.SpecialDiscountAmount,0)* 0.07 AS MONEY)) TaxAmountNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.SCMainAmount-mr.PAMainAmount-mr.DocMainAmount,CAST((ISNULL((pal.SCQTY*pal.UnitPrice*100/107)-pal.SCDiscountDocLineAmount,0) - ISNULL((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount,0) - IIF(ISNULL(pal.Amount,0) = 0,NULL,ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount,0)))AS MONEY)) RemainAmountNonFixTH
	   ----------------------------------------------------------------- Cumulative This Period ----------------------------------------------------------------------------------------------------
	   ,IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(ISNULL(pal.PAQTY,0) AS MONEY))  + IIF(pal.SystemCategoryId IN (0,-2),NULL,ISNULL(pal.DocQty,0)) CUPQty
	   ,UnitPrice*100/107 CUPunitPrice
	   ,IIF(pal.SystemCategoryId IN (0,-2),mr.PAMainAmount,CAST((pal.PAQTY*pal.UnitPrice*100/107)-pal.PADiscountDocLineAmount
	   * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) + IIF(pal.SystemCategoryId IN (0,-2),NULL,CAST(IIF(ISNULL(pal.Amount,0) = 0,ISNULL(mr.DocMainAmount,0),ISNULL((pal.DocQTY*pal.UnitPrice*100/107)-pal.DiscountDocLineAmount,0)) * ISNULL(pa.DocCurrencyRate,1) AS MONEY)) CUPAmount

FROM dbo.ProgressAcceptanceLines pal WITH (NOLOCK)
	LEFT JOIN dbo.ItemCategories ic WITH (NOLOCK) ON ic.Id = pal.ItemCategoryId
	LEFT JOIN dbo.ItemMetas im WITH (NOLOCK) ON im.Id = pal.ItemMetaId
	INNER JOIN ProgressAcceptances pa WITH (NOLOCK) ON pa.Id = pal.ProgressAcceptanceId
	LEFT JOIN (
			select parent,SUM(SCQTY*UnitPrice*100/107) - SUM(SCDiscountDocLineAmount) SCMainAmount
					,SUM(PAQTY*UnitPrice*100/107) - SUM(PADiscountDocLineAmount) PAMainAmount
					,SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) DocMainAmount
					,SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) - SUM(SpecialDiscountAmount) MainTaxbase
					,(SUM(DocQTY*UnitPrice*100/107) - SUM(DiscountDocLineAmount) - SUM(SpecialDiscountAmount))*0.07 MainTaxAmount
				from ProgressAcceptanceLines where  parent IS NOT NULL AND ProgressAcceptanceId = @DocId group by Parent
    ) mr ON mr.parent = pal.Code
WHERE pal.ProgressAcceptanceId = @DocId
      AND pal.SystemCategoryId NOT IN (123,129,131,199,207,46,47,212,54,214)
ORDER BY pal.LineNumber
/* 214 = drdiscount,212= drrecord */
/*3-Other*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
ROW_NUMBER()OVER(ORDER BY pal.LineNumber)Line_No
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',ic.Code) ItemCategoryCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',ic.Name) ItemCategoryName
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',im.Code) ItemMetaCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',im.Name) ItemMetaName
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',IIF(im.Code IS NULL,ic.Code,im.Code)) ItemCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',IIF(im.Code IS NULL,ic.Name,im.Name)) ItemName
	   ,pal.Description
	   ,pal.RefDocCode
	   ,IIF(pal.SystemCategoryId IN (0,-2),'',pal.DocUnitName) DocUnitName
		,IIF(pal.SystemCategoryId IN (0,-2),NULL,ISNULL(pal.DocQty,0)) DocQty
		,pal.UnitPrice
		,pal.Amount
FROM dbo.ProgressAcceptanceLines pal
	LEFT JOIN dbo.ItemCategories ic WITH (NOLOCK) ON ic.Id = pal.ItemCategoryId
	LEFT JOIN dbo.ItemMetas im WITH (NOLOCK) ON im.Id = pal.ItemMetaId
where pal.ProgressAcceptanceId = @DocId
and pal.SystemCategoryId = 212

/*4-Payment*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT '4-Payment' TableMappingName;

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

DROP TABLE #Cummulative

-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#RESubcontracts', 'U') IS NOT NULL
DROP TABLE #RESubcontracts