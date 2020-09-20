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