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

The main thing I have decided to check was that the currency conversion was done right and, of course, it was, however, this made me realize the main reason for the decline of the revenue which was the exchange rate:
```
SELECT cou.region,
	AVG(CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END) as RateTo_Usd2018H1,
	AVG(CASE WHEN YEAR(ord.exec_date) = 2019 THEN exRate.rate ELSE 0.00 END) as RateTo_Usd2019H1,
	((AVG(CASE WHEN YEAR(ord.exec_date) = 2019 THEN exRate.rate ELSE 0.00 END)-
	 AVG(CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END))/
	 AVG(CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END))*100 as rate_difference_perc
FROM bi.sales.Orders ord
JOIN bi.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN bi.sales.Customer cust ON ord.customer = cust.id
JOIN bi.sales.Country cou ON cust.country_id = cou.id
JOIN bi.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN bi.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
  AND YEAR(ord.exec_date) IN (2018, 2019) -- Year 2018, 2019
  AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
GROUP BY cou.region
ORDER BY 1
;
```
This query shows how there is an increment by 6.4% in the average exchange rate from 2018 H1 to 2019 H1 which is the primary cause of the decline since we are looking at units per USD. After noticing that the currency was playing a significant factor, I have then summarized the data in two tables: one for 2018 and one for 2019.

```
SELECT cou.region,
  ordItm.PRODUCT_ID,
  prod.NAME AS Product,
  ordItm.license_type,
  cou.NAME AS Country,
  exRate.rate,
  Ord.Currency,
  CASE WHEN YEAR(ord.exec_date) = 2018 THEN (ordItm.Price_Item) ELSE 0.00 END As '2018_Price_Item',
  COUNT(DISTINCT CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.order_id END) as Orders_2018_H1,
  SUM( CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.quantity END) as Quantity_2018_H1,
  SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total ELSE 0.00 END) as Sales_2018_H1
INTO T_2018
FROM bi.sales.Orders ord
JOIN bi.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN bi.sales.Customer cust ON ord.customer = cust.id
JOIN bi.sales.Country cou ON cust.country_id = cou.id
JOIN bi.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN bi.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
  AND YEAR(ord.exec_date) IN (2018) -- Year 2018
  AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
GROUP BY cou.region,ordItm.PRODUCT_ID,prod.NAME, cou.NAME, ordItm.license_type, ord.exec_date, ordItm.Price_Item, exRate.rate,  Ord.Currency
ORDER BY 1

SELECT cou.region,
  ordItm.PRODUCT_ID,
  prod.NAME AS Product,
  ordItm.license_type,
  cou.NAME AS Country,
  exRate.rate,
  Ord.Currency,
  CASE WHEN YEAR(ord.exec_date) = 2019 THEN (ordItm.Price_Item) ELSE 0.00 END As '2019_Price_Item',
  COUNT(DISTINCT CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.order_id END) as Orders_2019_H1,
  SUM( CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.quantity END) as Quantity_2019_H1,
  SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total ELSE 0.00 END) as Sales_2019_H1
INTO T_2019
FROM bi.sales.Orders ord
JOIN bi.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN bi.sales.Customer cust ON ord.customer = cust.id
JOIN bi.sales.Country cou ON cust.country_id = cou.id
JOIN bi.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN bi.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
  AND YEAR(ord.exec_date) IN (2019) -- Year 2019
  AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
GROUP BY cou.region,ordItm.PRODUCT_ID,prod.NAME, cou.NAME, ordItm.license_type, ord.exec_date, ordItm.Price_Item, exRate.rate,  Ord.Currency
ORDER BY 1
```
I have then checked the revenue by country by currency:

```
SELECT 
T_2019.Country,
T_2019.Currency,
T_2019.[2019_Revenue],
T_2018.[2018_Revenue],
(T_2019.[2019_Revenue]-T_2018.[2018_Revenue]) AS Difference,
((T_2019.[2019_Revenue]-T_2018.[2018_Revenue])/T_2018.[2018_Revenue])*100 AS Difference_Percentage

FROM

(SELECT
T_2019.Country,
T_2019.Currency,
SUM(T_2019.Sales_2019_H1) AS '2019_Revenue'
FROM dbfour.dbo.T_2019 T_2019
GROUP BY
T_2019.Country,
T_2019.Currency) T_2019

JOIN

(SELECT
T_2018.Country,
T_2018.Currency,
SUM(T_2018.Sales_2018_H1) AS '2018_Revenue'
FROM dbfour.dbo.T_2018 T_2018
GROUP BY
T_2018.Country,
T_2018.Currency) T_2018 ON T_2019.Country = T_2018.Country;

```
And I have noticed that we only had an actual decline in revenue in New Zealand, Austria and Australia.
![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Revenue%20analysis%20by%20country.PNG?raw=true)

Although as you can see the difference is very low, I have dagged deeper to try to understand which product is not performing that well in those countries:

