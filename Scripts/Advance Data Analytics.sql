Use DataWarehouseAnalytics

--Change Over Time Trends 

SELECT 
DATETRUNC(month,order_date),
SUM(sales_amount) Total_revenue,
COUNT(customer_key) TotalCustomers,
COUNT(product_key) TotalProductsSold
FROM
gold.fact_sales
WHERE order_date is not null
GROUP BY DATETRUNC(month,order_date)

--Cumulative Analysis

--Calculate the total Sales per month and the running total of Sales over time.

SELECT
order_date,
Total_Sales,
--calculaing the running total Sales 
SUM(Total_Sales) OVER(ORDER BY order_date) RunningTotalSales,
AvgPrice,
AVG(AvgPrice) OVER(Order by order_date) MovingAvg
FROM(
	SELECT
	DATETRUNC(YEAR,order_date) order_date,
	SUM(sales_amount) Total_Sales,
	AVG(price) AvgPrice
	FROM
	gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY
	DATETRUNC(Year,order_date)
)t

--Perfomance Analysis

--Analyze the yearly performance of products by comparing each  product's sales 
--to both its average sales performance and the previous year's sales 


WITH Product_Sales_Performance AS (
SELECT
YEAR(S.order_date) Order_Year,
P.product_name,
SUM(S.sales_amount) Yearly_Product_Sales
FROM gold.fact_sales S
LEFT JOIN
gold.dim_products P ON S.product_key = P.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(S.order_date),P.product_name
)
SELECT
Order_Year,
product_name,
Yearly_Product_Sales,
AVG(Yearly_Product_Sales) OVER(PARTITION BY product_name) Avg_Product_Sales,
Yearly_Product_Sales - AVG(Yearly_Product_Sales) OVER(PARTITION BY product_name) Avg_Diff,
CASE WHEN Yearly_Product_Sales - AVG(Yearly_Product_Sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Avg'
	 WHEN Yearly_Product_Sales - AVG(Yearly_Product_Sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Avg'
ELSE 'Avg' END Segmentation,
--Year Over Year Analysis
LAG(Yearly_Product_Sales) OVER(PARTITION BY product_name ORDER BY Order_Year) Py_Year,
Yearly_Product_Sales - LAG(Yearly_Product_Sales) OVER(PARTITION BY product_name ORDER BY Order_Year) Diff_PY,
CASE WHEN Yearly_Product_Sales - LAG(Yearly_Product_Sales) OVER(PARTITION BY product_name ORDER BY Order_Year) > 0 THEN 'Increase'
     WHEN Yearly_Product_Sales - LAG(Yearly_Product_Sales) OVER(PARTITION BY product_name ORDER BY Order_Year) < 0 THEN 'Decrease'
ELSE 'No Change' END Py_Seg 
FROM
Product_Sales_Performance
ORDER BY product_name,Order_Year

--Part-to-Whole Analysis

--which category contribute the most to overall sales?

WITH Sales_Category AS(
SELECT
P.Category,
SUM(sales_amount) total_sales
FROM gold.fact_sales S
LEFT JOIN 
gold.dim_products P ON S.product_key = P.product_key
GROUP BY P.category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER() OverAll_Sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT)/SUM(total_sales) OVER())*100,2),'%') As Percentage_of_Total
FROM
Sales_Category
Order BY 
total_sales DESC

--Data Segmentation

--Segment products into cost ranges and count how many products fall into each segment

WITH Product_Segement AS (
	SELECT DISTINCT
	product_name,
	category,
	subcategory,
	SUM(cost) Product_Cost,
	CASE WHEN SUM(cost) < 100 THEN 'Below 100'
		 WHEN SUM(cost) BETWEEN 100 and 500 THEN '100-500'
		 WHEN SUM(cost) BETWEEN 500 and 1000 THEN '500-1000'
	ELSE 'Above 1000' END Cost_Range
	FROM
	gold.dim_products
	WHERE category IS NOT NULL AND subcategory IS NOT NULL
	GROUP BY category,subcategory,product_name
)
SELECT
cost_range,
COUNT(product_name) AS total_poducts
FROM Product_Segement
GROUP BY cost_range

--Group customers based on their spending behaviour:
--VIP: at least 12 months  of history and spending more than $5000.
--Regular: at least 12 months of history but spending $5000 or less.
--New:lifespan less than 12 months
--And find the find total numbers by each group 
GO
WITH Customer_Segment AS (
	SELECT
	c.customer_key,
	MIN(order_date) first_order,
	MAX(order_date) last_order,
	DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) Spending_Period,  
	SUM(sales_amount) Total_Spending,
	CASE WHEN SUM(sales_amount) > 5000 AND DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) >= 12 THEN 'VIP'
		 WHEN SUM(sales_amount) <= 5000 AND DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) >=12 THEN 'Regular'
		 ELSE 'NEW' END Customer_behaviour
	FROM
	gold.fact_sales s
	LEFT JOIN gold.dim_customers c ON s.customer_key = c.customer_key
	GROUP BY c.customer_key
)
SELECT
Customer_behaviour,
COUNT(customer_key)
FROM
Customer_Segment
GROUP BY Customer_behaviour
ORDER BY COUNT(customer_key) DESC

/*
=========================================================================================
Customer Report
=========================================================================================
Purpose:
-This report consolidate key customer metrics and behaviours 

Highlights:
1.Gathers essential fields such as names, ages, and transaction details.
2.Segments customers into categories (VIP,Regular,New) and age groups.
3.Aggregate customer-level metrics:
	-total Orders
	-Total Sales
	-total quantity purchased
	-Total products
	-lifespan (in months)
4.Calculates valuable KPIs:
	-Recency (months since last orders)
	--Average Order Value
	-average monthly spend 
=========================================================================================
*/
/*---------------------------------------------------------------------------------------
--Base Query: Retrive core coulmns from tables
-----------------------------------------------------------------------------------------*/
Create VIEW gold.report_custoemrs AS
WITH Base_Query AS (
	SELECT
	c.customer_key,
	c.customer_number,
	c.birthdate,
	CONCAT(c.first_name ,' ', c.last_name) FullName,
	DATEDIFF(YEAR,c.birthdate,GETDATE()) Age,
	s.order_number,
	s.order_date,
	s.shipping_date,
	s.sales_amount,
	s.product_key,
	s.quantity
	FROM
	gold.dim_customers c
	LEFT JOIN gold.fact_sales s ON c.customer_key = s.customer_key
	WHERE order_date IS NOT NULL
)
,Customer_Aggregations AS (
SELECT
	customer_key,
	customer_number,
	FullName,
	Age,
	 MAX(order_date)  Last_OrderDate,
	 COUNT(DISTINCT order_number) TotalOrders,
	 SUM(sales_amount) Total_Sales,
	 SUM(quantity) Total_Quantity,
	 COUNT(DISTINCT product_key) Total_Products,
	 DATEDIFF(MONTH,MIN(order_date),MAX(order_date))Lifespan
FROM
Base_Query
GROUP BY customer_key,
		customer_number,
		FullName,
		Age
)
--Customer Segmentaion
	SELECT
		customer_key,
		customer_number,
		FullName,
		Age,
		CASE WHEN Age BETWEEN 20 and 30 THEN '20-30'
			 WHEN Age BETWEEN 30 AND 40 THEN '30-40'
			 WHEN Age BETWEEN 40 AND 50 THEN '40-50'
			 WHEN Age BETWEEN 50 AND 60 THEN '50-60'
			 WHEN Age BETWEEN 60 AND 80 THEN '60-80'
		ELSE 'Above 80' END Age_Group,
		TotalOrders,
		Total_Sales,
		Total_Quantity,
		Total_Products,
		Last_OrderDate,
		DATEDIFF(MONTH,Last_OrderDate,GETDATE()) Recency,
		Lifespan,
		CASE WHEN Total_Sales > 5000 AND Lifespan >= 12 THEN 'VIP'
			 WHEN Total_Sales <= 5000 AND Lifespan >= 12 THEN 'Regular'
		ELSE 'New' END Customer_segments,
--Avg Order Value
		Total_Sales/TotalOrders as Avg_Order_value,
--Avg Monthy Spend
		CASE WHEN Lifespan = 0 THEN Total_Sales
		ELSE Total_Sales/Lifespan END as Avg_monthy_Spend
FROM
Customer_Aggregations


/*
========================================================================================
Product Report
========================================================================================
Purpose:
	-This report consolidates key metrics and behaviours.

Highlights:
1. Gathers essential insights fields such as product name,category,sub category and cost,
2. Segments products by revenue to identify High-Performers,Mid-Rnge, or Low-Performers.
3. Aggregates product-level metrics:
	-total orders
	-total sales
	-tota quantity sold
	-total custoemrs (unique)
	-lifespan(in months)
4.Calcualate valuable KPI's 
	-recency (months since last sale)
	-average order revenue(AOR)
	-average monthly revenue
=======================================================================================*/

/*===================================================================================== 
1. Base Query primary colums from the table
=======================================================================================*/
GO
CREATE VIEW gold.report_products AS 
WITH Base_PQuery AS (
	SELECT
	f.order_number,
	f.customer_key,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	p.product_id,
	p.product_number,
	p.category,
	p.subcategory,
	p.maintenance,
	p.product_name,
	p.cost
	FROM
	gold.fact_sales f 
	LEFT JOIN 
	gold.dim_products p ON f.product_key= p.product_key
)
/*===================================================================================
2) Product Aggregations: Summarize key metrics at the product level
=====================================================================================*/
,Product_Aggregations AS(
	SELECT 
	product_key,
	product_id,
	product_name,
	category,
	subcategory,
	cost,
	MAX(order_date) LastOrderDate,
	COUNT(DISTINCT order_number) Total_Orders_ByProduct,
	SUM(sales_amount) Total_Sales_ByProduct,
	COUNT(quantity) as Total_Quantity_ByProduct,
	COUNT(DISTINCT customer_key) as Total_Customer_ByProduct,
	DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) Lifespan
	FROM
	Base_PQuery
	GROUP BY product_key,
	product_id,
	product_name,
	category,
	subcategory,
	cost
)
SELECT
/*======================================================================================
3) Final Query: Combines all product results  into one output
========================================================================================*/
	product_key,
	product_id,
	product_name,
	category,
	subcategory,
	cost,
	LastOrderDate,
	DATEDIFF(MONTH,LastOrderDate,GETDATE()) Recency,
	Total_Orders_ByProduct,
	Total_Sales_ByProduct,
	CASE WHEN Total_Sales_ByProduct > 50000 THEN 'High-Performer'
		 WHEN Total_Sales_ByProduct <= 10000 THEN 'Mid-Range'
	ELSE 'Low-Performer' END AS product_segment,	 
	Total_Quantity_ByProduct,
	Total_Customer_ByProduct,
	--Avg_Order_Revenue
	CASE WHEN Total_Orders_ByProduct = 0  THEN 0
	ELSE Total_Sales_ByProduct/Total_Orders_ByProduct
	END AS avg_Order_revenue,
	Lifespan,
	--Avg_Monthly_Revenue
	CASE WHEN Lifespan = 0 THEN Total_Sales_ByProduct
	ELSE Total_Sales_ByProduct/Lifespan
	END AS avg_monthly_revenue
FROM
Product_Aggregations


SELECT 
*
FROM
gold.report_products