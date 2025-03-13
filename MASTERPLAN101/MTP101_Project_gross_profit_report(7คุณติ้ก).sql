/*==> Ref:d:\site\erp\notpublish\customprinting\reportcommands\mtp101_project_gross_profit_report.sql ==>*/

/*รายงานกำไรขั้นต้น รายโครงการ*/

DECLARE @p0 DATETIME = '2025-03-04'
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

		select po.PaidProjectId,po.TypeVat
					,sum(po.pamount) [POTaxbase]
					,IIF(po.TypeVat != 131,sum(po.pamount) * 1.07,sum(po.pamount)) [POAmount]	
		from(

				/*จ่ายค่าของ Invoice,payment */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode,vat.SystemCategoryId TypeVat,vat.SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM InvoiceLines il
					WHERE il.InvoiceId = acl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId IN (37,213) /* จับทั้ง INAP,INPA ที่ allocate เข้า budgetline ที่เป็น mat */
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 50 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode
				
				union all
-- 				/*จ่ายค่าของ AdjustInvoice,payment */

				SELECT ccl.CommittedProjectId [PaidProjectId],ccl.[Date],p.Code [PaidDocCode],ccl.RefDocCode,vat.SystemCategoryId [TypeVat],vat.SystemCategory,sum(ccl.Amount) pamount
				from Payments p
				INNER JOIN PaymentLines pl ON p.Id = pl.PaymentId
				INNER JOIN CommittedCostLines ccl ON pl.DocId = ccl.RefDocId AND RefDocTypeId = 39
				INNER JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM AdjustInvoiceLines il
					WHERE il.AdjustInvoiceId = ccl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 39
					GROUP BY SystemCategoryId, SystemCategory 
				) vat

				where ccl.CommittedProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pl.SystemCategoryId = 39 and ccl.Date <= @Todate --AND pl.DocId = 7
						
				group by ccl.CommittedProjectId,ccl.[Date],p.Code,vat.SystemCategoryId,vat.SystemCategory,ccl.RefDocCode

				union all
				/*จ่ายค่าของ WorkerExpenses */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				LEFT JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM WorkerExpenseLines wel
					WHERE wel.WorkerExpenseId = pcl.RefDocId AND wel.SystemCategoryId IN (123,129,131) 
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ WE มีทำ multi vat */

				) vat
				where PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 97 and pcl.Date <= @Todate --AND pcl.RefDocId = 70

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory

				union all
				/*จ่ายค่าของ JV  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,'NoVat' SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 64 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713
				Group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode

				union all
				/*จ่ายค่าของ OP  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherPaymentLines opl
					WHERE opl.OtherPaymentId = acl.RefDocId AND opl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 43
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 43 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode
				
				union all
				/* รับเงินคืนจาก OR  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherReceiveLines orl
					WHERE orl.OtherReceiveId = acl.RefDocId AND orl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 44
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 99 AND pcl.RefDocTypeId = 44 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode

				union all
				/*จ่ายค่าของ ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 99
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory )po group by po.PaidProjectId,po.TypeVat
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

		select po.PaidProjectId,po.TypeVat
					,sum(po.pamount) [POTaxbase]
					,IIF(po.TypeVat != 131,sum(po.pamount) * 1.07,sum(po.pamount)) [POAmount]	
		from(

				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],acl.RefDocCode,vat.SystemCategoryId TypeVat,vat.SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM InvoiceLines il
					WHERE il.InvoiceId = acl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId IN (37,213) /* จับทั้ง INAP,INPA ที่ allocate เข้า budgetline ที่เป็น mat */
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 50 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode
				
				union all
-- 				/*จ่ายค่าของ AdjustInvoice,payment */

				SELECT ccl.CommittedProjectId [PaidProjectId],ccl.[Date],p.Code [PaidDocCode],ccl.RefDocCode,vat.SystemCategoryId [TypeVat],vat.SystemCategory,sum(ccl.Amount) pamount
				from Payments p
				INNER JOIN PaymentLines pl ON p.Id = pl.PaymentId
				INNER JOIN CommittedCostLines ccl ON pl.DocId = ccl.RefDocId AND RefDocTypeId = 39
				INNER JOIN BudgetLines bl ON ccl.BudgetLineId = bl.Id
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM AdjustInvoiceLines il
					WHERE il.AdjustInvoiceId = ccl.RefDocId AND il.SystemCategoryId IN (123,129,131) AND ccl.RefDocTypeId = 39
					GROUP BY SystemCategoryId, SystemCategory 
				) vat

				where ccl.CommittedProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pl.SystemCategoryId = 39 and ccl.Date <= @Todate --AND pl.DocId = 7
						
				group by ccl.CommittedProjectId,ccl.[Date],p.Code,vat.SystemCategoryId,vat.SystemCategory,ccl.RefDocCode

				union all
				/*จ่ายค่าของ WorkerExpenses */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				LEFT JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM WorkerExpenseLines wel
					WHERE wel.WorkerExpenseId = pcl.RefDocId AND wel.SystemCategoryId IN (123,129,131) 
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ WE มีทำ multi vat */

				) vat
				where PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 97 and pcl.Date <= @Todate --AND pcl.RefDocId = 70

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory

				union all
				/*จ่ายค่าของ JV  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,'NoVat' SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 64 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713
				Group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode

				union all
				/*จ่ายค่าของ OP  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherPaymentLines opl
					WHERE opl.OtherPaymentId = acl.RefDocId AND opl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 43
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 43 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode

				union all
				/* รับเงินคืนจาก OR  */
				SELECT pcl.PaidProjectId,pcl.Date,pcl.RefDocCode [PaidDocCode],NULL RefDocCode
						,ISNULL(vat.SystemCategoryId,131) TypeVat
						,ISNULL(vat.SystemCategory,'NoVat') SystemCategory,SUM(pcl.Amount) pamount
				from PaidCostLines pcl
				INNER JOIN BudgetLines bl ON pcl.BudgetLineId = bl.Id
				INNER JOIN AccountCostLines acl ON acl.Id = pcl.AccountCostLineId
				OUTER APPLY( 
					SELECT SystemCategoryId, SystemCategory FROM OtherReceiveLines orl
					WHERE orl.OtherReceiveId = acl.RefDocId AND orl.SystemCategoryId IN (123,129,131) AND acl.RefDocTypeId = 44
					GROUP BY SystemCategoryId, SystemCategory /* เผื่อ invoice มีทำ multi vat */

				) vat
				where pcl.PaidProjectId = @ProjectId AND bl.SystemCategoryId = 105 AND pcl.RefDocTypeId = 44 and pcl.Date <= @Todate --AND pcl.RefDocId = 1713

				group by pcl.PaidProjectId,pcl.Date,pcl.RefDocCode,vat.SystemCategoryId,vat.SystemCategory,acl.RefDocCode

				union all
				/*จ่ายค่าของ ProhibitedTax NOPayment  */
				select pd.PaidProjectId,pd.Date,pd.RefDocCode [PaidDocCode],NULL RefDocCode,131 TypeVat,bu.SystemCategory,sum(pd.Amount) pamount
				from Invoices i
				left join ProhibitedTaxItems ph on i.Code = ph.SetDocCode
				left join ProhibitedTaxes p on ph.ProhibitedTaxId = p.Id
				inner join PaymentLines pl on ph.SetDocCode = pl.DocCode
				left join PaidCostLines pd on p.Code = pd.RefDocCode 
				left join BudgetLines bu on pd.BudgetLineId = bu.Id
				where  bu.SystemCategoryId = 105
						and pd.Date <= @Todate
						
				group by pd.PaidProjectId,pd.Date,pd.RefDocCode,bu.SystemCategory )po group by po.PaidProjectId,po.TypeVat

		) po
		group by po.PaidProjectId
)po 
option(recompile);
/************************************************************************************************************************************************************************/


/*1-core*/
SELECT o.Id
		,o.[Code(2)]
		,o.[Name(3)]
		,o.OriginalContractNO
		,o.[OriginalContractAmount(4)]
		,o.VODate
		,o.[VOAmount(5)]
		,o.[CurrentContractAmount(6)]
		,o.ContractNO
		,o.[RVOriginalContract TaxBase(7)]
		,o.[RVVOContract TaxBase(8)]
		,o.[RVTotal TaxBase(9)]
		,o.[Current Budget Mat(10)]
		,o.[Current Budget Sub(11)]
		,o.[MatPay Taxbase(12)]
		,o.[SupPay Taxbase(13)]
		,o.[PVTotal Taxbase(14)]
		,o.[Gross profit Taxbase(15)]
		,o.[ReMainContract Taxbase(16)]
		,o.[PORemainTaxbase(17)]
		,o.[SCRemainTaxbase(18)]
		,o.[TotalRemainTaxbase(19)]
		,o.[BudgetRemainMat(20)]
		,o.[BudgetRemainSub(21)]
		,o.[BudgetRemain(22)]
		,o.[EstCostPaidTaxbase(23)]
		,o.[Est Gross profit Taxbase(24)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit Taxbase(25)]),'%') [% Est Gross profit Taxbase(25)] 
		,o.[JvAmount Taxbase(26)]
		,o.[Est Gross profit and loss minus internal rent(27)]
		,CONCAT(convert(decimal(12,2),o.[% Est Gross profit and loss minus internal rent(28)]),'%') [% Est Gross profit and loss minus internal rent(28)]

FROM(

	select	org.Id
		,org.Code [Code(2)] /*(2)*/
		,org.Name [Name(3)]/*(2)*/
		,orgP.ContractNO [OriginalContractNO] 
		,(ISNULL(orgP.ContractAmount,0) * 100 / 107) [OriginalContractAmount(4)] /*(4)*/
		,pvo.VOcontractdate [VODate]
		,ISNULL(pvo.VOSUM,0) [VOAmount(5)] /*(5)*/
		,(ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) [CurrentContractAmount(6)]  /*(6) = (4)+(5)*/
		,m.ContractNO

		--,ISNULL(m.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/
		,ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) [RVOriginalContract TaxBase(7)] /*(7)*/

		--,ISNULL(s.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/
		,ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0) [RVVOContract TaxBase(8)] /*(8)*/

		--,(ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [RVTotal TaxBase(9)]  /*(9) = (7)+(8)*/

		,ISNULL(BRMat.BlMatAmount,0) [Current Budget Mat(10)] /*(10)*/
		,ISNULL(BRSub.BlSubAmount,0) [Current Budget Sub(11)] /*(11)*/
		,ISNULL(mp.POTaxbase,0) [MatPay Taxbase(12)] /*(12)*/
		,ISNULL(sp.POTaxbase,0) [SupPay Taxbase(13)] /*(13)*/
		,ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0) [PVTotal Taxbase(14)]  /*(14) = (12)+(13)*/

		--,((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		--,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/
		,(ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))) [Gross profit Taxbase(15)] /*(15) = (9)-(14)*/

		--,((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0))) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		--,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0)) + ISNULL(s.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/
		,((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) [ReMainContract Taxbase(16)]  /*(16) = (6)-(9)*/

		,ISNULL(PORemain.PORemainTaxbase,0) [PORemainTaxbase(17)] /*(17)*/
		,ISNULL(SCRemain.SCRemainTaxbase,0) [SCRemainTaxbase(18)] /*(18)*/
		,ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0) [TotalRemainTaxbase(19)] /*(19)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) [BudgetRemainMat(20)] /*(20)*/
		,ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0) [BudgetRemainMat(20)] /*(20) = (10)-(12)-(17)*/

		--,ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemainSub(21)] /*(21)*/
		,ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0) [BudgetRemainSub(21)] /*(21) = (11)-(13)-(18)*/

		--,ISNULL(BRMat.BudgetRemainMat,0) + ISNULL(BRSub.BudgetRemainSub,0) [BudgetRemain(22)] /*(22) = (20)+(21)*/
		,(ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) /*(20)*/
		 + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) /*(21)*/
		 [BudgetRemain(22)] /*(22) = (20)+(21)*/

		--,ISNULL((ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0)) + (BRMat.BudgetRemainMat + BRSub.BudgetRemainSub),0) [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/
		,(ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))  /*(19)*/
		  +( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		     + (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ) /*(22)*/
		  [EstCostPaidTaxbase(23)] /*(23) =(19)+(22)*/


		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--		+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--		+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/

		,((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0)))) /*(15)*/
			+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
			[Est Gross profit Taxbase(24)] /*(24) = (15)+(16)-(23)*/


		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--	  ELSE	ROUND(ISNULL((((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) /*(6)*/
		--			/ ((((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0)))  /*(15)*/
		--			+ ((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) ,0),2)/*(23)*/ 
		--	END [% Est Gross profit Taxbase(25)] /*(25) = (6) / ((15)+(16)-(23))*/

		,CASE WHEN ( (ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
			  ELSE	ROUND(ISNULL(
								(( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
									+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
									- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
										+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
										+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) /*(23)*/
							/ ((ISNULL(orgP.ContractAmount,0) * 100 / 107) + ISNULL(pvo.VOSUM,0))) ,0),2)/*(6)*/ 
			END [% Est Gross profit Taxbase(25)] /*(25) = (24) / (6) */


		,ISNULL(jl.JvAmount,0) [JvAmount Taxbase(26)] /*(26)*/

		--,(((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--	+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--	- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--	- ISNULL(jl.JvAmount,0) /*(26)*/
		--      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/

		,( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
			+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) /*(23)*/ 
			- ISNULL(jl.JvAmount,0) /*(26)*/
		      [Est Gross profit and loss minus internal rent(27)] /*(27) = (15)+(16)-(23)-(26)*/

		--,CASE WHEN ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
		--		ELSE ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) /*(6)*/
		--			/ ( (((ISNULL(m.TaxBase,0) + ISNULL(s.TaxBase,0))) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
		--			+ (((ISNULL(orgP.ContractAmount,0) + ISNULL(pvo.VOSUM,0))) - ((ISNULL(m.TaxAmount,0) + ISNULL(s.TaxBase,0)))) /*(16)*/
		--			- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
		--				+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
		--				+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) )) /*(23)*/ 
		--			- ISNULL(jl.JvAmount,0) )  /*(26)*/
		--		END [% Est Gross profit and loss minus internal rent(28)] /*(28) = (6) / (15)+(16)-(23)-(26)*/

		,CASE WHEN ( (ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0) ) = 0 THEN 0
				ELSE  (( ((ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0)) - ((ISNULL(mp.POTaxbase,0) + ISNULL(sp.POTaxbase,0))))  /*(15)*/
							+ (((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) - (ISNULL(m.TaxBase,0) + ISNULL(ir.IrTaxBase,0) + ISNULL(ac.BFTaxbase,0) + ISNULL(orm.TaxBase,0) + ISNULL(s.TaxBase,0) + ISNULL(irv.IrVoTaxBase,0) + ISNULL(ors.TaxBase,0))) /*(16)*/
							- ( (ISNULL(PORemain.PORemainTaxbase,0) + ISNULL(SCRemain.SCRemainTaxbase,0))
								+ ( (ISNULL(BRMat.BlMatAmount,0) - ISNULL(mp.POTaxbase,0) - ISNULL(PORemain.PORemainTaxbase,0)) 
								+ (ISNULL(BRSub.BlSubAmount,0) - ISNULL(sp.POTaxbase,0) - ISNULL(SCRemain.SCRemainTaxbase,0)) ))) /*(23)*/ 
							- ISNULL(jl.JvAmount,0))
					/ ((ISNULL(orgP.ContractAmount,0)* 100 / 107) + ISNULL(pvo.VOSUM,0)) /*(6)*/
				END [% Est Gross profit and loss minus internal rent(28)] /*(28) = (27) / (6)*/
				
from	Organizations org
left join Organizations_ProjectConstruction orgP on org.Id = orgP.id
left join (	select SUM(isnull(ContractAmount,0)* 100 / 107) VOSUM,
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
left join (select bm.ProjectId,bm.Date,(bm.BlMatAmount * 100 / 107) BlMatAmount,bm.UseMatAmount,((bm.BlMatAmount * 100 / 107)-bm.UseMatAmount) [BudgetRemainMat]
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
/*JV 41000716 : รายได้ค่าเช่าภายใน*/
left join (select jl.OrgId,sum(isnull(jl.Amount,0)) JvAmount
			from JVLines jl
                        left join JournalVouchers j on j.Id = jl.JournalVoucherId
			where j.Date  <= @Todate
                                        and jl.AccountCode in (41000716)
					and jl.isDebit = 1
			group by jl.OrgId
			) jl on org.Id = jl.OrgId

/*Interrim BF*/
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
			where ac.DocTypeId = 149 and ac.AccountCode = '11130101'
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