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