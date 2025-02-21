/*==> Ref:d:\site\erppro\notpublish\customprinting\reportcommands\mtp101_summary_of_project_income_and_expenses.sql ==>*/
 
/*รายได้แต่ละโครงการ - ผู้บริหาร*/

DECLARE @p0 DATETIME = '2025-01-08'
DECLARE @p1 nvarchar(500) = '113'--'1931'--'1107,1152' --''--
DECLARE @p2 BIT = 0

DECLARE @Todate DATETIME = @p0
DECLARE @ProjectId nvarchar(500) = @p1
DECLARE @IncChild BIT = @p2

/************************************************************************************************************************************************************************/
DECLARE @OrgId TABLE (Id int not null);

INSERT INTO @OrgId(Id)     /*Save More OrgId Or Single OrgId Not Include Child to Temp.*/
            
            SELECT   distinct orgD.ChildrenId       
            FROM   dbo.fn_organizationDepends() orgD
			where (@incChild = 1 and orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)))
			or (isnull(@incChild,0) = 0 and  orgD.OrgId in (select ncode from dbo.fn_listCode(@ProjectId)) and orgD.OrgId = orgD.ChildrenId)
            

/************************************************************************************************************************************************************************/
/*#TempPORemain*/
IF OBJECT_ID(N'tempdb..#TempPORemain') IS NOT NULL
BEGIN
    DROP TABLE #TempPORemain;
END;

SELECT *
INTO #TempPORemain
FROM
(
	select po.LocationId
			,SUM(po.PORemainTaxbase) PORemainTaxbase
			,SUM(po.PORemainAmount) PORemainAmount
from (
		select po.LocationId
			,case when po.SystemCategoryId = 123 then sum(po.Notpay)
				when po.SystemCategoryId = 129 then sum(po.Notpay) * 100 / 107
				else sum(po.Notpay)
				end [PORemainTaxbase]
				,case when po.SystemCategoryId = 123 then sum(po.Notpay) * 107 / 100
					  when po.SystemCategoryId = 129 then sum(po.Notpay)
				else sum(po.Notpay)
				end [PORemainAmount]
			from(
				select po.LocationId
				,po.SystemCategoryId
				,case when po.DocType = 22 then (po.POAmount - po.AdjustAmount - po.AdjustInvoiceAmount - po.DiscountInvAmount)  - (po.PayAmount + po.PaycnAmount)
					 when po.DocType = 43 then  (po.POAmount - po.AdjustAmount - po.AdjustInvoiceAmount)  - po.PayAmount
					 End Notpay
				from( 
					/*PO ExtVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) - ISNULL(sp.PODiscount,0) POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rs.RSAmount,0) - ISNULL(rs.RSDiscount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId 
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select pl.POId,pl.SystemCategoryId,SUM(pl.Amount) PODiscount
								from POLines pl
								where pl.SystemCategoryId = 124
								group by pl.POId,pl.SystemCategoryId
								) sp on p.Id = sp.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					LEFT JOIN (
						SELECT a.RefDocId, SUM(a.RSAmount) RSAmount ,SUM(a.RSDiscount) RSDiscount
						from(
								select  r.RefDocId,sum(rl.Amount) RSAmount, NULL RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1) 
								GROUP by r.RefDocId 
						UNION ALL
								SELECT r.RefDocId,NULL RSAmount, sum(rl.Amount) RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								WHERE rl.SystemCategoryId = 124 AND r.DocStatus not in (-1) 
								GROUP by r.RefDocId ) a group by RefDocId
					)rs ON rs.RefDocId = p.Id
					OUTER APPLY (
								select po.Id,SUM(i.InvoiceAmount) InvoiceAmount,SUM(i.DiscountInvAmount) DiscountInvAmount,SUM(cn.AdjustInvoiceAmount) AdjustInvoiceAmount
								,SUM(pl1.PayAmount1) PayAmount1,SUM(pl2.PayAmount2) PayAmount2,SUM(pn1.PaycnAmount1) PaycnAmount1,SUM(pn2.PaycnAmount2) PaycnAmount2
								from POes po
								LEFT JOIN (
										select i.Id,i.Code,il.RefDocId2,il.RefDocCode2,sum(il.Amount) InvoiceAmount, SUM(il.SpecialDiscount) DiscountInvAmount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
											group by il.RefDocId2,il.RefDocCode2,i.Id,i.Code
										) i ON i.RefDocId2 = po.Id
								left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode
											) cn ON cn.RefDocId = i.Id
								left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.TaxBase) PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode,pl.DocId
											)pl1 on i.Id = pl1.DocId
								LEFT JOIN (select p.id,pl.InvoiceAPCode
											,SUM(pl.PayDocAmount) * 100 / 107 PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											) pl2 ON pl2.InvoiceAPCode = i.Code
								left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.PayDocAmount) PaycnAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocId
											)pn1 on cn.Id = pn1.DocId 
								left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
											,sum(pl.PayDocAmount) PaycnAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on pn2.InvoiceAPCode = cn.Code
								where po.Id = p.Id
								GROUP BY Po.Id
					) il
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 123 
							

					union all
					/*PO IncVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) - ISNULL(sp.PODiscount,0)POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rs.RSAmount,0) - ISNULL(rs.RSDiscount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId 
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select pl.POId,pl.SystemCategoryId,SUM(pl.Amount) PODiscount
								from POLines pl
								where pl.SystemCategoryId = 124
								group by pl.POId,pl.SystemCategoryId
								) sp on p.Id = sp.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					LEFT JOIN (
						SELECT a.RefDocId, SUM(a.RSAmount) RSAmount ,SUM(a.RSDiscount) RSDiscount
						from(
								select  r.RefDocId,sum(rl.Amount) RSAmount, NULL RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1) 
								GROUP by r.RefDocId 
						UNION ALL
								SELECT r.RefDocId,NULL RSAmount, sum(rl.Amount) RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								WHERE rl.SystemCategoryId = 124 AND r.DocStatus not in (-1) 
								GROUP by r.RefDocId ) a group by RefDocId
					)rs ON rs.RefDocId = p.Id
					OUTER APPLY (
								select po.Id,SUM(i.InvoiceAmount) InvoiceAmount,SUM(i.DiscountInvAmount) DiscountInvAmount,SUM(cn.AdjustInvoiceAmount) AdjustInvoiceAmount
								,SUM(pl1.PayAmount1) PayAmount1,SUM(pl2.PayAmount2) PayAmount2,SUM(pn1.PaycnAmount1) PaycnAmount1,SUM(pn2.PaycnAmount2) PaycnAmount2
								from POes po
								LEFT JOIN (
										select i.Id,i.Code,il.RefDocId2,il.RefDocCode2,sum(il.Amount) InvoiceAmount, SUM(il.SpecialDiscount) DiscountInvAmount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
											group by il.RefDocId2,il.RefDocCode2,i.Id,i.Code
										) i ON i.RefDocId2 = po.Id
								left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode
											) cn ON cn.RefDocId = i.Id
								left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.PayDocAmount) PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode,pl.DocId
											)pl1 on i.Id = pl1.DocId
								LEFT JOIN (select p.id,pl.InvoiceAPCode
											,SUM(pl.PayDocAmount) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											) pl2 ON pl2.InvoiceAPCode = i.Code
								left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.PayDocAmount) PaycnAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocId
											)pn1 on cn.Id = pn1.DocId 
								left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
											,sum(pl.PayDocAmount) PaycnAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on pn2.InvoiceAPCode = cn.Code
								where po.Id = p.Id
								GROUP BY Po.Id
					) il
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 129
							

					union all
					/*PO NOVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) - ISNULL(sp.PODiscount,0) POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rs.RSAmount,0) - ISNULL(rs.RSDiscount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId 
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select pl.POId,pl.SystemCategoryId,SUM(pl.Amount) PODiscount
								from POLines pl
								where pl.SystemCategoryId = 124
								group by pl.POId,pl.SystemCategoryId
								) sp on p.Id = sp.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					LEFT JOIN (
						SELECT a.RefDocId, SUM(a.RSAmount) RSAmount ,SUM(a.RSDiscount) RSDiscount
						from(
								select  r.RefDocId,sum(rl.Amount) RSAmount, NULL RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1) 
								GROUP by r.RefDocId 
						UNION ALL
								SELECT r.RefDocId,NULL RSAmount, sum(rl.Amount) RSDiscount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								WHERE rl.SystemCategoryId = 124 AND r.DocStatus not in (-1) 
								GROUP by r.RefDocId ) a group by RefDocId
					)rs ON rs.RefDocId = p.Id
					OUTER APPLY (
								select po.Id,SUM(i.InvoiceAmount) InvoiceAmount,SUM(i.DiscountInvAmount) DiscountInvAmount,SUM(cn.AdjustInvoiceAmount) AdjustInvoiceAmount
								,SUM(pl1.PayAmount1) PayAmount1,SUM(pl2.PayAmount2) PayAmount2,SUM(pn1.PaycnAmount1) PaycnAmount1,SUM(pn2.PaycnAmount2) PaycnAmount2
								from POes po
								LEFT JOIN (
										select i.Id,i.Code,il.RefDocId2,il.RefDocCode2,sum(il.Amount) InvoiceAmount, SUM(il.SpecialDiscount) DiscountInvAmount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
											group by il.RefDocId2,il.RefDocCode2,i.Id,i.Code
										) i ON i.RefDocId2 = po.Id
								left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode
											) cn ON cn.RefDocId = i.Id
								left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.PayDocAmount) PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode,pl.DocId
											)pl1 on i.Id = pl1.DocId
								LEFT JOIN (select p.id,pl.InvoiceAPCode
											,SUM(pl.PayDocAmount) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											) pl2 ON pl2.InvoiceAPCode = i.Code
								left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
											,sum(pl.PayDocAmount) PaycnAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocId
											)pn1 on cn.Id = pn1.DocId 
								left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
											,sum(pl.PayDocAmount) PaycnAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on pn2.InvoiceAPCode = cn.Code
								where po.Id = p.Id
								GROUP BY Po.Id
					) il
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 131
							

					union all
					/*OP ExtVat*/
					select p.LocationId,p.Id,p.Code,43 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,0 AdjustAmount
					,0 RSAmount
					,0 InvoiceAmount
					,0 DiscountInvAmount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) * 107 / 100 PayAmount
					,0 PaycnAmount
					from OtherPayments p
					left join OtherPaymentLines pl on p.Id = pl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'Material'  
								group by b.RefDocCode,b.RefDocType
								) b1 on p.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'Material'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on p.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on p.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on p.Code = b4.RefDocCode
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 123
							and p.SubDocTypeId in (629,630)
							



					union all
					/*OP IncVat*/
					select p.LocationId,p.Id,p.Code,43 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,0 AdjustAmount
					,0 RSAmount
					,0 InvoiceAmount
					,0 DiscountInvAmount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) * 107 / 100 PayAmount
					,0 PaycnAmount
					from OtherPayments p
					left join OtherPaymentLines pl on p.Id = pl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'Material'  
								group by b.RefDocCode,b.RefDocType
								) b1 on p.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'Material'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on p.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on p.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on p.Code = b4.RefDocCode
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 129
							and p.SubDocTypeId in (629,630)
							

					union all
					/*OP NOVat*/
					select p.LocationId,p.Id,p.Code,43 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,0 AdjustAmount
					,0 RSAmount
					,0 InvoiceAmount
					,0 DiscountInvAmount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) PayAmount
					,0 PaycnAmount
					from OtherPayments p
					left join OtherPaymentLines pl on p.Id = pl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'Material'  
								group by b.RefDocCode,b.RefDocType
								) b1 on p.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'Material'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on p.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on p.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'Material' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on p.Code = b4.RefDocCode
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 131
							and p.SubDocTypeId in (629,630)
							
							
				) po
		)po group by po.LocationId,po.SystemCategoryId
	)po group by po.LocationId
)po 
option(recompile);

/************************************************************************************************************************************************************************/
/*#TempSCRemain*/
IF OBJECT_ID(N'tempdb..#TempSCRemain') IS NOT NULL
BEGIN
    DROP TABLE #TempSCRemain;
END;

SELECT *
INTO #TempSCRemain
FROM
(
select sc.LocationId,SUM(sc.SCRemainTaxbase) SCRemainTaxbase,SUM(sc.SCRemainAmount) SCRemainAmount
from(
	select sc.LocationId,sc.SystemCategoryId
			,case when sc.SystemCategoryId in (123,131) then sum(sc.Notpay) 
						  when sc.SystemCategoryId = 129 then sum(sc.Notpay) * 100 / 107
					end [SCRemainTaxbase]
					,case when sc.SystemCategoryId = 123 then sum(sc.Notpay) * 107 / 100 
						  when sc.SystemCategoryId in (129,131) then sum(sc.Notpay) 
					end [SCRemainAmount]
	from(
			select sc.LocationId
				,sc.SystemCategoryId
				,case when sc.DocType = 105 then (sc.SCAmount - sc.DeductionRecordDocAmount - sc.AdjustCostAmount - sc.AdjustInvoiceAmount - sc.SpecialDiscount)  - (sc.PayAmount + sc.PaycnAmount)
					 when sc.DocType = 43 then  (sc.SCAmount - sc.AdjustInvoiceAmount) - sc.PayAmount
					 End Notpay
					
	from(
			/*SC ExtVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) - ISNULL(sul.SCDiscount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
								from SubContracts s
								left join SubContractLines sl on s.Id = sl.SubContractId 
								left join (select sl.SubContractId,SUM(sl.Amount) SCAmount, SUM(SpecialDiscountAmount) SCDiscount
											from SubContractLines sl
											where sl.SystemCategoryId = 105
											group by sl.SubContractId
											) sul on s.Id = sul.SubContractId 
								left join (select p.SubContractId
													,SUM(p.SubTotal) SubTotal
													,SUM(p.RetentionAmount) RetentionAmount
													,SUM(p.WHTAmount) WHTAmount
													,SUM(p.DeductionRecordDocAmount) DeductionRecordDocAmount
											from ProgressAcceptances p
											where p.DocStatus not in (-1)
											group by p.SubContractId
											) p on s.Id = p.SubContractId
								left join (select v.SubContractId,ABS(sum(vl.AdjustCostAmount)) AdjustCostAmount
											from VariationOrders v
											left join VariationOrderLines vl on v.id = vl.VariationOrderId
											where vl.SystemCategoryId = 105
											group by v.SubContractId
											) v on s.Id = v.SubContractId
								OUTER APPLY (
											select sc.Id,SUM(i.InvoiceAmount) InvoiceAmount,SUM(i.SpecialDiscount) SpecialDiscount,SUM(cn.AdjustInvoiceAmount) AdjustInvoiceAmount
											,SUM(pl1.PayAmount1) PayAmount1,SUM(pl2.PayAmount2) PayAmount2,SUM(pn1.PaycnAmount1) PaycnAmount1,SUM(pn2.PaycnAmount2) PaycnAmount2
											from SubContracts sc
											LEFT JOIN (
													select i.Id,i.Code,il.RefDocId2,il.RefDocCode2,sum(il.Amount) InvoiceAmount , SUM(il.SpecialDiscount) SpecialDiscount
														from Invoices i
														left join InvoiceLines il on i.Id = il.InvoiceId
														where il.SystemCategoryId = 105 and i.DocStatus not in (-1)
														group by il.RefDocId2,il.RefDocCode2,i.Id,i.Code
													) i ON i.RefDocId2 = sc.Id
											left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
														from AdjustInvoices c
														left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
														where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
														group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode
														) cn ON cn.RefDocId = i.Id
											left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
														,sum(pl.TaxBase) PayAmount1
														from Payments p
														left join PaymentLines pl on p.Id = pl.PaymentId
														where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
														group by p.id,pl.DocCode,pl.DocId
														)pl1 on i.Id = pl1.DocId
											LEFT JOIN (select p.id,pl.InvoiceAPCode
														,SUM(pl.PayDocAmount) * 100 / 107 PayAmount2
														from Payments p
														left join PaymentLines pl on p.Id = pl.PaymentId
														where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
														group by p.id,pl.InvoiceAPCode
														) pl2 ON pl2.InvoiceAPCode = i.Code
											left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
														,sum(pl.PayDocAmount) PaycnAmount1
														from Payments p
														left join PaymentLines pl on p.Id = pl.PaymentId
														where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
														group by p.id,pl.DocId
														)pn1 on cn.Id = pn1.DocId 
											left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
														,sum(pl.PayDocAmount) PaycnAmount2
														from Payments p
														left join PaymentLines pl on p.Id = pl.PaymentId
														where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
														group by p.id,pl.InvoiceAPCode
														)pn2 on pn2.InvoiceAPCode = cn.Code
											where sc.Id = s.Id
											GROUP BY sc.Id
											) il
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 123
										
			union all
			/*SC IncVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
								from SubContracts s
								left join SubContractLines sl on s.Id = sl.SubContractId 
								left join (select sl.SubContractId,SUM(sl.Amount) SCAmount
											from SubContractLines sl
											where sl.SystemCategoryId = 105
											group by sl.SubContractId
											) sul on s.Id = sul.SubContractId 
								left join (select p.SubContractId
													,SUM(p.SubTotal) SubTotal
													,SUM(p.RetentionAmount) RetentionAmount
													,SUM(p.WHTAmount) WHTAmount
													,SUM(p.DeductionRecordDocAmount) DeductionRecordDocAmount
											from ProgressAcceptances p
											where p.DocStatus not in (-1)
											group by p.SubContractId
											) p on s.Id = p.SubContractId
								left join (select v.SubContractId,ABS(sum(vl.AdjustCostAmount)) AdjustCostAmount
											from VariationOrders v
											left join VariationOrderLines vl on v.id = vl.VariationOrderId
											where vl.SystemCategoryId = 105
											group by v.SubContractId
											) v on s.Id = v.SubContractId
								OUTER APPLY (SELECT a.RefDocId2,SUM(a.InvoiceAmount) InvoiceAmount, SUM(a.SpecialDiscount) SpecialDiscount, SUM(a.AdjustInvoiceAmount) AdjustInvoiceAmount
                                            ,SUM(a.PayAmount1) PayAmount1,SUM(a.PayAmount2) PayAmount2, SUM(a.PaycnAmount1) PaycnAmount1, SUM(a.PaycnAmount2) PaycnAmount2
                                            from(
                                                select il.RefDocId2,SUM(il.Amount) InvoiceAmount,SUM(il.SpecialDiscount) SpecialDiscount,ISNULL(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
											,ISNULL(pl1.PayAmount1,0)PayAmount1,ISNULL(pl2.PayAmount2,0)PayAmount2,ISNULL(pn1.PayAmount1,0) PaycnAmount1,ISNULL(pn2.PayAmount2,0)PaycnAmount2
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId

                                            left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
                                                        from AdjustInvoices c
                                                        left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
                                                        where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
                                                        group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode) cn ON cn.RefDocId = i.Id
                                            left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount1
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.DocCode,pl.DocId
                                                        )pl1 on i.Id = pl1.DocId
                                            LEFT JOIN (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount2
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.InvoiceAPCode) pl2 ON pl2.InvoiceAPCode = i.Code
                                            left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount1
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.DocId
                                                        )pn1 on cn.Id = pn1.DocId 
                                            left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount2
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.InvoiceAPCode
                                                        )pn2 on pn2.InvoiceAPCode = cn.Code
											where il.SystemCategoryId = 105 and i.DocStatus not in (-1) AND il.RefDocId2 = s.Id
											group by il.RefDocId2,cn.AdjustInvoiceAmount,pl1.PayAmount1,pl2.PayAmount2,pn1.PayAmount1,pn2.PayAmount2
                                            )a group by a.RefDocId2
                                            ) il
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 129
										
			union all
			/*SC NOVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(il.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(il.PayAmount1,(isnull(il.PayAmount2,0))) PayAmount
					,isnull(il.PaycnAmount1,(isnull(il.PaycnAmount2,0))) PaycnAmount
								from SubContracts s
								left join SubContractLines sl on s.Id = sl.SubContractId 
								left join (select sl.SubContractId,SUM(sl.Amount) SCAmount
											from SubContractLines sl
											where sl.SystemCategoryId = 105
											group by sl.SubContractId
											) sul on s.Id = sul.SubContractId 
								left join (select p.SubContractId
													,SUM(p.SubTotal) SubTotal
													,SUM(p.RetentionAmount) RetentionAmount
													,SUM(p.WHTAmount) WHTAmount
													,SUM(p.DeductionRecordDocAmount) DeductionRecordDocAmount
											from ProgressAcceptances p
											where p.DocStatus not in (-1)
											group by p.SubContractId
											) p on s.Id = p.SubContractId
								left join (select v.SubContractId,ABS(sum(vl.AdjustCostAmount)) AdjustCostAmount
											from VariationOrders v
											left join VariationOrderLines vl on v.id = vl.VariationOrderId
											where vl.SystemCategoryId = 105
											group by v.SubContractId
											) v on s.Id = v.SubContractId
								OUTER APPLY (SELECT a.RefDocId2,SUM(a.InvoiceAmount) InvoiceAmount, SUM(a.SpecialDiscount) SpecialDiscount, SUM(a.AdjustInvoiceAmount) AdjustInvoiceAmount
                                            ,SUM(a.PayAmount1) PayAmount1,SUM(a.PayAmount2) PayAmount2, SUM(a.PaycnAmount1) PaycnAmount1, SUM(a.PaycnAmount2) PaycnAmount2
                                            from(
                                                select il.RefDocId2,SUM(il.Amount) InvoiceAmount,SUM(il.SpecialDiscount) SpecialDiscount,ISNULL(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
											,ISNULL(pl1.PayAmount1,0)PayAmount1,ISNULL(pl2.PayAmount2,0)PayAmount2,ISNULL(pn1.PayAmount1,0) PaycnAmount1,ISNULL(pn2.PayAmount2,0)PaycnAmount2
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId

                                            left join (select c.Id,c.Code,cl.RefDocId,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
                                                        from AdjustInvoices c
                                                        left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
                                                        where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
                                                        group by c.Id,c.Code,cl.RefDocId,cl.RefDocCode) cn ON cn.RefDocId = i.Id
                                            left join (select p.id,pl.DocCode,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount1
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.DocCode,pl.DocId
                                                        )pl1 on i.Id = pl1.DocId
                                            LEFT JOIN (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount2
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.InvoiceAPCode) pl2 ON pl2.InvoiceAPCode = i.Code
                                            left join (select p.id,pl.DocId--,Isnull(sum(pl.DocAmount),0)  PayAmount1
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount1
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.DocId
                                                        )pn1 on cn.Id = pn1.DocId 
                                            left join (select p.id,pl.InvoiceAPCode--,Isnull(sum(pl.DocAmount),0) PayAmount2
                                                        ,Isnull(sum(pl.PayDocAmount),0) + Isnull(sum(pl.RetentionSetDocAmount),0)  PayAmount2
                                                        from Payments p
                                                        left join PaymentLines pl on p.Id = pl.PaymentId
                                                        where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
                                                        group by p.id,pl.InvoiceAPCode
                                                        )pn2 on pn2.InvoiceAPCode = cn.Code
											where il.SystemCategoryId = 105 and i.DocStatus not in (-1) AND il.RefDocId2 = s.Id
											group by il.RefDocId2,cn.AdjustInvoiceAmount,pl1.PayAmount1,pl2.PayAmount2,pn1.PayAmount1,pn2.PayAmount2
                                            )a group by a.RefDocId2
                                            ) il
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 131
										
			union all
			
			/*OP ExtVat*/					
			select s.LocationId,s.Id,43 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(b1.POAmount,0) SCAmount
					,isnull(NULL,0) RetentionAmount,isnull(NULL,0)  WHTAmount,isnull(NULL,0)  DeductionRecordDocAmount
					,0 AdjustCostAmount,0 InvoiceAmount,0 SpecialDiscount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) * 107 / 100 PayAmount
					,0 PaycnAmount
					from OtherPayments s
					left join OtherPaymentLines sl on s.Id = sl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'SubContract'  
								group by b.RefDocCode,b.RefDocType
								) b1 on s.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'SubContract'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on s.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on s.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on s.Code = b4.RefDocCode
					where s.Date <= @Todate
							and s.DocStatus not in (-1) 
							and sl.SystemCategoryId = 123
							and s.SubDocTypeId in (629,630)
							
							
			union all
			/*OP IncVat*/					
			select s.LocationId,s.Id,43 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(b1.POAmount,0) SCAmount
					,isnull(NULL,0) RetentionAmount,isnull(NULL,0)  WHTAmount,isnull(NULL,0)  DeductionRecordDocAmount
					,0 AdjustCostAmount,0 InvoiceAmount,0 SpecialDiscount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) * 107 / 100 PayAmount
					,0 PaycnAmount
					from OtherPayments s
					left join OtherPaymentLines sl on s.Id = sl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'SubContract'  
								group by b.RefDocCode,b.RefDocType
								) b1 on s.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'SubContract'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on s.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on s.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on s.Code = b4.RefDocCode
					where s.Date <= @Todate
							and s.DocStatus not in (-1) 
							and sl.SystemCategoryId = 129
							and s.SubDocTypeId in (629,630)
							
			union all
			/*OP NOVat*/					
			select s.LocationId,s.Id,43 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(b1.POAmount,0) SCAmount
					,isnull(NULL,0) RetentionAmount,isnull(NULL,0)  WHTAmount,isnull(NULL,0)  DeductionRecordDocAmount
					,0 AdjustCostAmount,0 InvoiceAmount,0 SpecialDiscount
					,isnull(ad.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,IIF(isnull(b4.pay,0) = 0,isnull(b2.pay,0) + isnull(b3.pay,0),isnull(b4.pay,0)) * 107 / 100 PayAmount
					,0 PaycnAmount
					from OtherPayments s
					left join OtherPaymentLines sl on s.Id = sl.OtherPaymentId 
					left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) POAmount
								from CommittedCostLines b
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where b.RefDocType = 'OtherPayment' 
										and bl.SystemCategory = 'SubContract'  
								group by b.RefDocCode,b.RefDocType
								) b1 on s.Code = b1.RefDocCode
					left join (select ad.Id,ad.Code,adj.RefDocCode,b1.AdjustInvoiceAmount
								from AdjustInvoices ad
								left join AdjustInvoiceLines adj on ad.Id = adj.AdjustInvoiceId
								left join (select b.RefDocCode,b.RefDocType,SUM(b.Amount) AdjustInvoiceAmount
											from CommittedCostLines b
											left join BudgetLines bl on b.BudgetLineId = bl.Id 
											where b.RefDocType = 'CreditNoteAP' 
													and bl.SystemCategory = 'SubContract'  
											group by b.RefDocCode,b.RefDocType
											) b1 on ad.Code = b1.RefDocCode
								where ad.DocStatus not in (-1) 
								) ad on s.Code = ad.RefDocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค OP มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b2 on s.Code = b2.DocCode
					left join (select pl.DocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from Payments p
								left join PaymentLines pl on p.id = pl.PaymentId
								left join CommittedCostLines b on pl.DocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.DocCode
								) b3 on ad.Code = b3.DocCode
					left join (select pl.RefDocCode,sum(b.Amount) pay  /*เช็ค CN มาจ่าย PV*/
								from OtherPayments p
								left join OtherPaymentLines pl on p.id = pl.OtherPaymentId
								left join CommittedCostLines b on pl.RefDocCode = b.RefDocCode
								left join BudgetLines bl on b.BudgetLineId = bl.Id 
								where bl.SystemCategory = 'SubContract' 
										and p.DocStatus not in (-1)
								group by pl.RefDocCode
								) b4 on s.Code = b4.RefDocCode
					where s.Date <= @Todate
							and s.DocStatus not in (-1) 
							and sl.SystemCategoryId = 131
							and s.SubDocTypeId in (629,630)
							
			) sc		
		)sc group by sc.LocationId,sc.SystemCategoryId
	)sc group by sc.LocationId
)sc
option(recompile);
/************************************************************************************************************************************************************************/
/*#Tempbudget*/
IF OBJECT_ID(N'tempdb..#Tempbudget') IS NOT NULL
BEGIN
    DROP TABLE #Tempbudget;
END;

SELECT *
INTO #Tempbudget
FROM
(

select *
from (
		select ProjectId,Id,Date
				, ROW_NUMBER () over (partition by ProjectId,BudgetId order by ProjectId,BudgetId,Date DESC) rvNo
				, Code
				, Description
		from RevisedBudgets
		--where Date <= @Todate
) rv
where rv.rvNo  = 1
)r 
option(recompile);
/************************************************************************************************************************************************************************/
/*#TempPOPaid*/
IF OBJECT_ID(N'tempdb..#TempPOPaid') IS NOT NULL
BEGIN
    DROP TABLE #TempPOPaid;
END;

SELECT *
INTO #TempPOPaid
FROM
(
select po.PaidProjectId
			,SUM(po.POTaxbase) POTaxbase
			,SUM(po.POAmount) POAmount
from (

		select po.PaidProjectId
					,case when po.TypeVat = 123 then sum(po.pamount)
							  when po.TypeVat = 129 then sum(po.pamount) --* 100 / 107
						else sum(po.pamount)
						end [POTaxbase]
						,case when po.TypeVat = 123 then sum(po.pamount) * 107 / 100
							  when po.TypeVat = 129 then sum(po.pamount) * 107 / 100
						else sum(po.pamount)
						end [POAmount]	
		from(

				/*จ่ายค่าของ Invoice,billing,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join InvoiceLines il on i.Id = il.InvoiceId
				left join BillingAPLines bl on i.Code = bl.DocCode
				--left join BillingAPs b on bl.BillingAPId = b.Id
				--left join PaymentLines pl on b.Code = pl.DocCode
				left join PaymentLines pl on bl.Id = pl.BillingAPLineId  /*2023-12-26 : ปรับเงื่อนไขใหม่*/
				--left join Payments p on pl.PaymentId = p.Id
				--left join PaidCostLines pd on p.Code = pd.RefDocCode
				left join PaidCostLines pd on pl.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
                        and pd.RefDocTypeId = 50
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าของ Invoice,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join InvoiceLines il on i.Id = il.InvoiceId
				left join PaymentLines pl on i.Code = pl.DocCode
				--left join Payments p on pl.PaymentId = p.Id
				--left join PaidCostLines pd on p.Code = pd.RefDocCode
				left join PaidCostLines pd on pl.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.RefDocTypeId = 50
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าของ AdjustInvoice,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from AdjustInvoices i
				left join AdjustInvoiceLines il on i.Id = il.AdjustInvoiceId
				left join PaymentLines pl on i.Code = pl.DocCode
				left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าของ WorkerExpenses */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,Isnull(il.SystemCategoryId,131) TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from WorkerExpenses i
				left join WorkerExpenseLines il on i.Id = il.WorkerExpenseId
				--left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join PaidCostLines pd on il.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.RefDocTypeId = 97
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าของ JV  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from JournalVouchers i
				left join PaidCostLines pd on i.Code = pd.RefDocCode and i.OrgId = pd.PaidProjectId
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.RefDocTypeId = 64
						and pd.Date <= @Todate

				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory

				union all
				/*จ่ายค่าของ OP  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,ISNULL(ol.SystemCategoryId,131) TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from OtherPayments i
				left join OtherPaymentLines il on i.Id = il.OtherPaymentId
				--left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join PaidCostLines pd on il.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				left join (select ol.OtherPaymentId,ol.SystemCategoryId
							from OtherPaymentLines ol
							where ol.SystemCategoryId in (123,129)
							) ol on pd.RefDocId = ol.OtherPaymentId
				where  bu.SystemCategoryId = 99
						and i.SubDocTypeId not in (629,630)
						--and il.SystemCategoryId in (123,129,131)
						and pd.RefDocTypeId = 43
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,ol.SystemCategoryId,bu.SystemCategory
				/*รายงานคุณกรไม่ใช่*/
				--union all
				--/*ค่าของ OP ตั้งหนี้และจ่าย*/
				--select b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId TypeVat,bl.SystemCategory,sum(pd.Amount) pamount
				--from Budgets b
				--left join BudgetLines bl on b.Id = bl.BudgetId
				--left join PaidCostLines pd on bl.Id = pd.BudgetLineId
				--inner join OtherPayments o on pd.RefDocCode = o.Code
				--inner join OtherPaymentLines ol on o.Code = ol.RefDocCode
				--inner join OtherPayments oo on ol.RefDocCode = oo.Code
				--inner join OtherPaymentLines oll on oo.Id = oll.OtherPaymentId
				--where bl.SystemCategoryId = 99
				--		and oll.SystemCategoryId in (123,129,131)
				--						and pd.Date <= @Todate
				--						and pd.RefDocTypeId in (43)
				--						and o.SubDocTypeId  in (629,630)
				--group by b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId,bl.SystemCategory

				)po
				group by po.PaidProjectId,po.TypeVat
		) po
		group by po.PaidProjectId
)po 
option(recompile);
/************************************************************************************************************************************************************************/
/*#TempSCPaid*/
IF OBJECT_ID(N'tempdb..#TempSCPaid') IS NOT NULL
BEGIN
    DROP TABLE #TempSCPaid;
END;

SELECT *
INTO #TempSCPaid
FROM
(
select po.PaidProjectId
			,SUM(po.POTaxbase) POTaxbase
			,SUM(po.POAmount) POAmount
from (

		select po.PaidProjectId
					,case when po.TypeVat = 123 then sum(po.pamount)
							  when po.TypeVat = 129 then sum(po.pamount) --* 100 / 107
						else sum(po.pamount)
						end [POTaxbase]
						,case when po.TypeVat = 123 then sum(po.pamount) * 107 / 100
							  when po.TypeVat = 129 then sum(po.pamount) * 107 / 100
						else sum(po.pamount)
						end [POAmount]	
		from(

				/*จ่ายค่าแรง Invoice,billing,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join InvoiceLines il on i.Id = il.InvoiceId
				left join BillingAPLines bl on i.Code = bl.DocCode
				--left join BillingAPs b on bl.BillingAPId = b.Id
				--left join PaymentLines pl on b.Code = pl.DocCode
				left join PaymentLines pl on bl.Id = pl.BillingAPLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				--left join Payments p on pl.PaymentId = p.Id
				--left join PaidCostLines pd on p.Code = pd.RefDocCode
				left join PaidCostLines pd on pl.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
                        and pd.RefDocTypeId = 50
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าแรง Invoice,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join InvoiceLines il on i.Id = il.InvoiceId
				left join PaymentLines pl on i.Code = pl.DocCode
				--left join Payments p on pl.PaymentId = p.Id
				--left join PaidCostLines pd on p.Code = pd.RefDocCode
				left join PaidCostLines pd on pl.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.RefDocTypeId = 50
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าแรง AdjustInvoice,payment */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from AdjustInvoices i
				left join AdjustInvoiceLines il on i.Id = il.AdjustInvoiceId
				left join PaymentLines pl on i.Code = pl.DocCode
				left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and il.SystemCategoryId in (123,129,131)
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าแรง WorkerExpenses */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,Isnull(il.SystemCategoryId,131) TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from WorkerExpenses i
				left join WorkerExpenseLines il on i.Id = il.WorkerExpenseId
				--left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join PaidCostLines pd on il.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.RefDocTypeId = 97
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,il.SystemCategoryId,bu.SystemCategory

				union all
				/*จ่ายค่าแรง JV  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from JournalVouchers i
				left join PaidCostLines pd on i.Code = pd.RefDocCode and i.OrgId = pd.PaidProjectId
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.RefDocTypeId = 64
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory

				union all
				/*จ่ายค่าแรง OP  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,ol.SystemCategoryId TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from OtherPayments i
				left join OtherPaymentLines il on i.Id = il.OtherPaymentId
				--left join PaidCostLines pd on i.Code = pd.RefDocCode
				left join PaidCostLines pd on il.Id = pd.RefDocLineId	/*2023-12-26 : ปรับเงื่อนไขใหม่*/
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				left join (select ol.OtherPaymentId,ol.SystemCategoryId
							from OtherPaymentLines ol
							where ol.SystemCategoryId in (123,129)
							) ol on pd.RefDocId = ol.OtherPaymentId
				where  bu.SystemCategoryId = 105
						and i.SubDocTypeId not in (629,630)
						--and il.SystemCategoryId in (123,129,131)
						and pd.RefDocTypeId = 43
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,ol.SystemCategoryId,bu.SystemCategory
				/*รายงานคุณกรไม่ใช่*/
				--union all
				--/*จ่ายค่าแรง OP ตั้งหนี้และจ่าย*/
				--select b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId TypeVat,bl.SystemCategory,sum(pd.Amount) pamount
				--from Budgets b
				--left join BudgetLines bl on b.Id = bl.BudgetId
				--left join PaidCostLines pd on bl.Id = pd.BudgetLineId
				--inner join OtherPayments o on pd.RefDocCode = o.Code
				--inner join OtherPaymentLines ol on o.Code = ol.RefDocCode
				--inner join OtherPayments oo on ol.RefDocCode = oo.Code
				--inner join OtherPaymentLines oll on oo.Id = oll.OtherPaymentId
				--where bl.SystemCategoryId = 105
				--		and oll.SystemCategoryId in (123,129,131)
				--						and pd.Date <= @Todate
				--						and pd.RefDocTypeId in (43)
				--						and o.SubDocTypeId  in (629,630)
				--group by b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId,bl.SystemCategory

				)po
				group by po.PaidProjectId,po.TypeVat
		) po
		group by po.PaidProjectId
)po 
option(recompile);
/************************************************************************************************************************************************************************/
select * from #TempSCRemain WHERE LocationId = 143
/*1-core*/
SELECT o.Id
		,o.Codesum
		,o.[Code(2)]
		,o.[Name(3)]
		,o.OriginalContractNO
		,o.[OriginalContractAmount(4)]
		,o.VODate
		,o.[VOAmount(5)]
		,o.[CurrentContractAmount(6)]
		,o.ContractNO
		,o.[RVOriginalContract Amount(7)]
		,o.[RVVOContract Amount(8)]
		,o.[RVTotal Amount(9)]	
		,o.[Current Budget Mat(10)]
		,o.[Current Budget Sub(11)]
		,o.[MatPay Amount(12)]
		,o.[SupPay Amount(13)]
		,o.[PVTotal Amount(14)]
		,o.[Gross profit Amount(15)]
		,o.[ReMainContract Amount(16)]
		,o.[PORemainAmount(17)]
		,o.[SCRemainAmount(18)]
		,o.[TotalRemainAmount(19)]
		,o.[BudgetRemainMat(20)]
		,o.[BudgetRemainSub(21)]
		,o.[BudgetRemain(22)]
		,o.[EstCostPaidAmount(23)]
		,o.[Est Gross profit Amount(24)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit Amount(25)]),'%') [% Est Gross profit Amount(25)] 

FROM(

	select	org.Id
		,IIF(org.Code like '%AN-%',substring(org.Code,4,20),org.Code) [Codesum]
		,org.Code [Code(2)] /*(2)*/
		,org.Name [Name(3)]/*(2)*/
		,orgP.ContractNO [OriginalContractNO] 
		,ISNULL(orgP.ContractAmount,0) [OriginalContractAmount(4)] /*(4)*/
		,pvo.VOcontractdate [VODate]
		,ISNULL(pvo.VOSUM,0) [VOAmount(5)] /*(5)*/
		,(ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0)) [CurrentContractAmount(6)]  /*(6) = (4)+(5)*/
		,m.ContractNO
		,ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0) [RVOriginalContract Amount(7)] /*(7)*/

		--,ISNULL(s.Amount,0) [RVVOContract Amount(8)] /*(8)*/
		,ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0)  [RVVOContract Amount(8)] /*(8)*/
		
		--,((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0)) + ISNULL(s.Amount,0)) [RVTotal Amount(9)] /*(9) = (7)+(8)*/
		,((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0))) [RVTotal Amount(9)] /*(9) = (7)+(8)*/

		,ISNULL(BRMat.BlMatAmount,0) [Current Budget Mat(10)] /*(10)*/
		,ISNULL(BRSub.BlSubAmount,0) [Current Budget Sub(11)] /*(11)*/
		,ISNULL(mp.POAmount,0) [MatPay Amount(12)] /*(12)*/
		,ISNULL(sp.POAmount,0) [SupPay Amount(13)] /*(13)*/
		,ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0) [PVTotal Amount(14)]  /*(14) = (12)+(13)*/

		--,((ISNULL(m.Amount,0) + ISNULL(s.Amount,0))) - (ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0)) [Gross profit Amount(15)] /*(15) = (9)-(14)*/
		--,((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0)) + ISNULL(s.Amount,0)) - (ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0)) [Gross profit Amount(15)] /*(15) = (9)-(14)*/
		,((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0))) - (ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0)) [Gross profit Amount(15)] /*(15) = (9)-(14)*/

		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(s.Amount,0))) [ReMainContract Amount(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0)) + ISNULL(s.Amount,0)) [ReMainContract Amount(16)]  /*(16) = (6)-(9)*/
		,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0))) [ReMainContract Amount(16)]  /*(16) = (6)-(9)*/

		,ISNULL(PORemain.PORemainAmount,0) [PORemainAmount(17)] /*(17)*/
		,ISNULL(SCRemain.SCRemainAmount,0) [SCRemainAmount(18)] /*(18)*/
		,ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0) [TotalRemainAmount(19)] /*(19) = (17)+(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) [BudgetRemainMat(20)] /*(20)*/
		,ISNULL(BRMat.BudgetRemainMat,0) /* - ISNULL(mp.POAmount,0) */ /* - ISNULL(PORemain.PORemainAmount,0) */ [BudgetRemainMat(20)] /*(20) = (10)-(12)-(17)*/

		--,ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemainSub(21)] /*(21)*/
		,ISNULL(BRSub.BudgetRemainSub,0) /* - ISNULL(sp.POAmount,0) */ /* - ISNULL(SCRemain.SCRemainAmount,0) */ [BudgetRemainSub(21)] /*(21) = (11)-(13)-(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemain(22)] /*(22) = (20)+(21)*/
		,(ISNULL(BRMat.BlMatAmount,0) /* - ISNULL(mp.POAmount,0) *//*  - ISNULL(PORemain.PORemainAmount,0) */) /*(20)*/	
		 + (ISNULL(BRSub.BlSubAmount,0) /* - ISNULL(sp.POAmount,0) */ /* - ISNULL(SCRemain.SCRemainAmount,0) */) /*(21)*/
		 [BudgetRemain(22)] /*(22) = (20)+(21)*/

		--,ISNULL((ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) + (BRMat.BudgetRemainMat + BRSub.BudgetRemainSub),0)  [EstCostPaidAmount(23)] /*(23) =(19)+(22)*/
		,(ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) /*(19)*/
		 + ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POAmount,0) - ISNULL(PORemain.PORemainAmount,0)) 
		      + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POAmount,0) - ISNULL(SCRemain.SCRemainAmount,0)) ) /*(22)*/
		 [EstCostPaidAmount(23)] /*(23) =(19)+(22)*/

		--,(((ISNULL(m.Amount,0) + ISNULL(s.Amount,0))) - (ISNULL(mp.POAmount,0) + (ISNULL(sp.POAmount,0)))) /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(s.Amount,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) 
		--         + ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POAmount,0) - ISNULL(PORemain.PORemainAmount,0)) 
		--         + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POAmount,0) - ISNULL(SCRemain.SCRemainAmount,0)) )) /*(23)*/ 
		-- [Est Gross profit Amount(24)] /*(24) = (15)+(16)-(23)*/

		 ,(((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0))) - (ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0))) /*(15)*/
			+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0)))) /*(16)*/
			- ( (ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) 
		         + ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POAmount,0) - ISNULL(PORemain.PORemainAmount,0)) 
		         + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POAmount,0) - ISNULL(SCRemain.SCRemainAmount,0)) )) /*(23)*/ 
		 [Est Gross profit Amount(24)] /*(24) = (15)+(16)-(23)*/

		--,CASE WHEN ( ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--	  ELSE	ROUND(ISNULL(((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) /*(6)*/
		--			/ ((((ISNULL(m.Amount,0) + ISNULL(s.Amount,0))) - (ISNULL(mp.POAmount,0) + (ISNULL(sp.POAmount,0)))) /*(15)*/
		--				+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(s.Amount,0)))) /*(16)*/
		--				- ( (ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) 
		--					 + ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POAmount,0) - ISNULL(PORemain.PORemainAmount,0)) 
		--					 + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POAmount,0) - ISNULL(SCRemain.SCRemainAmount,0)) ))) ,0),2)/*(23)*/ 
		--	END [% Est Gross profit Amount(25)] /*(25) = (6) / 24*/

		,CASE WHEN ( ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
			  ELSE	ROUND(ISNULL(
								( (((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0))) - (ISNULL(mp.POAmount,0) + ISNULL(sp.POAmount,0))) /*(15)*/
								+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.Amount,0) + ISNULL(ir.IrAmount,0) + ISNULL(ac.BFAmount,0) + ISNULL(orm.ORMAmount,0)) + (ISNULL(s.Amount,0) + ISNULL(irv.IrVoAmount,0) + ISNULL(ors.ORVAmount,0)))) /*(16)*/
								- ( (ISNULL(PORemain.PORemainAmount,0) + ISNULL(SCRemain.SCRemainAmount,0)) 
									 + ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POAmount,0) - ISNULL(PORemain.PORemainAmount,0)) 
									 + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POAmount,0) - ISNULL(SCRemain.SCRemainAmount,0)) ))) /*(23)*/ 
								/ ((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) /*(6)*/ ,0),2)
			END [% Est Gross profit Amount(25)] /*(25) = (24) / (6)*/
			
from	Organizations org
left join Organizations_ProjectConstruction orgP on org.Id = orgP.id
left join (	select SUM(isnull(ContractAmount,0)) VOSUM,
						max(ContractDate) VOcontractdate,
						pv.ProjectConstructionId 
						from ProjectVOes pv
						where ContractDate <= @Todate
						group by pv.ProjectConstructionId
						)pvo on pvo.ProjectConstructionId = org.id
/*รายได้สัญญาณหลักรับแล้ว*/
left join (select orgP.Id,orgP.ContractNO
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from Organizations_ProjectConstruction orgP
			left join TaxItemLines tl on orgP.ContractNO = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by orgP.Id,orgP.ContractNO
			) m on org.Id = m.Id
/*รายได้สัญญาณ VO รับแล้ว*/
left join (select vo.ProjectConstructionId--,vo.Code
					,SUM(tl.TaxBase) [TaxBase]
					,SUM(tl.TaxAmount) [TaxAmount]
					,SUM(tl.TaxBase+tl.TaxAmount) [Amount]
			from ProjectVOes vo
			left join TaxItemLines tl on vo.Code = tl.ContractNO 
			inner join TaxItems t on t.id = tl.TaxItemId
			inner join ReceiveVoucherLines rl on t.Id = rl.TaxItemId
			inner join ReceiveVouchers r on r.id = rl.ReceiveVoucherId
			where r.Date  <= @Todate
			group by vo.ProjectConstructionId
			) s on org.Id = s.ProjectConstructionId
/*จ่ายอุปกรณ์*/
left join #TempPOPaid mp on org.Id = mp.PaidProjectId
/*จ่ายค่าแรง*/
left join #TempSCPaid sp on org.Id = sp.PaidProjectId
/*TempPORemain*/
left join #TempPORemain PORemain on org.Id = PORemain.LocationId
/*TempSCRemain*/
left join #TempSCRemain SCRemain on org.Id = SCRemain.LocationId
/*BudgetMatRemain*/
left join (select bm.ProjectId,bm.Date,bm.BlMatAmount,bm.UseMatAmount,bm.BlMatAmount-bm.UseMatAmount [BudgetRemainMat]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlMatAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseMatAmount
					,SUM(rl.CompleteAmount) - SUM(isnull(c.Amount,0)) [BudgetRemainMat]
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.OrgId,c.BudgetLineId,sum(c.Amount) Amount
								from CommittedCostLines c
								where c.OrgId is not null
										and Date <= @Todate
								group by c.OrgId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 99
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bm 
			)BRMat on org.Id = BRMat.ProjectId
/*BudgetSubRemain*/
left join (select bs.ProjectId,bs.Date,bs.BlSubAmount,bs.UseSubAmount,bs.BlSubAmount-bs.UseSubAmount [BudgetRemainSub]
			from (
					select r.ProjectId,r.Date,r.Id,SUM(rl.CompleteAmount) BlSubAmount,bl.SystemCategoryId,SUM(isnull(c.Amount,0)) UseSubAmount
					,SUM(rl.CompleteAmount) - SUM(isnull(c.Amount,0)) [BudgetRemainMat]
					from #Tempbudget r
					left join RevisedBudgetLines rl on r.Id = rl.RevisedBudgetId
					left join BudgetLines bl on rl.BudgetLineId = bl.Id
					left join (select c.OrgId,c.BudgetLineId,sum(c.Amount) Amount
								from CommittedCostLines c
								where c.OrgId is not null
										and Date <= @Todate
								group by c.OrgId,c.BudgetLineId
								) c on bl.Id = c.BudgetLineId
					where bl.SystemCategoryId = 105
					group by r.ProjectId,r.Date,r.Id,bl.SystemCategoryId
					)bs
			)BRSub on org.Id = BRSub.ProjectId
/*Interrim BF สัญญาหลัก*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrTaxBase
					,sum(irl.TaxAmount) IrTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO = irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) ir on org.Id = ir.OrgId
/*Interrim BF VO*/
left join (select ir.OrgId,ir.OrgCode
					,sum(irl.TaxBase) IrVoTaxBase
					,sum(irl.TaxAmount) IrVoTaxAmount
					,sum(irl.TaxBase + irl.TaxAmount) IrVoAmount
			from InterimPayments ir
			left join InterimPaymentLines irl on ir.Id = irl.InterimPaymentId and ir.OriginalContractNO <> irl.ContractNO
			where irl.SystemCategoryId = 169
			group by ir.OrgId,ir.OrgCode
			) irv on org.Id = irv.OrgId
/*BF OR*/
left join (select ac.OrgId,ac.OrgCode
					,sum(orl.Amount*100/107) BFTaxbase
					,sum(orl.Amount) BFAmount
			from AcctElementSets ac
			inner join OtherReceiveLines orl on ac.DocCode = orl.RefDocCode
			where ac.DocTypeId = 149 and ac.AccountCode = 11130101
					and orl.SystemCategory = 'SetUpAcctBalFwd' and orl.isDebit = 0
			group by ac.OrgId,ac.OrgCode
			) ac on org.Id = ac.OrgId
/*รายได้สัญญาณหลักรับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORMAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000101,41000201,41000300,41000301,41000400,41000401,41000501,41000600,41000601)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) orm on org.Id = orm.LocationId

/*รายได้สัญญาณ VO รับแล้ว OR*/
left join (select orgP.Id,o.LocationId
					,SUM(orm.Amount) [ORVAmount]
					,IIF(orgP.TaxType = 129,SUM(orm.Amount)*100/107,IIF(orgP.TaxType = 123,SUM(orm.Amount)*107/100,SUM(orm.Amount))) [TaxBase]
			from Organizations_ProjectConstruction orgP
			left join InvoiceARs i on orgP.id = i.LocationId
			left join CustomNoteLines cnl on i.Code = cnl.DataValues and cnl.KeyName = 'RefInvoiceAR'
			left join OtherReceives o on cnl.DocGuid = o.guid 
			left join (select orm.OtherReceiveId,Isnull(orm.Amount1,0) - Isnull(orm.Amount2,0) Amount
					   from(
							select OtherReceiveId,sum(Amount) Amount1,NULL Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 0
							group by OtherReceiveId
						
							union all 

							select OtherReceiveId,NULL Amount1,sum(Amount) Amount2
							from OtherReceiveLines
							where AcctCode in (41000102,41000202,41000302,41000402,41000502,41000602,41000700,41000701,41000702,41000703,41000704,41000705,41000707,41000708)
									and isDebit = 1
							group by OtherReceiveId
							) orm
						   ) orm on o.Id = orm.OtherReceiveId
			where o.Date  <= @Todate
					and i.DocStatus not in (-1,5)
					and o.DocStatus not in (-1)
					and o.SubDocTypeId in (609)
			group by orgP.Id,orgP.TaxType,o.LocationId
			) ors on org.Id = ors.LocationId
where (exists (select 1 from @OrgId a where org.Id = a.Id) or @ProjectId is null)

)o order by o.[Code(2)]
/************************************************************************************************************************************************************************/

/*2-Filter*/
select @Todate [As Of Date]
		--,@ProjectId
		,(SELECT dbo.GROUP_CONCAT(code)  FROM dbo.Organizations WHERE Id in (SELECT ncode FROM dbo.fn_listCode(@ProjectId))) Project
		,IIF(@IncChild = 1,'Include Child','NO') IncChild

/************************************************************************************************************************************************************************/

/*3-Company*/
select * from fn_CompanyInfoTable(@ProjectId)