SELECT
T_2019.Country,
T_2019.Product,
T_2019.Currency,
SUM(T_2019.Sales_2019_H1) AS '2019_Revenue'
FROM dbfour.dbo.T_2019 T_2019
GROUP BY
T_2019.Country,
T_2019.Product,
T_2019.Currency;

SELECT
T_2018.Country,
T_2018.Product,
T_2018.Currency,
SUM(T_2018.Sales_2018_H1) AS '2018_Revenue'
FROM dbfour.dbo.T_2018 T_2018
GROUP BY
T_2018.Country,
T_2018.Product,
T_2018.Currency;