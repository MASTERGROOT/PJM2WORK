/*==> Ref:d:\programmanee\prototype-ss\notpublish\customprinting\documentcommands\test_customdocform.sql ==>*/
DECLARE @p0 INT = 3

DECLARE @DocId INT = @p0;
DECLARE @DocTypeId INT = 240;
DECLARE @DocGuid NVARCHAR(100);

SELECT @DocGuid = guid 
FROM CustomDocuments 
WHERE Id = @DocId;

WITH InterimPaymentData AS (
    SELECT 
        ip.Id AS InterimPaymentId,
        ip.Code AS InterimPaymentCode,
        ip.PloyUnitId,
        ip.ExtOrgId,
        ip.REUnitId,
        (
            SELECT DataValues 
            FROM CustomNoteLines 
            WHERE DocGuid = @DocGuid AND KeyName = 'InterimCode'
        ) AS InterimCode
        ,ip.OrgId
    FROM InterimPayments ip
    WHERE ip.Code = (
        SELECT DataValues 
        FROM CustomNoteLines 
        WHERE DocGuid = @DocGuid AND KeyName = 'InterimCode'
    )
),
InterimPaymentLinesData AS (
    SELECT TOP (1) 
        PloyQuotationLineId,
        InterimPaymentId
    FROM InterimPaymentLines
    WHERE InterimPaymentId = (SELECT InterimPaymentId FROM InterimPaymentData)
    ORDER BY Id DESC
),
RealEstateUnitData AS (
    SELECT
        Code,
        Id,
        Code + ' : ' + Name [DisplayUnit]
    FROM RealEstateUnits
    WHERE Id = (SELECT REUnitId FROM InterimPaymentData)
),
ExtOrgData AS (
    SELECT
        extorg.Id AS ExtOrgId,
        extorg.Name,
        extorg.Tel,
        extorg.guid,
        extorg.TaxId
    FROM ExtOrganizations extorg
    WHERE extorg.Id = (SELECT ExtOrgId FROM InterimPaymentData)
),
BankData AS (
    SELECT 
    TOP(1)
    pba.BankCode,
    b.LocalBankName
	,pba.AcctNumber
    FROM PayeeBankAccts pba
    LEFT JOIN Banks b on b.LocalBankCode = pba.BankCode
    WHERE pba.PayeeTypeId = 6 AND pba.PayeeId = (select ExtOrgId from ExtOrgData)
),
OrgData AS(
    SELECT
        guid
    FROM Organizations org
    WHERE org.Id = (SELECT OrgId FROM InterimPaymentData)
),
CustomNoteData AS (
    -- SELECT 
    --     KeyName,
    --     DataValues
    -- FROM CustomNoteLines
    -- WHERE DocGuid = @DocGuid -- docGuid
    -- OR
    -- DocGuid = (select guid FROM ExtOrgData)
    select *
    from
    (
        select IIF(DataValues = '',Null,DataValues) DataValues, KeyName
        from dbo.CustomNoteLines
        WHERE DocGuid = @DocGuid --customdoc
        or DocGuid = (select guid from ExtOrgData) --extorg
        or DocGuid = (select guid from OrgData) --org
    ) d
    pivot
    (
        max(DataValues)
        for KeyName in (
            Project_titledeed_No
            ,Building_No
            ,Subdistrict_Titledeed
            ,Building_Name
            ,District_Titledeed
            ,Condo_RegistrationNo
            ,Project_Province
            ,Buyer_RepresentativeName
            ,Buyer_Age
            ,Buyer_Nationality
            ,Buyer_Race
            ,Buyer_Parents_Name
            ,Buyer_Status
            ,Buyer_Spouse_Name
            ,Buyer_spouse_Nationality
            ,Buyer_VillageName
            ,Buyer_HouseNo
            ,Buyer_Alley
            ,Buyer_Street
            ,Buyer_Moo
            ,Buyer_Subdistrict
            ,Buyer_District
            ,Buyer_Province
            ,Buyer2Name
            ,Buyer2IDNo
            ,Buyer2_Age
            ,Buyer2_Nationality
            ,Buyer2_Race
            ,Buyer2_Parents_Name
            ,Buyer2_Status
            ,Buyer2_Spouse_Name
            ,Buyer2_spouse_Nationality
            ,Buyer2_VillageName
            ,Buyer2_HouseNo
            ,Buyer2_Alley
            ,Buyer2_Street
            ,Buyer2_Moo
            ,Buyer2_Subdistrict
            ,Buyer2_District
            ,Buyer2_Province
            ,Buyer2Tel
            ,[Price_LegalTransactions(Baht)]
            ,[Price_LegalTransactions(Satang)]
            ,Date
            ,Month
            ,Year
            --Improve
            ,Dated_Signed_Seller
            ,Dated_Signed_Buyer
            --End Improve
            ,[Capital_Appraisal_Price(Baht)]
            ,[Capital_Appraisal price (satang)]
            ,Unit_Area
            ,Unit_price_appraised_per_sqm
            ,Area_other_personal
            ,BalconyArea_price_sqm
            ,Sale_ContractNo
            ,[Electricity meter insurance]
            ,Check_pay_Preeda_amt
            ,Check_pay_Thachawan_amt
            ,Additional_Pay
            ,Transfer_Fee
            ,Mortgage_Costs
            ,Property_Appraisal_Cost
            ,Fund_per_Sqmtr
            ,Common_expenses_per_Sqm
            ,Months_CommonExpenses_Advance
            ,Employee_ForTransfer
            ,LandOffice_Branch
            ,Other_Personal_Property
            ,Inspection_Doc_No
            ,Date_Inspection_Doc
            ,SalesUnit_No
            ,Date_Transfer
            --Improve
            ,Seller_RepresentativeName
            ,Date_Contract
            ,Transfer_AtPlace
			,Transfer_AtPlace2
            ,Garuntee_Transfer
            ,Parcel_No
            ,[Capital_Appraisal2_Price(Baht)]
            ,Alien_AreaRatio
            ,Transfer_Officer
            ,LandDepartment_fees
            ,[In-DecreaseArea]
            ,[In-DeacreaseAreaBaht]
            ,[DiscountPrice]
			,[FreeElectricMeter]
			,[MortgageAmount]
			,[BankMortgage]
			,[RateMortgageFee]
        )
    ) piv
),
REUnitsPloyData AS(
    SELECT 
    rep.Id as PloyUnitId,
    rep.AddressNo [f2],
    JSON_VALUE(rep.LandInfo, '$.SpaceAreaOnTitleDeed')[f10],
    (LandArea - JSON_VALUE(rep.LandInfo, '$.SpaceAreaOnTitleDeed')) [f70],
    JSON_VALUE(rep.UnitInfo2, '$.CPLA') [f71],
    pp.FloorArea [FloorArea],
    qp.price,
    qp.discount,
    bap.BankThaiName,
    bap.BankHomeLoanAmount
    FROM [dbo].[REUnitsPloy] rep
    LEFT JOIN [dbo].[PlansPloy] pp on PlanId = pp.id
    LEFT JOIN [dbo].[QuotationsPloy] qp ON qp.REUnitId = rep.Id
    OUTER APPLY (
            select 	b.ThaiName AS BankThaiName
                    ,ba.HomeLoanAmount AS BankHomeLoanAmount
            from dbo.BankApplicationsPloy ba left join BanksPloy b on b.Id = ba.BankId 
            where (ba.CustomerLoanId = (select Id from CustomerLoansPloy Where REUnitId = rep.Id AND Status = 1 AND CustomerId = (select Customer from QuotationsPloy where REUnitId = rep.Id and status > 1)))
        )bap
    WHERE rep.Id = (SELECT PloyUnitId FROM InterimPaymentData)
)
-- Main SELECT query
SELECT 
    ipd.InterimPaymentId                                [InterrimPaymentId]
    ,ExtOrg.guid                                        [extorgid]
    ,ipd.InterimPaymentCode                             [InterrimPaymentCode]
    ,ipd.PloyUnitId                                     [PloyUnitId]
    ,ipl.PloyQuotationLineId                            [PloyQuotationLineId]
    ,cnd.[Project_titledeed_No]
    ,reploy.f2                                          [Unit_Address_No]
    ,reploy.FloorArea                                   [Floor_No]
    ,cnd.[Building_No]  --f4
    ,cnd.[Subdistrict_Titledeed]  --f5
    ,cnd.[Building_Name]  --f6
    ,cnd.[District_Titledeed]  --f7
    ,cnd.[Condo_RegistrationNo]  --f8
    ,cnd.[Project_Province]  --f9
    ,reploy.f10                                         [Estimate_Area]
    ,IIF(cnd.Buyer2Name IS NULL,extorg.Name,NULL) [Buyer_Name]  --f29
    ,IIF(cnd.Buyer2Name IS NOT NULL,CONCAT('1.',extorg.Name,CHAR(10),'2.',cnd.Buyer2Name),NULL) [TwoBuyer_Name]
    ,IIF(cnd.Buyer2Name IS NOT NULL,'1 และ 2',NULL) NumPerson
	,IIF(cnd.[Buyer_Status]='หม้าย',extorg.Name,NULL)		[Buyer_Name_Status]
    ,IIF(cnd.Buyer2Name IS NULL,extorg.TaxId,NULL) [Buyer_ID_No] --f30
    ,IIF(cnd.Buyer2Name IS NOT NULL,CONCAT(extorg.TaxId,CHAR(10),cnd.Buyer2IDNo),NULL) [TwoBuyer_TaxId]
    ,IIF(cnd.Buyer2Name IS NOT NULL,CONCAT(extorg.TaxId,',',cnd.Buyer2IDNo),NULL) [TwoBuyer_TaxId_Horizontal]
    ,cnd.[Buyer_RepresentativeName]  --f31
    ,CASE WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Age,'-'),',',COALESCE(cnd.Buyer2_Age,'-'))
    ELSE COALESCE(cnd.Buyer_Age,'-')
    END
    [Buyer_Age]  --f32
    ,CASE WHEN (cnd.Buyer_Nationality = cnd.Buyer2_Nationality ) THEN COALESCE(cnd.Buyer_Nationality,Buyer2_Nationality)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Nationality,'-'),',',COALESCE(cnd.Buyer2_Nationality,'-'))
    ELSE COALESCE(cnd.Buyer_Nationality,'-')
    END
    [Buyer_Nationality]  --f33
    ,CASE WHEN (cnd.Buyer_Race = cnd.Buyer2_Race ) THEN COALESCE(cnd.Buyer_Race,Buyer2_Race,'-')
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Race,'-'),',',COALESCE(cnd.Buyer2_Race,'-'))
    ELSE COALESCE(cnd.Buyer_Race,'-')
    END
    [Buyer_Race]  --f34
    ,CASE /* WHEN (cnd.Buyer_Parents_Name = cnd.Buyer2_Parents_Name) THEN CONCAT(COALESCE(cnd.Buyer_Parents_Name,'-'),',',COALESCE(cnd.Buyer2_Parents_Name,'-')) */
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Parents_Name,'-'),',',COALESCE(cnd.Buyer2_Parents_Name,'-'))
    ELSE COALESCE(cnd.Buyer_Parents_Name,'-')
    END
    [Buyer_Parents_Name]  --f35
    ,cnd.[Buyer_Status]  --f36
    ,CASE /* WHEN (cnd.Buyer_Parents_Name = cnd.Buyer2_Parents_Name) THEN CONCAT(COALESCE(cnd.Buyer_Parents_Name,'-'),',',COALESCE(cnd.Buyer2_Parents_Name,'-')) */
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Parents_Name,'-'),',',COALESCE(cnd.Buyer2_Parents_Name,'-'))
    ELSE COALESCE(cnd.Buyer_Parents_Name,'-')
    END
    [Buyer_Spouse_Name]  --f37
    ,CASE WHEN (cnd.Buyer_spouse_Nationality = cnd.Buyer2_spouse_Nationality ) THEN COALESCE(cnd.Buyer_spouse_Nationality,Buyer2_spouse_Nationality)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_spouse_Nationality,'-'),',',COALESCE(cnd.Buyer2_spouse_Nationality,'-'))
    ELSE COALESCE(cnd.Buyer_spouse_Nationality,'-')
    END
    [Buyer_spouse_Nationality]  --f38
    ,CASE WHEN (cnd.Buyer_VillageName = cnd.Buyer2_VillageName ) THEN COALESCE(cnd.Buyer_VillageName,Buyer2_VillageName)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_VillageName,'-'),',',COALESCE(cnd.Buyer2_VillageName,'-'))
    ELSE COALESCE(cnd.Buyer_VillageName,'-')
    END
    [Buyer_VillageName]  --f39
    ,CASE WHEN (cnd.Buyer_HouseNo = cnd.Buyer2_HouseNo ) THEN COALESCE(cnd.Buyer_HouseNo,Buyer2_HouseNo)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_HouseNo,'-'),',',COALESCE(cnd.Buyer2_HouseNo,'-'))
    ELSE COALESCE(cnd.Buyer_HouseNo,'-')
    END
    [Buyer_HouseNo]  --f40
    ,CASE WHEN (cnd.Buyer_Alley = cnd.Buyer2_Alley ) THEN COALESCE(cnd.Buyer_Alley,Buyer2_Alley)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Alley,'-'),',',COALESCE(cnd.Buyer2_Alley,'-'))
    ELSE COALESCE(cnd.Buyer_Alley,'-')
    END
    [Buyer_Alley]  --f41
    ,CASE WHEN (cnd.Buyer_Street = cnd.Buyer2_Street ) THEN COALESCE(cnd.Buyer_Street,Buyer2_Street)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Street,'-'),',',COALESCE(cnd.Buyer2_Street,'-'))
    ELSE COALESCE(cnd.Buyer_Street,'-')
    END
    [Buyer_Street]  --f42
    ,CASE WHEN (cnd.Buyer_Moo = cnd.Buyer2_Moo ) THEN COALESCE(cnd.Buyer_Moo,Buyer2_Moo)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Moo,'-'),',',COALESCE(cnd.Buyer2_Moo,'-'))
    ELSE COALESCE(cnd.Buyer_Moo,'-')
    END
    [Buyer_Moo]  --f43
    ,CASE WHEN (cnd.Buyer_Subdistrict = cnd.Buyer2_Subdistrict ) THEN COALESCE(cnd.Buyer_Subdistrict,Buyer2_Subdistrict)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Subdistrict,'-'),',',COALESCE(cnd.Buyer2_Subdistrict,'-'))
    ELSE COALESCE(cnd.Buyer_Subdistrict,'-')
    END
    [Buyer_Subdistrict]  --f44
    ,CASE WHEN (cnd.Buyer_District = cnd.Buyer2_District ) THEN COALESCE(cnd.Buyer_District,Buyer2_District)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_District,'-'),',',COALESCE(cnd.Buyer2_District,'-'))
    ELSE COALESCE(cnd.Buyer_District,'-')
    END
    [Buyer_District]  --f45
    ,CASE WHEN (cnd.Buyer_Province = cnd.Buyer2_Province ) THEN COALESCE(cnd.Buyer_Province,Buyer2_Province)
            WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(cnd.Buyer_Province,'-'),',',COALESCE(cnd.Buyer2_Province,'-'))
    ELSE COALESCE(cnd.Buyer_Province,'-')
    END
    [Buyer_Province]  --f46

    /* buyer 2 */
	-- ,CONCAT('2.',cnd.Buyer2Name) Buyer2Name
	-- ,cnd.Buyer2IDNo
	-- ,cnd.Buyer2_Age
	-- ,cnd.Buyer2_Nationality
	-- ,cnd.Buyer2_Race
	-- ,cnd.Buyer2_Parents_Name
	,cnd.Buyer2_Status
	-- ,cnd.Buyer2_Spouse_Name
	-- ,cnd.Buyer2_spouse_Nationality
	-- ,cnd.Buyer2_VillageName
	-- ,cnd.Buyer2_HouseNo
	-- ,cnd.Buyer2_Alley
	-- ,cnd.Buyer2_Street
	-- ,cnd.Buyer2_Moo
	-- ,cnd.Buyer2_Subdistrict
	-- ,cnd.Buyer2_District
	-- ,cnd.Buyer2_Province
    /* end buyer 2 */
    ,CASE WHEN cnd.Buyer2Name IS NOT NULL THEN CONCAT(COALESCE(extorg.Tel,'-'),',',COALESCE(cnd.Buyer2Tel,'-'))
    ELSE COALESCE(extorg.Tel,'-')
    END
    [Buyer_Phone]
    ,CAST(cnd.[Price_LegalTransactions(Baht)] AS INT)  [Price_LegalTransactions(Baht)]--f48
    ,IIF(CAST(cnd.[Price_LegalTransactions(Satang)] AS INT) != 0 ,CAST(cnd.[Price_LegalTransactions(Satang)] AS INT),NULL) [Price_LegalTransactions(Satang)]  --f49
    ,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(CONCAT(cnd.[Price_LegalTransactions(Baht)],'.',cnd.[Price_LegalTransactions(Satang)]) AS VARCHAR(50)),'0', '๐'),'1', '๑'),'2', '๒'),'3', '๓'),'4', '๔'),'5', '๕'),'6', '๖'),'7', '๗'),'8', '๘'),'9', '๙')                             [Price_LegalTransactions(Text)]
    ,cnd.[Date]  --f51
    ,cnd.[Month]  --f52
    ,cnd.[Year]  --f53
    --Improve
    -- ,cnd.[Dated_Signed_Seller]  --f54
    -- ,cnd.[Dated_Signed_Buyer]  --f55
    ,IIF(LEN(Dated_Signed_Seller) = 10, 
       CONCAT(
           SUBSTRING(Dated_Signed_Seller, 1, 6), 
           CAST(SUBSTRING(Dated_Signed_Seller, 7, 4) AS INT) + 543
       ), 
       NULL
    ) [Dated_Signed_Seller]
    ,IIF(LEN(Dated_Signed_Buyer) = 10, 
       CONCAT(
           SUBSTRING(Dated_Signed_Buyer, 1, 6), 
           CAST(SUBSTRING(Dated_Signed_Buyer, 7, 4) AS INT) + 543
       ), 
       NULL
    ) [Dated_Signed_Buyer]
    --End Improve
    ,CAST(cnd.[Capital_Appraisal_Price(Baht)] AS INT)   [Capital_Appraisal_Price(Baht)]--f56
    ,IIF(CAST(cnd.[Capital_Appraisal price (satang)] AS INT) != 0 ,CAST(cnd.[Capital_Appraisal price (satang)] AS INT),NULL) [Capital_Appraisal price (satang)]  --f57
    ,f58.[DataValues] [SellerID_No]  --f58
    ,CAST(cnd.[Unit_Area] AS MONEY) [Unit_Area]  --f59
    ,cnd.[Unit_price_appraised_per_sqm]  --f60
    ,CONVERT(decimal,cnd.[Unit_Area]) * CONVERT(decimal,cnd.[Unit_price_appraised_per_sqm])                             [Total_Unit_Appraised_Price] --61
    ,CAST(cnd.[Area_other_personal] AS MONEY) [Area_other_personal]  --f62
    ,cnd.[BalconyArea_price_sqm]  --f63
    ,(CONVERT(decimal,cnd.[Area_other_personal]) * CONVERT(decimal,cnd.[BalconyArea_price_sqm]))                             [Total_Balcony_Appraised_Price] --64
    ,(CONVERT(decimal,CONVERT(decimal,cnd.[Unit_Area]) * CONVERT(decimal,cnd.[Unit_price_appraised_per_sqm])) + CONVERT(decimal,(CONVERT(decimal,cnd.[Area_other_personal]) * CONVERT(decimal,cnd.[BalconyArea_price_sqm])))) [AppraisedPrice_Registration] --65                        
    ,cnd.[Sale_ContractNo]  --f66
    ,reploy.BankThaiName                                [Bank_Loan]
    ,reploy.price                                       [Selling price]
    ,reploy.discount                                    [discount]
    ,reploy.f70                                         [Indecrease_Area]
    ,reploy.f71                                         [Price_in/decrease_per_sqm]
    ,ISNULL(CAST(f72.[DataValues] AS decimal),0)                  [Deduct_paided]  --f72
    ,IIF(cnd.FreeElectricMeter Like '%ฟรี เงินประกันมิเตอร์ไฟฟ้า%',0,CAST(cnd.[Electricity meter insurance] AS decimal)) [Electricity meter insurance]   --f73
    ,CAST(cnd.[Check_pay_Preeda_amt] AS decimal)        [Check_pay_Preeda_amt]--f74
    ,CAST(cnd.[Check_pay_Thachawan_amt] AS decimal)     [Check_pay_Thachawan_amt]--f75
    ,CAST(cnd.[Additional_Pay] AS decimal)              [Additional_Pay]--f76
    ,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าธรรมเนียมในการจดทะเบียนโอนกรรมสิทธิ์ห้องชุด%',0,((CAST(cnd.Unit_Area AS decimal)*CAST(cnd.[Capital_Appraisal_Price(Baht)] AS INT))
				+(CAST(cnd.[Area_other_personal] AS decimal)*CAST(cnd.[Capital_Appraisal2_Price(Baht)] AS INT)))*2/100)                [Transfer_Fee]--f77
    ,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าใช้จ่ายในการจดจำนอง%',0,CAST(cnd.MortgageAmount AS decimal)*CAST(cnd.[RateMortgageFee] AS decimal)/100)              [Mortgage_Costs]--f78
    ,CAST(cnd.[Property_Appraisal_Cost] AS decimal)     [Property_Appraisal_Cost]--f79
    ,CAST(cnd.[Fund_per_Sqmtr] AS decimal)              [Fund_per_Sqmtr]--f80
    ,CAST(cnd.[Common_expenses_per_Sqm] AS decimal)     [Common_expenses_per_Sqm]--f81
    ,CAST(cnd.[Months_CommonExpenses_Advance] AS decimal)[Months_CommonExpenses_Advance]--f82
    ,cnd.[Employee_ForTransfer]  --f83
    ,cnd.[LandOffice_Branch]  --f84
    ,cnd.[Other_Personal_Property]  --f85
    ,cnd.[Inspection_Doc_No]  --f86
    --Improve
    -- ,cnd.[Date_Inspection_Doc]  --f87
    ,IIF(LEN(Date_Inspection_Doc) = 10, 
       CONCAT(
           SUBSTRING(Date_Inspection_Doc, 1, 6), 
           CAST(SUBSTRING(Date_Inspection_Doc, 7, 4) AS INT) + 543
       ), 
       NULL
    ) [Date_Inspection_Doc]
    --End Improve
    ,reu.Code                                    [SalesUnit_No]
    ,reploy.BankHomeLoanAmount                  [TotalLoan_Am]
    --Improve 
    -- ,cnd.[Date_Transfer]  --f90
    ,cnd.Transfer_AtPlace 
	,cnd.Transfer_AtPlace2
    ,cnd.Parcel_No
    ,cnd.Garuntee_Transfer
    ,IIF(cnd.Garuntee_Transfer = 'ข้าพเจ้ามิได้รับโอนแทนบุคคลต่างด้าวหรือเพื่อ ประโยชน์แก่บุคคลต่างด้าวที่ไม่มีสิทธิถือกรรมสิทธิ์ห้องชุด',1,0) [Garuntee_Transfer_Type1]
    ,IIF(cnd.Garuntee_Transfer = 'ข้าพเจ้าเป็นบุคคลต่างด้าว ขอรับโอนห้องชุดตามสิทธิใน พ.ร.บ. อาคารชุด พ.ศ. ๒๕๒๒ มาตรา ๑๙ (๕)',1,0) [Garuntee_Transfer_Type2]
    ,IIF(LEN(Date_Transfer) = 10, 
       CONCAT(
           SUBSTRING(Date_Transfer, 1, 6), 
           CAST(SUBSTRING(Date_Transfer, 7, 4) AS INT) + 543
       ), 
       NULL
    ) [Date_Transfer]
    ,cnd.Seller_RepresentativeName 
    ,Date_Contract
    ,IIF(LEN(Date_Contract) = 10, SUBSTRING(Date_Contract, 1, 2), NULL) [Date_Contract_Day]
    ,IIF(LEN(Date_Contract) = 10, SUBSTRING(Date_Contract, 4, 2), NULL) [Date_Contract_Month]
    ,IIF(LEN(Date_Contract) = 10, CAST(CAST(SUBSTRING(Date_Contract, 7, 4) AS INT) + 543 AS VARCHAR), NULL) [Date_Contract_Year]
    ,IIF(LEN(Date_Contract) = 10, 
       CONCAT(
           SUBSTRING(Date_Contract, 1, 6), 
           CAST(SUBSTRING(Date_Contract, 7, 4) AS INT) + 543
       ), 
       NULL
    ) [Date_Contract_BE]
    ,IIF(LEN(Date_Contract) = 10, 
        CASE SUBSTRING(Date_Contract, 4, 2)
            WHEN '01' THEN 'มกราคม'
            WHEN '02' THEN 'กุมภาพันธ์'
            WHEN '03' THEN 'มีนาคม'
            WHEN '04' THEN 'เมษายน'
            WHEN '05' THEN 'พฤษภาคม'
            WHEN '06' THEN 'มิถุนายน'
            WHEN '07' THEN 'กรกฎาคม'
            WHEN '08' THEN 'สิงหาคม'
            WHEN '09' THEN 'กันยายน'
            WHEN '10' THEN 'ตุลาคม'
            WHEN '11' THEN 'พฤศจิกายน'
            WHEN '12' THEN 'ธันวาคม'
        END, NULL
    ) [Date_Contract_Month_Thai]
    ,IIF(LEN(Date_Contract) = 10, 
        SUBSTRING(Date_Contract, 1, 2) + ' ' + 
        CASE SUBSTRING(Date_Contract, 4, 2)
            WHEN '01' THEN 'มกราคม'
            WHEN '02' THEN 'กุมภาพันธ์'
            WHEN '03' THEN 'มีนาคม'
            WHEN '04' THEN 'เมษายน'
            WHEN '05' THEN 'พฤษภาคม'
            WHEN '06' THEN 'มิถุนายน'
            WHEN '07' THEN 'กรกฎาคม'
            WHEN '08' THEN 'สิงหาคม'
            WHEN '09' THEN 'กันยายน'
            WHEN '10' THEN 'ตุลาคม'
            WHEN '11' THEN 'พฤศจิกายน'
            WHEN '12' THEN 'ธันวาคม'
        END + ' ' + 
        CAST(CAST(SUBSTRING(Date_Contract, 7, 4) AS INT) + 543 AS VARCHAR), 
        NULL
    ) [Date_Contract_Full_Thai]
    ,CASE WHEN cnd.Buyer2Name IS NOT NULL THEN IIF((Buyer_Status = 'โสด' OR Buyer2_Status = 'โสด'),1,0)
    ELSE  IIF((Buyer_Status = 'โสด' ),1,0)
    END
    [Buyer_Status_Single]
    ,CASE WHEN cnd.Buyer2Name IS NOT NULL THEN IIF((Buyer_Status = 'สมรส' OR Buyer2_Status = 'สมรส' ),1,0)
    ELSE  IIF((Buyer_Status = 'สมรส'),1,0)
    END
    [Buyer_Status_Married]
    ,CASE WHEN cnd.Buyer2Name IS NOT NULL THEN IIF((Buyer_Status = 'หม้าย' OR Buyer2_Status= 'หม้าย'),1,0)
    ELSE  IIF((Buyer_Status = 'หม้าย'),1,0)
    END
    [Buyer_Status_Divorce]
    ,IIF(CAST(cnd.[Capital_Appraisal2_Price(Baht)] AS INT) != 0 ,CAST(cnd.[Capital_Appraisal2_Price(Baht)] AS INT),NULL) [Capital_Appraisal2_Price(Baht)]
    ,cnd.Alien_AreaRatio
    ,bd.LocalBankName   [Bank]
	,bd.AcctNumber		[BankAccountNumber]
    ,cnd.Transfer_Officer
    ,IIF(cnd.Transfer_Officer = 'คุณมนฤดี',1,0) [Transfer_Officer1]
    ,IIF(cnd.Transfer_Officer = 'คุณพจน์',1,0) [Transfer_Officer2]
    ,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าดำเนินการกรมที่ดิน%',0,CAST(cnd.LandDepartment_fees AS decimal)) LandDepartment_fees
    ,reu.DisplayUnit [Unit]
    ,CAST(cnd.[In-DecreaseArea] as decimal) [In-DecreaseArea]
    ,CAST(cnd.[In-DeacreaseAreaBaht] as decimal) [In-DeacreaseAreaBaht]
    ,CAST(cnd.[DiscountPrice] as decimal) [DiscountPrice]
	,IIF(cnd.FreeElectricMeter Like '%ฟรี เงินประกันมิเตอร์ไฟฟ้า%',1,0) FreeMeterElectric
	,IIF(cnd.FreeElectricMeter Like '%ฟรี เงินประกันมิเตอร์ไฟฟ้า%',CONCAT(Format(CAST(cnd.[Electricity meter insurance] AS decimal),'N2'),' บาท'),'-') FreeMeterElectricText
	,IIF(cnd.FreeElectricMeter Like '%ฟรี เงินสมทบกองทุนนิติบุคคลอาคารชุด%',1,0) FreeNiti
	,IIF(cnd.FreeElectricMeter Like '%ฟรี เงินสมทบกองทุนนิติบุคคลอาคารชุด%',CONCAT(Format(CAST(cnd.[Fund_per_Sqmtr] AS decimal)*(CAST(cnd.[Area_other_personal] AS MONEY)+CAST(cnd.[Unit_Area] AS MONEY)) ,'N2'),' บาท'),'-') FreeNitiText
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าใช้จ่ายส่วนกลาง%',1,0) FreeCoWorking
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าใช้จ่ายส่วนกลาง%',CONCAT(Format(CAST(cnd.[Electricity meter insurance] AS decimal),'N2'),' บาท'),'-') FreeCoWorkingText
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าดำเนินการกรมที่ดิน%',1,0) FreeLand
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าดำเนินการกรมที่ดิน%',CONCAT(Format(CAST(cnd.LandDepartment_fees AS decimal),'N2'),' บาท'),'-') FreeLandText
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าธรรมเนียมในการจดทะเบียนโอนกรรมสิทธิ์ห้องชุด%',1,0) FreeTranfer
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าธรรมเนียมในการจดทะเบียนโอนกรรมสิทธิ์ห้องชุด%',CONCAT(Format(((CAST(cnd.Unit_Area AS decimal)*CAST(cnd.[Capital_Appraisal_Price(Baht)] AS INT))
					+(CAST(cnd.[Area_other_personal] AS decimal)*CAST(cnd.[Capital_Appraisal2_Price(Baht)] AS INT)))*2/100,'N2'),' บาท'),'-') FreeTranferText
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าใช้จ่ายในการจดจำนอง%',1,0) FreeMortgage
	,IIF(cnd.FreeElectricMeter Like '%ฟรี ค่าใช้จ่ายในการจดจำนอง%',CONCAT(Format(CAST(cnd.MortgageAmount AS decimal)*CAST(cnd.[RateMortgageFee] AS decimal)/100,'N2'),' บาท'),'-') FreeMortgageText
	,CAST(cnd.MortgageAmount AS decimal) MortgageAmount
	,CONCAT('วงเงินสินเชื่อธนาคาร ',cnd.BankMortgage,' วงเงินที่อนุมัติ ',Format(CAST(cnd.MortgageAmount AS decimal),'N2'),' บาท') BankMortgage
	
	

FROM CustomDocuments cd
LEFT JOIN InterimPaymentData ipd ON cd.Id = @DocId
LEFT JOIN InterimPaymentLinesData ipl ON ipl.InterimPaymentId = ipd.InterimPaymentId
LEFT JOIN RealEstateUnitData reu ON reu.Id = ipd.REUnitId
LEFT JOIN REUnitsPloyData reploy ON reploy.PloyUnitId = ipd.PloyUnitId
LEFT JOIN ExtOrgData extorg ON extorg.ExtOrgId = ipd.ExtOrgId
LEFT JOIN BankData bd ON 1 = 1
LEFT JOIN CustomNoteData cnd ON 1 = 1 
OUTER APPLY (select IIF(OrgCategory in (998,999),CONVERT(NVARCHAR,taxtypeid),(select [Value] from CompanyConfigs where ConfigName = 'TaxNumber')) [DataValues] from Organizations where id in (select SUBSTRING([Path],CHARINDEX('|', [Path]) + 1,CHARINDEX('|', [Path], CHARINDEX('|', [Path]) + 1) - CHARINDEX('|', [Path]) - 1) AS rootpath from Organizations where id = ipd.OrgId))f58
OUTER APPLY (select SUM(Amount) [DataValues]
        from OtherReceiveLines
        where OtherReceiveId IN (
                            select id
                            from OtherReceives
                            where Code in (
                                              select LEFT(JSON_VALUE(OtherInfo, '$.Invoice'), PATINDEX('% %',JSON_VALUE(OtherInfo,'$.Invoice')) - 1) [OtherReceiveCode]
                                              from InterimPaymentLines
                                              where InterimPaymentId in (select Id from InterimPayments ip where ip.Code = (select DataValues from CustomNoteLines cnl where cnl.DocGuid = @DocGuid and cnl.KeyName = 'InterimCode'))
                                                    and JSON_VALUE(OtherInfo, '$.Invoice') != ''
                                          )
                        )
        and SystemCategoryId in ( 59, 58, 176 )
        GROUP BY RefDocId
    )f72
--LEFT JOIN CustomNoteLines
WHERE cd.Id = @DocId;






