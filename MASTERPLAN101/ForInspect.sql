/*==> Ref:d:\site\erp\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/

/*รายงานกำไรขั้นต้น รายโครงการ*/

DECLARE @p0 DATETIME = '2025-02-21'
DECLARE @p1 nvarchar(500) = '143'--'1931'--'1107,1152' --''--
DECLARE @p2 BIT = 1

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
				,case when po.DocType = 22 then (po.InvoiceAmount - po.DiscountInvAmount - po.AdjustInvoiceAmount)  - (po.PayAmount + po.PaycnAmount)
					 when po.DocType = 43 then  (po.POAmount - po.AdjustInvoiceAmount)  - po.PayAmount
					 End Notpay
				from( 
					/*PO ExtVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rl.RSAmount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) * 100 / 107 PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) * 100 / 107 PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId 
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					left join (select r.Id,r.RefDocId,sum(rl.Amount) RSAmount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1)
								group by r.Id,r.RefDocId
								)rl on p.Id = rl.RefDocId
					left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il2.DiscountInvAmount) DiscountInvAmount
								from Invoices i
								left join InvoiceLines il on i.Id = il.InvoiceId
								left join (select il.InvoiceId,sum(il.Amount) DiscountInvAmount
											from InvoiceLines il
											where il.SystemCategoryId = 124
											group by il.InvoiceId
											) il2 on il.InvoiceId = il2.InvoiceId
								where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
								group by i.Code,il.RefDocCode2
								)il on p.Code = il.RefDocCode2
					left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
								from AdjustInvoices c
								left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
								where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
								group by c.Code,cl.RefDocCode
								)cn on il.Code = cn.RefDocCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pl1 on il.Code = pl1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pl2 on il.Code = pl2.InvoiceAPCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pn1 on cn.Code = pn1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pn2 on cn.Code = pn2.InvoiceAPCode
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 123 
							

					union all
					/*PO IncVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rl.RSAmount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					left join (select r.Id,r.RefDocId,sum(rl.Amount) RSAmount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1)
								group by r.Id,r.RefDocId
								)rl on p.Id = rl.RefDocId
					left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il2.DiscountInvAmount) DiscountInvAmount
								from Invoices i
								left join InvoiceLines il on i.Id = il.InvoiceId
								left join (select il.InvoiceId,sum(il.Amount) DiscountInvAmount
											from InvoiceLines il
											where il.SystemCategoryId = 124
											group by il.InvoiceId
											) il2 on il.InvoiceId = il2.InvoiceId
								where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
								group by i.Code,il.RefDocCode2
								)il on p.Code = il.RefDocCode2
					left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
								from AdjustInvoices c
								left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
								where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
								group by c.Code,cl.RefDocCode
								)cn on il.Code = cn.RefDocCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pl1 on il.Code = pl1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pl2 on il.Code = pl2.InvoiceAPCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pn1 on cn.Code = pn1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pn2 on cn.Code = pn2.InvoiceAPCode
					where p.Date <= @Todate
							and p.DocStatus not in (-1) 
							and pl.SystemCategoryId = 129
							

					union all
					/*PO NOVat*/
					select p.LocationId,p.Id,p.Code,22 DocType,p.Date,pl.SystemCategoryId
					,isnull(b1.POAmount,0) POAmount
					,isnull(ajl.AdjustAmount,0) AdjustAmount
					,isnull(rl.RSAmount,0) RSAmount
					,isnull(il.InvoiceAmount,0) InvoiceAmount
					,isnull(il.DiscountInvAmount,0) DiscountInvAmount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) PaycnAmount
					from POes p
					left join POLines pl on p.Id = pl.POId
					left join (select b.POId,b.SystemCategoryId,SUM(b.Amount) POAmount
								from POLines b
								where b.SystemCategoryId = 99
								group by b.POId,b.SystemCategoryId
								) b1 on p.Id = b1.POId
					left join (select aj.POId,ABS(sum(ajl.AdjustAmount)) AdjustAmount
								from AdjustPOes aj
								left Join AdjustPOLines ajl on aj.Id = ajl.AdjustPOId
								where ajl.SystemCategoryId = 99 and aj.DocStatus not in (-1) 
								group by aj.POId
								)ajl on p.Id = ajl.POId
					left join (select r.Id,r.RefDocId,sum(rl.Amount) RSAmount
								from ReceiveSuppliers r
								left Join ReceiveSupplierLines rl on r.Id = rl.ReceiveSupplierId
								where rl.SystemCategoryId = 99 and r.DocStatus not in (-1)
								group by r.Id,r.RefDocId
								)rl on p.Id = rl.RefDocId
					left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il2.DiscountInvAmount) DiscountInvAmount
								from Invoices i
								left join InvoiceLines il on i.Id = il.InvoiceId
								left join (select il.InvoiceId,sum(il.Amount) DiscountInvAmount
											from InvoiceLines il
											where il.SystemCategoryId = 124
											group by il.InvoiceId
											) il2 on il.InvoiceId = il2.InvoiceId
								where il.SystemCategoryId = 99 and i.DocStatus not in (-1)
								group by i.Code,il.RefDocCode2
								)il on p.Code = il.RefDocCode2
					left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
								from AdjustInvoices c
								left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
								where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
								group by c.Code,cl.RefDocCode
								)cn on il.Code = cn.RefDocCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (37,39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pl1 on il.Code = pl1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pl2 on il.Code = pl2.InvoiceAPCode
					left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.DocCode
								)pn1 on cn.Code = pn1.DocCode 
					left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
								from Payments p
								left join PaymentLines pl on p.Id = pl.PaymentId
								where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
								group by p.id,pl.InvoiceAPCode
								)pn2 on cn.Code = pn2.InvoiceAPCode
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
				,case when sc.DocType = 105 then (sc.InvoiceAmount - sc.SpecialDiscount - sc.AdjustInvoiceAmount)  - (sc.PayAmount + sc.PaycnAmount)
					 when sc.DocType = 43 then  (sc.SCAmount - sc.AdjustInvoiceAmount) - sc.PayAmount
					 End Notpay
					
	from(
			/*SC ExtVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) * 100 / 107  PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) * 100 / 107 PaycnAmount
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
								left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il.SpecialDiscount) SpecialDiscount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 105 and i.DocStatus not in (-1)
											group by i.Code,il.RefDocCode2
											)il on s.Code = il.RefDocCode2
								left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Code,cl.RefDocCode
											)cn on il.Code = cn.RefDocCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0) + Isnull(sum(pl.RetentionSetAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pl1 on il.Code = pl1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pl2 on il.Code = pl2.InvoiceAPCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pn1 on cn.Code = pn1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on cn.Code = pl2.InvoiceAPCode
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 123
										
			union all
			/*SC IncVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) PaycnAmount
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
								left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il.SpecialDiscount) SpecialDiscount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 105 and i.DocStatus not in (-1)
											group by i.Code,il.RefDocCode2
											)il on s.Code = il.RefDocCode2
								left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Code,cl.RefDocCode
											)cn on il.Code = cn.RefDocCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0) + Isnull(sum(pl.RetentionSetAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pl1 on il.Code = pl1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pl2 on il.Code = pl2.InvoiceAPCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pn1 on cn.Code = pn1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on cn.Code = pl2.InvoiceAPCode
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 129
										
			union all
			/*SC NOVat*/
			select s.LocationId,s.Id,105 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(sul.SCAmount,0) SCAmount
					,isnull(p.RetentionAmount,0) RetentionAmount,isnull(p.WHTAmount,0) WHTAmount,isnull(p.DeductionRecordDocAmount,0) DeductionRecordDocAmount
					,isnull(v.AdjustCostAmount,0) AdjustCostAmount,isnull(il.InvoiceAmount,0) InvoiceAmount,isnull(il.SpecialDiscount,0) SpecialDiscount
					,isnull(cn.AdjustInvoiceAmount,0) AdjustInvoiceAmount
					,isnull(pl1.PayAmount1,(isnull(pl2.PayAmount2,0))) PayAmount
					,isnull(pn1.PayAmount1,(isnull(pn2.PayAmount2,0))) PaycnAmount
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
								left join (select i.Code,il.RefDocCode2,sum(il.Amount) InvoiceAmount,sum(il.SpecialDiscount) SpecialDiscount
											from Invoices i
											left join InvoiceLines il on i.Id = il.InvoiceId
											where il.SystemCategoryId = 105 and i.DocStatus not in (-1)
											group by i.Code,il.RefDocCode2
											)il on s.Code = il.RefDocCode2
								left join (select c.Code,cl.RefDocCode,sum(cl.AdjustTaxBase) AdjustInvoiceAmount
											from AdjustInvoices c
											left join AdjustInvoiceLines cl on c.Id = cl.AdjustInvoiceId
											where cl.SystemCategoryId in (152,153) and c.DocStatus not in (-1)
											group by c.Code,cl.RefDocCode
											)cn on il.Code = cn.RefDocCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0) + Isnull(sum(pl.RetentionSetAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (213) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pl1 on il.Code = pl1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pl2 on il.Code = pl2.InvoiceAPCode
								left join (select p.id,pl.DocCode,Isnull(sum(pl.PayAmount),0)  PayAmount1
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (39) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.DocCode
											)pn1 on cn.Code = pn1.DocCode 
								left join (select p.id,pl.InvoiceAPCode,Isnull(sum(pl.PayAmount),0) PayAmount2
											from Payments p
											left join PaymentLines pl on p.Id = pl.PaymentId
											where pl.SystemCategoryId in (142) and p.DocStatus not in (-1) and p.DocTypeId in (50)
											group by p.id,pl.InvoiceAPCode
											)pn2 on cn.Code = pl2.InvoiceAPCode
								where s.Date <= @Todate
										and s.DocStatus not in (-1) 
										and sl.SystemCategoryId = 131
										
			union all
			
			/*OP ExtVat*/					
			select s.LocationId,s.Id,43 Doctype,s.Code,s.Date,sl.SystemCategoryId,isnull(b1.POAmount,0) SCAmount
					,isnull(NULL,0) RetentionAmount,isnull(NULL,0)  WHTAmount,isnull(NULL,0)  DeductionRecordDocAmount
					,0 AdjustCostAmount,0 InvoiceAmount ,0 SpecialDiscount
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

				union all
				/*ค่าของ OP ตั้งหนี้และจ่าย*/
				select b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId TypeVat,bl.SystemCategory,sum(pd.Amount) pamount
				from Budgets b
				left join BudgetLines bl on b.Id = bl.BudgetId
				left join PaidCostLines pd on bl.Id = pd.BudgetLineId
				inner join OtherPayments o on pd.RefDocCode = o.Code
				inner join OtherPaymentLines ol on o.Code = ol.RefDocCode
				inner join OtherPayments oo on ol.RefDocCode = oo.Code
				inner join OtherPaymentLines oll on oo.Id = oll.OtherPaymentId
				where bl.SystemCategoryId = 99
						and oll.SystemCategoryId in (123,129,131)
										and pd.Date <= @Todate
										and pd.RefDocTypeId in (43)
										and o.SubDocTypeId  in (629,630)
				group by b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId,bl.SystemCategory

				union all
				/*จ่ายค่าของ ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory
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

				union all
				/*จ่ายค่าแรง OP ตั้งหนี้และจ่าย*/
				select b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId TypeVat,bl.SystemCategory,sum(pd.Amount) pamount
				from Budgets b
				left join BudgetLines bl on b.Id = bl.BudgetId
				left join PaidCostLines pd on bl.Id = pd.BudgetLineId
				inner join OtherPayments o on pd.RefDocCode = o.Code
				inner join OtherPaymentLines ol on o.Code = ol.RefDocCode
				inner join OtherPayments oo on ol.RefDocCode = oo.Code
				inner join OtherPaymentLines oll on oo.Id = oll.OtherPaymentId
				where bl.SystemCategoryId = 105
						and oll.SystemCategoryId in (123,129,131)
										and pd.Date <= @Todate
										and pd.RefDocTypeId in (43)
										and o.SubDocTypeId  in (629,630)
				group by b.ProjectId,o.Date,pd.RefDocCode,oll.SystemCategoryId,bl.SystemCategory

				union all
				/*จ่ายค่าแรง ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory

				)po
				group by po.PaidProjectId,po.TypeVat
		) po
		group by po.PaidProjectId
)po 