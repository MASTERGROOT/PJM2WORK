DECLARE @MapByPloy INT
SELECT @MapByPloy = COUNT(Id) FROM dbo.MapByPloys
IF(ISNULL(@MapByPloy, 0) = 0)
BEGIN
 INSERT INTO Mapbyploys (PloyValue, PJMValue, Description, Type)
 VALUES 
 (11,184,'Booked','ReceiveBooked'),
 (12,185,'SaleContract','ReceiveContract'),
 (14,186,'DownPayment','ReceiveDownPayment'),
 (15,187,'RightTransfer','ReceiveRightTransfer'),
 (17,188,'OtherExpense','ReceiveOtherExpense'),
 (24,177,'VariationDeal','VariationDeal'),
 (58,58,'CheckReceive','CheckReceive'),
 (72,72,'CreditCard','CreditCard'),
 (61,59,'BankDeposit','BankAcct'),
 (60,60,'CashAcct','CashAcct'),
 (13,186,'DownPayment','ReceiveDownPayment'),
 (18,0,'FeeChange',''),
 (21,187,'DiscountAtTransferDate','ReceiveRightTransfer'),
 (19,124,'Discount','PromotionDiscount')
END

select * from dbo.MapByPloys