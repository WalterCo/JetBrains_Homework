# JetBrains_Homework_Walter Colombu

## Task 1 - Data quality – the difference between NetSuite ERP and payment gateway

The first thing I have done with this task was to merge together all the CSV files that I have got with it. It took only few seconds thanks to a freeware excel extension called "RDB Merge". 
I have imagined myself in the situation of having to provide this data to the finance team in order for them to review the transactions and update the wrong ones. So, once the CSV files were merged, I have uploaded them into my database (dbfour) and started thinking of the best way to flag inconsistencies between the csv data and the MySQL database. 

Unfortunately I didn't have a unique ID that I could have used to link the data properly, so I have decided to **create a query that summarized the total for NetSuite and Paymeny Gateway by Order_ref** this way I could easily identify which orders had some discrepancies in the payments. 

```
SELECT *
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
GROUP BY Netsuite_Data.ORDER_REF) AS Comparison;
```
I have placed the query results with an actual difference in the table **"Orders_With_Wrong_Transactions"**, This way I had the criteria to identify where finance would have to go and review the transactions.
```
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
```
I have converted all the amounts to positive for simplicity and left out the "Accounts Receivable" and "Deferred Revenue" as they are supposed to cancel each other, which they were, they weren't relevant for the search of discrepancies. Once the table was completed, I have ran a quantity of random checks to make sure that those records were actually for orders with wrong transactions:
```
SELECT
trans.ORDER_REF,
CASE
	WHEN tralin.AMOUNT_FOREIGN < 0 THEN tralin.AMOUNT_FOREIGN*-1
	ELSE tralin.AMOUNT_FOREIGN
END AS NetSuite
FROM bi.netsuite.TRANSACTIONS trans
JOIN bi.netsuite.TRANSACTION_LINES tralin ON trans.TRANSACTION_ID = tralin.TRANSACTION_ID
JOIN bi.netsuite.ACCOUNTS acc ON tralin.ACCOUNT_ID = acc.ACCOUNT_ID
WHERE acc.FULL_NAME != 'Accounts Receivable' AND acc.FULL_NAME != 'Deferred Revenue' AND trans.ORDER_REF='E000015977'
ORDER BY trans.ORDER_REF ASC;

SELECT
csv.ORDER_REF,
IIF(csv.NET<0,csv.NET*-1,csv.NET) AS Net_For_Calculations,
IIF(csv.FEE<0,csv.FEE*-1,csv.FEE) AS Fee_For_Calculations,
IIF(csv.GROSS<0,csv.GROSS*-1,csv.GROSS) AS Gross_For_Calculations
FROM dbfour.dbo.[Adyen Data Combined] csv
WHERE csv.ORDER_REF = 'E000015977'
ORDER BY csv.ORDER_REF ASC;
```
With the above query I was comparing the output by ORDER_REF. In the order E000015977 as you can see on the below screenshot:

![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Order%20with%20wrong%20transactions.PNG?raw=true)

It looks like we have only the "FEE" portion processed in NetSuite on opposite of Payment Gateway where we have Net and fee.
Finally, I have wrapped it up in the below query where I also double check the currency to make sure that it matches:

```
Select
trans.Order_Ref,
trans.transaction_id,
trans.Transaction_Type,
curr.SYMBOL AS NetSuite_Currency,
SUM(Distinct tralin.AMOUNT_FOREIGN)AS NetSuite,
csv.CURRENCY,
SUM(Distinct csv.GROSS) AS Payment_Gateway,
(SUM(Distinct csv.GROSS)-SUM(Distinct tralin.AMOUNT_FOREIGN)) AS Difference,
IIF(curr.SYMBOL=csv.CURRENCY,'Currency Match','Please review currency info') AS Currency_Comparison
FROM bi.netsuite.TRANSACTIONS trans
JOIN bi.netsuite.TRANSACTION_LINES tralin ON trans.TRANSACTION_ID = tralin.TRANSACTION_ID
JOIN bi.netsuite.ACCOUNTS acc ON acc.ACCOUNT_ID = tralin.ACCOUNT_ID
JOIN dbfour.dbo.[Adyen Data Combined] csv ON csv.ORDER_REF = trans.ORDER_REF
JOIN bi.netsuite.CURRENCIES curr ON curr.CURRENCY_ID = trans.CURRENCY_ID
WHERE 
acc.FULL_NAME <> 'Deferred Revenue' AND
acc.FULL_NAME <> 'Accounts Receivable' AND
trans.Order_Ref IN 
	(SELECT  Owwt.ORDER_REF FROM dbfour.dbo.Orders_With_Wrong_Transactions Owwt) AND
csv.Order_Ref IN 
		(SELECT  Owwt.ORDER_REF FROM dbfour.dbo.Orders_With_Wrong_Transactions Owwt) 
GROUP BY
trans.Order_Ref,
trans.transaction_id,
trans.Transaction_Type,
curr.SYMBOL,
csv.CURRENCY
ORDER BY trans.Order_Ref ASC;
```

## Task 2: Sale analysis – revenue decline in ROW region

