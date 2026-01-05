/*==> Ref:c:\web\prototype-oxygen\notpublish\customprinting\documentcommands\stdfre_v1_sc_variationorder.sql ==>*/
 
/*SC_VO_VariationOrder*/
/*Edit date 22-04-19 ver.2.01 By Sornthep Delete loss Field*/
/*EDIT DATE 30-04-19 VER.2.02 BY BANK - �������������Ť�ҼԴ������*/

-- DECLARE @p0 NUMERIC(18) = 1

DECLARE @DocId numeric(18) = @p0;
DECLARE @FormatVat NVARCHAR(5) = 'N0';
DECLARE @DocOrgId int = (select LocationId from VariationOrders where id = @DocId);
DECLARE @SCId int = (select SubContractId from VariationOrders where id = @DocId);
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
		,CONCAT(FORMAT((ISNULL(sc.RetentionAmount,0)*100/(ISNULL(st.Subtotal,0)-ISNULL(sc.SpecialDiscountDocAmount,0))),'N2'),'%') RetentionPercent
		,CAST(ISNULL(sc.RetentionAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) RetentionAmount
		,IIF(CONCAT(FORMAT(ISNULL(sc.DepositPercent,0),'N0'),'%') LIKE '0.00%','0%',CONCAT(FORMAT(ISNULL(sc.DepositPercent,0),'N0'),'%')) DepositPercent
		,CAST(ISNULL(sc.DepositAmount,0)*ISNULL(sc.DocCurrencyRate,1) AS MONEY) DepositAmount
        ,CONCAT(FORMAT((ISNULL(sc.WHTdocAmount,0)*100/(ISNULL(st.Subtotal,0)-ISNULL(sc.SpecialDiscountDocAmount,0))),'N2'),'%') WHTPercent
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



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT  vo.Id DocId
        ,vo.Code DocCode
		,FORMAT(vo.Date,'dd/MM/yyyy') DocDate
		,vo.SubContractCode
		,FORMAT(vo.SubContractDate,'dd/MM/yyyy') SubContractDate
		,o.Id LocationId
		,o.Code LocationCode
		,o.Name LocationName
		,o.Address LocationAddress
		,vo.Remarks
		,vo.CreateBy
		,FORMAT(vo.CreateTimestamp,'dd/MM/yyyy HH:mm:ss') CreateTimestamp
		,'ใบเปลี่ยนแปลง  เพิ่ม/ลด งาน' HeaderTH
	    ,'VARIATION ORDER' HeaderEN
		,FORMAT(vo.DateStart,'dd/MM/yyyy') DueDateStart
		,FORMAT(vo.DateEnd,'dd/MM/yyyy') DueDateEnd
		,CONCAT(FORMAT(vo.DateStart,'dd/MM/yyyy'),' - ',FORMAT(vo.DateEnd,'dd/MM/yyyy')) DueDate
		,ex.Id ExtOrgId
		,ex.Code ExtOrgCode
		,ex.Name ExtOrgName
		,ex.Address ExtOrgAddress
		,ex.TaxId ExtOrgTaxId
		,CASE WHEN ex.BranchCode ='00000' THEN 'สำนักงานใหญ่'
			  WHEN NULLIF(ex.BranchName,'') IS NOT NULL THEN ex.BranchName
			  ELSE ex.BranchCode END ExtOrgBranch
		,IIF(NULLIF(vo.ExtOrgContact,'') IS NULL,cp.Contract,vo.ExtOrgContact) ExtOrgContact
		,ISNULL(cp.tel,ex.Tel) ExtOrgTel
		,vo.DocCurrency
		,vo.DocCurrencyRate
		,w.Id WorkerId
		,w.Code WorkerCode
		,w.Name WorkerName
		,cd.Description DocStatus
		---------------------------------------------------------------------------------------------------------------------------------
		,CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) SubTotal
		,CASE WHEN vo.VariationOrderSpecialDiscount LIKE ('%[%]') 
			  THEN CAST(vo.VariationOrderSpecialDiscountDocAmount AS MONEY)
			  ELSE vo.VariationOrderSpecialDiscount
		 END [SpecialDiscount]
		,CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY) SpecialDiscountDocAmount
		,(CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)) BeforeTax
		,/* (
			CASE WHEN scl.SystemCategoryId = 129 THEN ( CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) )  *100/107
		ELSE
		CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)
		  - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) END
		  ) */(CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)) TaxBase
		,CONCAT('7','%') TaxRate
		--,CAST(
		--       CASE WHEN vl.VoSystemCategoryId = 123 
		--			THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*7/100) /*Exclude VAT*/
		--            WHEN vl.VoSystemCategoryId = 129 
		--			THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)/100) /*Include VAT*/
		--            ELSE 0 END
		--     AS MONEY) TaxAmount
		,CAST((ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1)- ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1))
				+ (ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*0.07*ISNULL(vo.DocCurrencyRate,1)AS MONEY)
				 GrandTotal
			,CAST(
		       ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*0.07)
		     AS MONEY) TaxAmount
		,
			CAST(
				(CAST((ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1)- ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1))
				+ (ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*0.07*ISNULL(vo.DocCurrencyRate,1)AS MONEY)
				)
		     * ISNULL(vo.DocCurrencyRate,1) 
			 AS MONEY)
			 -
			 CAST(ISNULL(vo.AdjustDepositDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)
				-
				CAST(ISNULL(vo.AdjustRetentionDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) 
				-
				CAST(ISNULL(vo.AdjustWHTDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) 
			 GrandTotal2
		---------------------------------------------------------------------------------------------------------------------------------
		,CONCAT(FORMAT(ISNULL(vo.AdjustRetentionPercent,0),'N0'),'%') VORetentionPercent
		,CAST(ISNULL(vo.AdjustRetentionDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VORetentionDocAmount
		,CONCAT(FORMAT(ISNULL(vo.AdjustDepositPercent,0),'N0'),'%') VODepositPercent
		,CAST(ISNULL(vo.AdjustDepositDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VODepositDocAmount
		,CONCAT(FORMAT(ISNULL(vo.AdjustWHTPercent,0),'N0'),'%') VOWHTPercent
		,CAST(ISNULL(vo.AdjustWHTDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VOWHTDocAmount
		---------------------------------------------------------------------------------------------------------------------------------
		,CAST(ISNULL(vl.VoSubTotal,0) AS MONEY) SubTotalNonFixTH
		,CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)  AS MONEY) SpecialDiscountDocAmountNonFixTH
		,(CAST(ISNULL(vl.VoSubTotal,0) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0) AS MONEY)) BeforeTaxNonFixTH
		,(CAST(ISNULL(vl.VoSubTotal,0) AS MONEY)
		  - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0) AS MONEY)
		  ) TaxBaseNonFixTH
		,CAST(
		       CASE WHEN vl.VoSystemCategoryId = 123 
					THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*7/100) /*Exclude VAT*/
		            WHEN vl.VoSystemCategoryId = 129 
					THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)/100) /*Include VAT*/
		            ELSE 0 END
		     AS MONEY) TaxAmountNonFixTH
		,CAST(((ISNULL(vl.VoSubTotal,0)
		        - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))
			    + CASE WHEN vl.VoSystemCategoryId = 123 
					        THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*7/100) /*Exclude VAT*/
		               WHEN vl.VoSystemCategoryId = 129 
					        THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)/100) /*Include VAT*/
		               ELSE 0 END )
			 AS MONEY) GrandTotalNonFixTH
		---------------------------------------------------------------------------------------------------------------------------------
		,CONCAT(FORMAT(ISNULL(vo.AdjustRetentionPercent,0),'N0'),'%') VORetentionPercent
		,CAST(ISNULL(vo.AdjustRetentionDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VORetentionDocAmount
		,CONCAT(FORMAT(ISNULL(vo.AdjustDepositPercent,0),'N0'),'%') VODepositPercent
		,CAST(ISNULL(vo.AdjustDepositDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VODepositDocAmount
		,CONCAT(FORMAT(ISNULL(vo.AdjustWHTPercent,0),'N0'),'%') VOWHTPercent
		,CAST(ISNULL(vo.AdjustWHTDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) VOWHTDocAmount
		---------------------------------------------------------------------------------------------------------------------------------
		,ISNULL(vs.SCSub,0) SCSubTotal
		,CAST(ISNULL(sc.SpecialDiscountDocAmount,0) AS MONEY)SCSpecialDiscount
		,ISNULL(sc.DepositAmount,0) SCDeposit
		,ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) SCNetAmount
		,(ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0))  *0.07 SCTaxAmount
		,ISNULL(sc.RetentionAmount,0) SCRetentionAmount
		,ISNULL(sc.WHTAmount,0) SCWHTAmount 
		,(ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0)) + ((ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0))  *0.07)
		-ISNULL(sc.DepositAmount,0)-ISNULL(sc.RetentionAmount,0)-ISNULL(sc.WHTAmount,0)
		SCGrandtotal
		,(
		CASE
			WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END
		)
		+
		(
				CASE
			WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END * ISNULL(scl.taxrate,0)/100 
		
		)
		
		- ISNULL(sc.DepositAmount,0)
		-ISNULL(sc.RetentionAmount,0) 
		-ISNULL(sc.WHTAmount,0) SCGrandtotal2
		---------------------------------------------------------------------------------------------------------------------------------
		,ISNULL(vs.SCSub,0) + CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) AdjustSubAmount
		,ISNULL(sc.SpecialDiscountDocAmount,0) + ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0) AdjustDiscountAmount
		,ISNULL(sc.DepositAmount,0) + CAST(ISNULL(vo.AdjustDepositDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) AdjustDepAmount
		,(
		CASE
			WHEN scl.SystemCategoryId = 129 THEN ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END 
		)
		+
		(
		CASE WHEN scl.SystemCategoryId = 129 THEN ( CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) )  *100/107
		ELSE
		CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)
		  - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) END
		  )  AdjustNetAmount
		, (
			CASE
			WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END * ISNULL(scl.taxrate,0)/100
		
			) 
		+
		(CAST(
		       CASE WHEN vl.VoSystemCategoryId = 123 
					THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))* ISNULL(scl.taxrate,0)/100) /*Exclude VAT*/
		            WHEN vl.VoSystemCategoryId = 129 
					THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)* ISNULL(scl.taxrate,0)/100) /*Include VAT*/
		            ELSE 0 END
		     AS MONEY)  ) AdjustTaxAmount
		,ISNULL(sc.RetentionAmount,0) + CAST(ISNULL(vo.AdjustRetentionDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) AdjustRetentionAmount
		,ISNULL(sc.WHTAmount,0)  + CAST(ISNULL(vo.AdjustWHTDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)  AdjustWHTAmount
		,(
					(
				CASE
					WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
				ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END
				)
				+
				(
						CASE
					WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
				ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END * ISNULL(scl.taxrate,0)/100 
		
				)
		  )
		
		+
		CAST(
				(
							(
						CASE WHEN scl.SystemCategoryId = 129 THEN ( CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) )  *100/107
					ELSE
					CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)
					  - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) END
					  ) 

			    + CASE WHEN vl.VoSystemCategoryId = 123 
					        THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))* ISNULL(scl.taxrate,0)/100) /*Exclude VAT*/
		               WHEN vl.VoSystemCategoryId = 129 
					        THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)* ISNULL(scl.taxrate,0)/100) /*Include VAT*/
		               ELSE 0 END 
				)
		     * ISNULL(vo.DocCurrencyRate,1) 
			 AS MONEY)
		 AdjustGrandTotal
		,
		(
		CASE
			WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END
		)
		+
		(
				CASE
			WHEN scl.SystemCategoryId = 129 THEN  ( ISNULL(vs.SCSub,0)  - ISNULL(sc.SpecialDiscountDocAmount,0) ) *100/107 
		ELSE ISNULL(vs.SCSub,0) - ISNULL(sc.SpecialDiscountDocAmount,0) END * ISNULL(scl.taxrate,0)/100 
		
		)
		+CAST(
				(
							(
						CASE WHEN scl.SystemCategoryId = 129 THEN ( CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) )  *100/107
					ELSE
					CAST(ISNULL(vl.VoSubTotal,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY)
					  - CAST(ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY) END
					  ) 

			    + CASE WHEN vl.VoSystemCategoryId = 123 
					        THEN ((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))* ISNULL(scl.taxrate,0)/100) /*Exclude VAT*/
		               WHEN vl.VoSystemCategoryId = 129 
					        THEN (((ISNULL(vl.VoSubTotal,0) - ISNULL(vo.VariationOrderSpecialDiscountDocAmount,0))*100/107)* ISNULL(scl.taxrate,0)/100) /*Include VAT*/
		               ELSE 0 END 
				)
		     * ISNULL(vo.DocCurrencyRate,1) 
			 AS MONEY) 
		-(ISNULL(sc.DepositAmount,0) + CAST(ISNULL(vo.AdjustDepositDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY))
		-(ISNULL(sc.WHTAmount,0)  + CAST(ISNULL(vo.AdjustWHTDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY))
		-(ISNULL(sc.RetentionAmount,0) + CAST(ISNULL(vo.AdjustRetentionDocAmount,0)*ISNULL(vo.DocCurrencyRate,1) AS MONEY))
		AdjustGrandTotal2

FROM	dbo.VariationOrders vo WITH (NOLOCK)
		LEFT JOIN dbo.ExtOrganizations ex WITH (NOLOCK) ON vo.ExtOrgId = ex.Id
		LEFT JOIN #RESubcontracts sc ON sc.Id = vo.SubContractId
		LEFT JOIN (
            select SubContractId,SUM(SubTotal) SubTotal
            from (select SubContractId,parent,ROUND(SUM(docqty*(UnitPrice*100/107))-SUM(DiscountAmount),2) SubTotal  
            from SubContractLines 
            where Path IS NOT NULL AND Parent IS NOT NULL AND SubContractId = @DocId group by SubContractId,parent) a group by SubContractId
            ) st ON st.SubContractId = sc.Id
		LEFT JOIN Subcontractlines scl ON scl.subcontractid = sc.id AND scl.systemcategoryid IN (123,129)
		LEFT JOIN (SELECT cp.ExtOrganizationId
		                  ,IIF(dbo.GROUP_CONCAT_D(DISTINCT CONCAT(cp.Name,' (Tel.',cp.Tel,')'),N', ') NOT IN ('',',',', ',' (Tel.)'),dbo.GROUP_CONCAT_D(DISTINCT CONCAT(cp.Name,' (Tel.',cp.Tel,')'),N', '),'') [Contract]  
						  ,tel
		           FROM dbo.ContactPersons cp WITH (NOLOCK)
				   GROUP BY cp.ExtOrganizationId,tel
				   ) cp ON cp.ExtOrganizationId = ex.Id		
		LEFT JOIN dbo.Organizations o WITH (NOLOCK) ON o.Id = vo.LocationId
		LEFT JOIN dbo.Workers w WITH (NOLOCK) ON w.Id = vo.WorkerId
		LEFT JOIN dbo.CodeDescriptions cd WITH (NOLOCK) ON cd.Name = 'DocStatus' AND cd.Value = vo.DocStatus
		LEFT JOIN (SELECT vl.VariationOrderId /* (AdjustDocLineAmount + AdjustDiscountDocLineAmount)*100/107 */
		                  ,SUM(IIF(vl.SystemCategoryId IN (99,100,105),(ISNULL(vl.AdjustDocLineAmount+vl.AdjustDiscountDocLineAmount,0)*100/107)-ISNULL(vl.AdjustDiscountDocLineAmount,0),0)) VoSubTotal
						  ,MAX(IIF(vl.SystemCategoryId IN (123,129,131,199,207),ISNULL(vl.TaxRate,0),0)) VoTaxRate
						  ,MAX(IIF(vl.SystemCategoryId IN (123,129,131,199,207),vl.SystemCategoryId,0)) VoSystemCategoryId
		           FROM dbo.VariationOrderLines vl WITH (NOLOCK)
				        INNER JOIN dbo.VariationOrders vo WITH (NOLOCK) ON vo.Id = vl.VariationOrderId
				   WHERE vl.SystemCategoryId IN (99,100,105,123,129,131,199,207)
				   GROUP BY vl.VariationOrderId
				  ) vl ON vl.VariationOrderId = vo.Id
		LEFT JOIN (
					SELECT SUM(SCqty*(UnitPrice*100/107))-SUM(SCDiscountDocLineAmount) SCSub,VariationOrderId 
					FROM VariationOrderLines
					WHERE VariationOrderId =@DocId and IsParent = 0  AND ISNULL(RefDocTypeId,0) NOT IN (76,0)
					GROUP BY VariationOrderId
					) vs ON vs.VariationOrderId =vo.id
WHERE	vo.Id = @DocId

/* 2-Line */

SELECT vol.Code
       ,vol.LineNumber
	   ,vol.SystemCategory
	   ,vol.SystemCategoryId
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',ic.Code) ItemCategoryCode
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',ic.Name) ItemCategoryName
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',im.Code) ItemMetaCode
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',im.Name) ItemMetaName
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',IIF(im.Code IS NULL,ic.Code,im.Code)) ItemCode
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',IIF(im.Code IS NULL,ic.Name,im.Name)) ItemName
	   ,IIF(vol.SystemCategoryId IN (-2,-3),'',vol.ClearMethodName) ClearMethodName
	   ,vol.Description
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',vol.DocUnitName) DocUnitName
	   ----------------------------------------------------------------------------------------------------------------
	   ,CASE WHEN ISNULL(vol.RefDocId,0) = 0 OR  vol.RefDocId = 756  THEN NULL
		ELSE IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.SCQTY,0)) END SCQTY
	   ,CASE WHEN ISNULL(vol.RefDocId,0) = 0 OR  vol.RefDocId = 756  THEN NULL
		ELSE IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST((((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.SCQTY,0))-ISNULL(vol.SCDiscountDocLineAmount,0)) / NULLIF(ISNULL(vol.SCQTY,0),0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) END SCUnitPrice
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.SCDiscountDocLineAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) SCDiscountAmount
	   ,CASE WHEN ISNULL(vol.RefDocId,0) = 0 OR  vol.RefDocId = 756  THEN NULL
	    ELSE IIF(vol.SystemCategoryId IN (0,-2,-3),(ISNULL(mr.SCAmount,0)-ISNULL(mr.SCDiscount,0))*ISNULL(vo.DocCurrencyRate,1),CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.SCQTY,0))-ISNULL(vol.SCDiscountDocLineAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) END SCAmount
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.DocQty,0)) DocQty
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.UnitPrice*100/107,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) UnitPrice
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',vol.Discount) Discount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.DiscountDocLineAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) DiscountAmount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),ISNULL(mr.Amount,0)* ISNULL(vo.DocCurrencyRate,1),CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) Amount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,vol.CalcVat) CalcVat
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.UnitCost,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) UnitCost
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.CostAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) CostAmount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)-ISNULL(vol.SpecialDiscountAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) TaxBase
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),'',CONCAT('7','%')) TaxRate
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)-ISNULL(vol.SpecialDiscountAmount,0))*0.07 * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) TaxAmount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.SpecialDiscountAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) SpecialDiscountAmount
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.AdjustQTY,0)) VOQTY /* (SUM(AdjustDocLineAmount + AdjustDiscountDocLineAmount)*100/107)-SUM(AdjustDiscountDocLineAmount) */
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.AdjustDiscountDocLineAmount,0) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) VODiscountAmount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),ISNULL(mr.AdjAmount-mr.AdjDiscount,0)*ISNULL(vo.DocCurrencyRate,1),CAST((ISNULL((vol.AdjustDocLineAmount + vol.AdjustDiscountDocLineAmount)*100/107,0)-vol.AdjustDiscountDocLineAmount) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) VOAmount
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST((((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.SCQTY,0))-ISNULL(vol.SCDiscountDocLineAmount,0)) / NULLIF(ISNULL(vol.SCQTY,0),0)) AS MONEY)) SCUnitPriceNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.SCDiscountDocLineAmount,0) AS MONEY)) SCDiscountAmount
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),mr.SCAmount,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.SCQTY,0))-ISNULL(vol.SCDiscountDocLineAmount,0)) AS MONEY)) SCAmountNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.UnitPrice*100/107,0) AS MONEY)) UnitPriceNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.DiscountDocLineAmount,0) AS MONEY)) DiscountAmountNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),ISNULL(mr.Amount,0),CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)) AS MONEY)) AmountNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.UnitCost,0) AS MONEY)) UnitCostNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.CostAmount,0) AS MONEY)) CostAmountNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)-ISNULL(vol.SpecialDiscountAmount,0)) AS MONEY)) TaxBaseNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.DocQty,0))-ISNULL(vol.DiscountDocLineAmount,0)-ISNULL(vol.SpecialDiscountAmount,0))*0.07 AS MONEY)) TaxAmountNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.SpecialDiscountAmount,0) AS MONEY)) SpecialDiscountAmountNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,CAST(ISNULL(vol.AdjustDiscountDocLineAmount,0) AS MONEY)) VODiscountAmountNonFixTH
	   ,IIF(vol.SystemCategoryId IN (0,-2,-3),ISNULL(mr.AdjAmount-mr.AdjDiscount,0),CAST((ISNULL((vol.AdjustDocLineAmount + vol.AdjustDiscountDocLineAmount)*100/107,0)-vol.AdjustDiscountDocLineAmount) AS MONEY)) VOAmountNonFixTH
	   ----------------------------------------------------------------------------------------------------------------
	   ,CASE WHEN ISNULL(vol.RefDocId,0) = 0 OR  vol.RefDocId = 756  THEN IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.AdjustQTY,0))
		ELSE IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.SCQTY,0))  +IIF(vol.SystemCategoryId IN (0,-2,-3),NULL,ISNULL(vol.AdjustQTY,0)) END AdjustQTY
	   ,CASE WHEN ISNULL(vol.RefDocId,0) = 0 OR  vol.RefDocId = 756  THEN IIF(vol.SystemCategoryId IN (-2,-3),NULL,CAST(((ISNULL(AdjustDocLineAmount + AdjustDiscountDocLineAmount,0)*100/107)-ISNULL(AdjustDiscountDocLineAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY))
	    ELSE IIF(vol.SystemCategoryId IN (0,-2,-3),mr.SCAmount-mr.SCDiscount,CAST(((ISNULL(vol.UnitPrice*100/107,0)*ISNULL(vol.SCQTY,0))-ISNULL(vol.SCDiscountDocLineAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) 
		+ IIF(vol.SystemCategoryId IN (0,-2,-3),mr.AdjAmount-mr.AdjDiscount,CAST(((ISNULL(AdjustDocLineAmount + AdjustDiscountDocLineAmount,0)*100/107)-ISNULL(AdjustDiscountDocLineAmount,0)) * ISNULL(vo.DocCurrencyRate,1) AS MONEY)) END AdjustAmount
	   ,vol.RefDocId


FROM dbo.VariationOrderLines vol WITH (NOLOCK)
	LEFT JOIN dbo.ItemCategories ic WITH (NOLOCK) ON ic.Id = vol.ItemCategoryId
	LEFT JOIN dbo.ItemMetas im WITH (NOLOCK) ON im.Id = vol.ItemMetaId
	INNER JOIN dbo.VariationOrders vo WITH (NOLOCK) ON vo.Id = vol.VariationOrderId
	    LEFT JOIN (
select parent,SUM(SCqty*(UnitPrice*100/107)) SCAmount, SUM(SCDiscountDocLineAmount) SCDiscount, SUM((ISNULL(UnitPrice*100/107,0)*ISNULL(DocQty,0))-ISNULL(DiscountDocLineAmount,0)) Amount
				,(SUM(AdjustDocLineAmount + AdjustDiscountDocLineAmount)*100/107) AdjAmount ,SUM(AdjustDiscountDocLineAmount) AdjDiscount
				from VariationOrderLines where  parent IS NOT NULL AND VariationOrderId = @DocId group by Parent
    ) mr ON mr.parent = vol.Code
WHERE vol.VariationOrderId = @DocId
      AND vol.SystemCategoryId NOT IN (123,129,131,199,207)

ORDER BY vol.LineNumber
/* col ที่ต้อง *100/107 : AdjustDocLineAmount
ต้องเอา adjustdoclineAmount + adjustDiscountDoclineAmount เเล้วค่อยคูณ 100/107
 */

/*3-Other*/
-----------------------------------------------------------------------------------------------------------------------------------------------
SELECT '3-Other' TableMappingName;

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
-- Drop the table if it already exists
IF OBJECT_ID('tempDB..#RESubcontracts', 'U') IS NOT NULL
DROP TABLE #RESubcontracts