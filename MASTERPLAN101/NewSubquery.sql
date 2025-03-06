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
select * From RevisedBudgetLines Where RevisedBudgetId = 1404

SELECT * from BudgetLines where BudgetId = 102

-- select TOP 3 * From AccountCostLines 
-- select TOP 3 * From PaidCostLines 