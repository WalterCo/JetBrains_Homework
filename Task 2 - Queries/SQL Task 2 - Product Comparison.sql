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