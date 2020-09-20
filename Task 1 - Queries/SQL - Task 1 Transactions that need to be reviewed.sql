Select
trans.Order_Ref,
trans.transaction_id,
trans.Transaction_Type,
curr.SYMBOL AS NetSuite_Currency,
SUM(Distinct tralin.AMOUNT_FOREIGN)AS NetSuite
FROM bi.netsuite.TRANSACTIONS trans
JOIN bi.netsuite.TRANSACTION_LINES tralin ON trans.TRANSACTION_ID = tralin.TRANSACTION_ID
JOIN bi.netsuite.ACCOUNTS acc ON acc.ACCOUNT_ID = tralin.ACCOUNT_ID
JOIN bi.netsuite.CURRENCIES curr ON curr.CURRENCY_ID = trans.CURRENCY_ID
WHERE 
acc.FULL_NAME <> 'Deferred Revenue' AND
acc.FULL_NAME <> 'Accounts Receivable' AND
trans.Order_Ref IN 
	(SELECT  Owwt.ORDER_REF FROM dbfour.dbo.Orders_With_Wrong_Transactions Owwt)
GROUP BY
trans.Order_Ref,
trans.transaction_id,
trans.Transaction_Type,
curr.SYMBOL
ORDER BY trans.Order_Ref ASC;