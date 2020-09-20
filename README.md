# JetBrains_Homework_Walter Colombu

## Task 1 - Data quality – the difference between NetSuite ERP and payment gateway

The first thing I have done with this task was to merge together all the CSV files that I have got with it. It took only few seconds thanks to a freeware excel extension called "RDB Merge". 
I have imagined myself in the situation of having to provide this data to the finance team in order for them to review the transactions and update the wrong ones. So, once the CSV files were merged, I have uploaded them into my database (dbfour) and started thinking of the best way to flag inconsistencies between the CSV data and the MySQL database. 

Unfortunately, I didn't have a unique ID that I could have used as a primary key to link the data properly, so I have decided to **create a query that summarized the total for NetSuite and Paymeny Gateway by Order_ref** - this way I could easily identify which orders had some discrepancies in the payments. 

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
I have placed the query results with an actual difference in the table **"Orders_With_Wrong_Transactions"**. This way I had the criteria to identify where finance would have to go and review the transactions.
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
I have converted all the amounts to positive for simplicity and left out the "Accounts Receivable" and "Deferred Revenue" as they cancel each other, therefore, they weren't relevant for the search of discrepancies. Once the table was completed, I have ran a quantity of random checks to make sure that those records were actually for orders with wrong transactions:
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
With the above query I was comparing the outputs by ORDER_REF. In the order E000015977 as you can see on the below screenshot:

![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Order%20with%20wrong%20transactions.PNG?raw=true)

It looks like we have only the "FEE" portion processed in NetSuite whilst in Payment Gateway we have both NET and FEE.
Finally, I have wrapped it up in the below query where I also compare the currency of Netsuite vs the currency of Payment Gateway to make sure that it matches:

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
![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Task%201%20Final%20output.PNG?raw=true)

## Task 2: Sale analysis – revenue decline in ROW region

The main question I asked myself was: In which country do we have the most severe revenue decline? 
Using the amount converted to USD you would notice that for Germany the number of orders and the ordered quantity went up yet the revenue in USD shows a decline which didn't make too much sense to me.
I wondered if there was any difference in price and, indeed, there wasn't. So, given the fact that the price stayed the same, the only logical factor was the exchange rate. I have checked if the currency conversion was done right and, of course, it was; however, this made me realize that the main reason for the decline of the revenue was the exchange rate:
```
SELECT 
	cou.region,
	ord.Currency,
	AVG(Distinct CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END) as RateTo_Usd2018H1,
	AVG(Distinct CASE WHEN YEAR(ord.exec_date) = 2019 THEN exRate.rate ELSE 0.00 END) as RateTo_Usd2019H1,
	((AVG(Distinct CASE WHEN YEAR(ord.exec_date) = 2019 THEN exRate.rate ELSE 0.00 END)-
	 AVG(Distinct CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END))/
	 AVG(Distinct CASE WHEN YEAR(ord.exec_date) = 2018 THEN exRate.rate ELSE 0.00 END))*100 as rate_difference_perc
FROM bi.sales.Orders ord
JOIN bi.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN bi.sales.Customer cust ON ord.customer = cust.id
JOIN bi.sales.Country cou ON cust.country_id = cou.id
JOIN bi.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN bi.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
  AND YEAR(ord.exec_date) IN (2018, 2019) -- Year 2018, 2019
  AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
  AND cou.region != 'US'
  AND ord.Currency != 'USD'
GROUP BY cou.region, ord.currency
ORDER BY 1
;
```
This query shows that there was an increment of 6.4% of the average exchange rate from USD to GBP and an increment of 6.8% of the average exchange rate from USD to EUR  between 2018 H1 and 2019 H1 which is the primary cause of the decline in USD revenue. After establishing that the currency was playing a significant factor, I have summarized the data in two tables: one for 2018 and another one for 2019.

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
And I have noticed that we only had an actual decline in revenue in New Zealand (USD), Austria (EUR) and Australia (USD).

![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Revenue%20analysis%20by%20country.PNG?raw=true)

Although as you can see the difference is very low, I have dagged deeper trying to understand which product is not performing well in those countries:
```
SELECT 
Combined.Country,
Combined.Product,
Combined.Currency,
SUM (CASE WHEN Combined.Year = '2019' THEN Combined.Revenue ELSE 0.00 END) AS '2019 Revenue',
SUM (CASE WHEN Combined.Year = '2018' THEN Combined.Revenue ELSE 0.00 END) AS '2018 Revenue',
(SUM (CASE WHEN Combined.Year = '2019' THEN Combined.Revenue ELSE 0.00 END) -
SUM (CASE WHEN Combined.Year = '2018' THEN Combined.Revenue ELSE 0.00 END)) AS 'Revenue Difference'
FROM 

(SELECT
T_2019.Country,
T_2019.Product,
T_2019.Currency,
'2019' As Year,
SUM(T_2019.Sales_2019_H1) AS 'Revenue',
SUM(T_2019.Quantity_2019_H1) AS 'Quantity Ordered',
SUM(T_2019.Orders_2019_H1) AS 'Total Orders'
FROM dbfour.dbo.T_2019 T_2019
GROUP BY
T_2019.Country,
T_2019.Product,
T_2019.Currency
UNION 
SELECT
T_2018.Country,
T_2018.Product,
T_2018.Currency,
'2018' AS Year,
SUM(T_2018.Sales_2018_H1) AS 'Revenue',
SUM(T_2018.Quantity_2018_H1) AS 'Quantity Ordered',
SUM(T_2018.Orders_2018_H1) AS 'Total Orders'
FROM dbfour.dbo.T_2018 T_2018
GROUP BY
T_2018.Country,
T_2018.Product,
T_2018.Currency) AS Combined


WHERE 
Combined.Country = 'Austria' OR 
Combined.Country = 'Australia' OR
Combined.Country = 'New Zealand'
GROUP BY
Combined.Country,
Combined.Product,
Combined.Currency;
```
Which returned the following output. 
**Please Note:** Marked in RED are the products that show the highest difference and in ORANGE are those that show a small difference:

![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Product%20Revenue%20Analysis%20for%20Austria,%20Australia%20and%20NZ.png?raw=true)

Obviously, this revenue decrease is a result of a decline in orders and quantity of ordered products. Let's see a summary of what have changed in these countries in terms of Orders, Amounts and Revenue with the below query:
```
SELECT 
Combined.Country,
Combined.Product,
Combined.Currency,
(SUM (CASE WHEN Combined.Year = '2019' THEN Combined.Revenue ELSE 0.00 END) -
SUM (CASE WHEN Combined.Year = '2018' THEN Combined.Revenue ELSE 0.00 END)) AS 'Revenue Difference',
(SUM (CASE WHEN Combined.Year = '2019' THEN Combined.[Total Orders] ELSE 0.00 END) -
SUM (CASE WHEN Combined.Year = '2018' THEN Combined.[Total Orders] ELSE 0.00 END)) AS 'Orders Difference',
(SUM (CASE WHEN Combined.Year = '2019' THEN Combined.[Quantity Ordered] ELSE 0.00 END) -
SUM (CASE WHEN Combined.Year = '2018' THEN Combined.[Quantity Ordered] ELSE 0.00 END)) AS 'Quantity Difference'
FROM 

(SELECT
T_2019.Country,
T_2019.Product,
T_2019.Currency,
'2019' As Year,
SUM(T_2019.Sales_2019_H1) AS 'Revenue',
SUM(T_2019.Quantity_2019_H1) AS 'Quantity Ordered',
SUM(T_2019.Orders_2019_H1) AS 'Total Orders'
FROM dbfour.dbo.T_2019 T_2019
GROUP BY
T_2019.Country,
T_2019.Product,
T_2019.Currency
UNION 
SELECT
T_2018.Country,
T_2018.Product,
T_2018.Currency,
'2018' AS Year,
SUM(T_2018.Sales_2018_H1) AS 'Revenue',
SUM(T_2018.Quantity_2018_H1) AS 'Quantity Ordered',
SUM(T_2018.Orders_2018_H1) AS 'Total Orders'
FROM dbfour.dbo.T_2018 T_2018
GROUP BY
T_2018.Country,
T_2018.Product,
T_2018.Currency) AS Combined


WHERE 
Combined.Country = 'Austria' OR 
Combined.Country = 'Australia' OR
Combined.Country = 'New Zealand'
GROUP BY
Combined.Country,
Combined.Product,
Combined.Currency;
```
Which would return the following output:

![image](https://github.com/WalterCo/JetBrains_Homework/blob/master/Summary_Orders_quantity_Revenue_Difference%20(2).png?raw=true)

**Conclusion:** The main reason for the drop was the fluctuation of the exchange rate, there is a decrease in revenue/orders/ordered quantity in Austria, Australia and New Zealand for which my recommendation would be ad follows: 

- Check the logs and the feedbacks coming from those countries to understand why the number of orders decreased.
- Review the market nieche, are we trying to sell only to IT Companies? Even companies that simply use only BI Tools need an effective ticketing system such as **YouTrack in Cloud**.
- Do a market research in those countries to understand what products are the most popular in the same nieche and investigate their feautures, are any of their feautures better? Is their tool more scalable in terms of use? Does it requires much more expertise? Is it more intuitive? etc.
