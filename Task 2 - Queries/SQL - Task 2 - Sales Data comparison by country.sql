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