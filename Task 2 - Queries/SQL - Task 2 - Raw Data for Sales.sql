SELECT cou.region,
  ordItm.PRODUCT_ID,
  prod.NAME,
  ordItm.license_type,
  cou.NAME,
  COUNT(DISTINCT CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.ID END) as Orders_2018_H1,
  SUM( CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.quantity END) as Quantity_2018_H1,
  COUNT(DISTINCT CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.ID END) as Orders_2019_H1,
  SUM( CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.quantity END) as Quantity_2019_H1,
  SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END) as Sales_Usd_2018H1,
  SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END) as Sales_Usd_2019H1
FROM bi.sales.Orders ord
JOIN bi.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN bi.sales.Customer cust ON ord.customer = cust.id
JOIN bi.sales.Country cou ON cust.country_id = cou.id
JOIN bi.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN bi.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
  AND YEAR(ord.exec_date) IN (2018, 2019) -- Year 2018, 2019
  AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
GROUP BY cou.region,ordItm.PRODUCT_ID,prod.NAME, cou.NAME, ordItm.license_type
ORDER BY 1
;