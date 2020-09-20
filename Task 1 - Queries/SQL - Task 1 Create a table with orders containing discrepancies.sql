
SELECT *
INTO Orders_With_Wrong_Transactions
FROM(
SELECT 
Netsuite_Data.ORDER_REF,
SUM(DISTINCT Netsuite_Data.NetSuite) AS Netsuite,
SUM(DISTINCT Order_Data.Gross_For_Calculations) AS Paymeny_Gateway,
(SUM(DISTINCT Netsuite_Data.NetSuite)-SUM(DISTINCT Order_Data.Gross_For_Calculations)) AS Difference
FROM
(SELECT
trans.ORDER_REF,
CASE
	WHEN tralin.AMOUNT_FOREIGN < 0 THEN tralin.AMOUNT_FOREIGN*-1
	ELSE tralin.AMOUNT_FOREIGN
END AS NetSuite
FROM bi.netsuite.TRANSACTIONS trans
JOIN bi.netsuite.TRANSACTION_LINES tralin ON trans.TRANSACTION_ID = tralin.TRANSACTION_ID
JOIN bi.netsuite.ACCOUNTS acc ON tralin.ACCOUNT_ID = acc.ACCOUNT_ID
WHERE acc.FULL_NAME != 'Accounts Receivable' AND acc.FULL_NAME != 'Deferred Revenue') AS Netsuite_Data
INNER JOIN 
(SELECT
csv.ORDER_REF,
IIF(csv.NET<0,csv.NET*-1,csv.NET) AS Net_For_Calculations,
IIF(csv.FEE<0,csv.FEE*-1,csv.FEE) AS Fee_For_Calculations,
IIF(csv.GROSS<0,csv.GROSS*-1,csv.GROSS) AS Gross_For_Calculations
FROM dbfour.dbo.[Adyen Data Combined] csv) Order_Data ON Order_Data.ORDER_REF = Netsuite_Data.ORDER_REF
GROUP BY Netsuite_Data.ORDER_REF) AS Comparison WHERE Comparison.Difference <> 0;