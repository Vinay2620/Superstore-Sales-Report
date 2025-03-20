SELECT * FROM superstore_data;

-- DATA CLEANING

ALTER TABLE superstore_data
MODIFY sales INT;

ALTER TABLE superstore_data
MODIFY profit INT;

ALTER TABLE superstore_data
MODIFY Unit_Price INT;

SELECT DISTINCT ship_mode
FROM superstore_data;

UPDATE superstore_data
SET ship_mode = CASE WHEN ship_mode = "FC" THEN "First Class" 
				ELSE ship_mode END;
                

SELECT DISTINCT segment
FROM superstore_data;

UPDATE superstore_data
SET segment = CASE WHEN segment = "HO" THEN "Home Office" 
			       ELSE segment
              END;
                

UPDATE superstore_data
SET segment = CONCAT(UPPER(SUBSTRING(segment,1,1)),LOWER(SUBSTRING(segment,2)))
WHERE Segment = "consumer";


SELECT DISTINCT Region
FROM superstore_data;

UPDATE superstore_data
SET Region = CASE WHEN Region = "West" THEN "Western" 
				  WHEN Region = "north eastern" THEN "North Eastern"
			      ELSE Region
             END;

-- Checking Duplicate Rows
             
SELECT * 
FROM (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Segment, Ship_City, Ship_State, Ship_Postal_Code,
	Region, Product_ID, Category, Sub_Category, Product_Name, sales, Quantity, Unit_Price, profit) AS RankDup
	FROM superstore_data
) DuplicateRow
WHERE RankDup >= 2; 

 

-- AD HOC ANALYSIS


-- Top 5 customers who generated the most profit.

SELECT Customer_ID, SUM(Profit) as TotalProfit
FROM superstore_data
GROUP BY Customer_ID
ORDER BY TotalProfit DESC
LIMIT 5;


-- Find the top 3 products by sales for each category

WITH ProductRanking AS (
	SELECT  Category, Product_name, SUM(sales) AS TotalSales,
	RANK() OVER(PARTITION BY Category ORDER BY SUM(sales) DESC) AS RankInCategory
	FROM superstore_data
	GROUP BY 1,2
)
SELECT Category, Product_name, TotalSales
FROM ProductRanking
WHERE RankInCategory <= 3
ORDER BY 1, RankInCategory;


-- Monthly Sales and Profit by Region

SELECT YEAR(order_date) AS Year, MONTH(order_date) AS Month,
region, SUM(sales) AS TotalSales, SUM(Profit) AS TotalProfit
FROM superstore_data
GROUP BY 1,2,3
ORDER BY 1,2;


-- Cumulative Sales by Month

SELECT YEAR(order_date) AS Year, MONTH(Order_date) AS Month, SUM(sales) AS MonthlySales,
SUM(SUM(sales)) OVER(ORDER BY YEAR(order_date), MONTH(Order_date)) AS CumulativeSales
FROM superstore_data
GROUP BY 1,2;


-- Year over Year Growth Percentage

SELECT YEAR(order_date) AS Year, SUM(Sales) AS TotalSales,
LAG(SUM(Sales),1,SUM(Sales)) OVER(ORDER BY YEAR(order_date)) AS PreviousTotalSales,
IFNULL(CONCAT(ROUND((SUM(Sales) - LAG(SUM(Sales),1) OVER(ORDER BY YEAR(order_date)))/
LAG(SUM(Sales),1) OVER(ORDER BY YEAR(order_date)) * 100,2),"%"),0) AS YoY_Growth
FROM superstore_data
GROUP BY 1;


-- Top 10 Customer Who Ordered Most Expensive Products

WITH MaxPricePerProduct AS (
	SELECT product_id, MAX(Unit_Price) as MaxPrice
	FROM superstore_data
	GROUP BY 1
)
SELECT sd.customer_id, sd.product_name, mp.MaxPrice
FROM superstore_data sd
JOIN MaxPricePerProduct mp
ON sd.Product_ID = mp.Product_ID
ORDER BY 3 DESC
LIMIT 10;



-- Total Sales and Profit on Weekends and Weekdays

SELECT CASE WHEN DAYOFWEEK(order_date) IN (1,7) 
			THEN "WeekEnds" 
            ELSE "WeekDays" END AS `WeekEnds/WeekDays`,
		SUM(sales) AS TotalSales, SUM(profit) AS TotalProfit
FROM superstore_data
GROUP BY 1;



-- Average sales per customer by segment

SELECT segment, ROUND(AVG(TotalSales),2) AvgSalesPerCustomer
FROM(
	SELECT customer_ID, segment, SUM(sales) AS TotalSales
	FROM superstore_data
	GROUP BY 1,2
) CuatomerSalesBySegment
GROUP BY 1;



-- Find the largest gap between two orders for each customer

WITH OrderGaps AS (
	SELECT customer_id, order_date,
	LAG(order_date,1) OVER(PARTITION BY customer_id ORDER BY order_date) AS PreviousOrderDate,
	DATEDIFF(order_date, LAG(order_date,1) OVER(PARTITION BY customer_id ORDER BY order_date)) AS GapInDays
	FROM superstore_data
)
SELECT customer_id, MAX(GapInDays) AS LongestGapInDays
FROM OrderGaps
GROUP BY 1
ORDER BY 2 DESC;




-- what quarters were the most profitable to us.

WITH QuarterRank AS (
SELECT YEAR(order_date) AS Year, QUARTER(Order_date) AS Quarter,
SUM(Profit) AS TotalProfit, RANK() OVER(PARTITION BY YEAR(order_date) ORDER BY SUM(Profit) DESC) AS RankProfit
FROM superstore_data
GROUP BY 1,2
)
SELECT Year, Quarter, TotalProfit
FROM QuarterRank
WHERE RankProfit = 1;




-- Best performing shipping mode by profit

SELECT ship_mode, SUM(Profit) AS TotalProfit,
RANK() OVER(ORDER BY SUM(Profit) DESC) AS RankProfit
FROM superstore_data
GROUP BY 1;



-- What are the profit margin by each region

SELECT region, CONCAT(ROUND((SUM(profit) / SUM(sales))*100,2),"%") AS ProfitMargin
FROM superstore_data
GROUP BY 1
ORDER BY 2 DESC;



-- What top 10 state brings in the highest sales and profits

SELECT Ship_State, SUM(sales) AS TotalSales, SUM(profit) AS TotalProfit
FROM superstore_data
GROUP BY 1
ORDER BY 2 DESC,3 DESC
LIMIT 10;


-- Let's observe bottom 10 states

SELECT Ship_State, SUM(sales) AS TotalSales, SUM(profit) AS TotalProfit
FROM superstore_data
GROUP BY 1
ORDER BY 2,3
LIMIT 10;



-- How many customers do we have (unique customer IDs) in total and how much per region and state

SELECT COUNT(DISTINCT customer_id) as TotalUniqueCustomer
FROM superstore_data;
SELECT region, COUNT(DISTINCT customer_id) as TotalUniqueCustomer
FROM superstore_data
GROUP BY 1;
SELECT ship_state, COUNT(DISTINCT customer_id) as TotalUniqueCustomer
FROM superstore_data
GROUP BY 1
ORDER BY 2 DESC;



-- Identify orders where the ship date overlaps with another order’s ship date

WITH OverlapDate AS (
SELECT order_id, ship_date,
LEAD(order_id,1) OVER(ORDER BY ship_date) AS OverlapOrderId,
LEAD(ship_date,1) OVER(ORDER BY ship_date) AS OverlapShipDate
FROM superstore_data
)
SELECT *
FROM OverlapDate
WHERE ship_date = OverlapShipDate and order_id <> OverlapOrderId;



-- Average shipping time per class

SELECT Ship_Mode, ROUND(AVG(DATEDIFF(ship_date, order_date))) AS AvgShippingTime
FROM superstore_data
GROUP BY 1
ORDER BY 2 DESC;



-- which month has the highest sales and profit in each year.

WITH MonthRanking AS (
SELECT YEAR(order_date) AS Year, MONTH(order_date) AS Month, SUM(sales) AS TotalSales,
SUM(profit) AS TotalProfit, RANK() OVER(PARTITION BY YEAR(order_date) ORDER BY SUM(sales) DESC, SUM(profit) DESC) AS RankMonth
FROM superstore_data
GROUP BY 1,2
ORDER BY 1,2
)
SELECT Year, Month, TotalSales, TotalProfit
FROM MonthRanking
WHERE RankMonth = 1;



-- Find the top 3 customer by profit for each year

SELECT Year, customer_id, TotalProfit
FROM (
	SELECT YEAR(order_date) AS Year, customer_id, SUM(Profit) AS TotalProfit,
	RANK() OVER(PARTITION BY YEAR(order_date) ORDER BY SUM(Profit) DESC) AS ProfitRank
	FROM superstore_data
	GROUP BY 1,2
) AS YearlyCustomerProfit
WHERE ProfitRank <= 3;



-- Identify customers who have purchased in all regions

WITH RegionCount AS (
SELECT customer_id, COUNT(DISTINCT region) AS RegionPurchasedIn
FROM superstore_data
GROUP BY 1
),
TotalRegion AS (
SELECT COUNT(DISTINCT region) AS TotalRegionCount
FROM superstore_data
)
SELECT rc.customer_id
FROM RegionCount rc, TotalRegion tr
WHERE rc.RegionPurchasedIn = tr.TotalRegionCount;


