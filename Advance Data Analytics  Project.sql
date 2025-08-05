Use DataWarehouseAnalytics

--Change Over Time Trends 

SELECT 
YEAR(order_date),
SUM(sales_amount) Total_SalesOverTime,
COUNT(DISTINCT customer_key) Total_Customers,
COUNT(DISTINCT product_key) Total_Products,
SUM(quantity) Total_quantity,
COUNT(order_number) TotalOrders
FROM
gold.fact_sales
WHERE order_date is not null
GROUP BY YEAR(order_date) 

SELECT
YEAR(order_date),
COUNT(order_number)
FROM 
gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)

SELECT
*
FROM
gold.fact_sales
WHERE order_date IS NOT NULL AND quantity > 1
ORDER BY order_date

