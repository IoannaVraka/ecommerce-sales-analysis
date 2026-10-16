-- ============================================================
-- 1. DATA CLEANING
-- ============================================================

-- Correct column type from text to date
UPDATE ecommerce_sales 
SET order_date = str_to_date(order_date,'%Y-%m-%d');
ALTER TABLE ecommerce_sales
MODIFY COLUMN order_date DATE;

-- Check for unexpected characters in customer name.
SELECT *
FROM ecommerce_sales
WHERE customer_name REGEXP '[^a-zA-Z ]'
order by order_id desc;

-- Verify encoding error from previous query.
SELECT * FROM ecommerce_sales WHERE customer_name LIKE '%Alia';

-- Correct encoding error.
SELECT 
    customer_name,
    REPLACE(customer_name, 'Dβ€™Alia', "D'Alia") AS corrected_name
FROM ecommerce_sales
WHERE customer_name LIKE '%Dβ€™Alia';

UPDATE ecommerce_sales
SET customer_name = REPLACE(customer_name, 'Dβ€™Alia', "D'Alia")
WHERE customer_name LIKE '%Dβ€™Alia';

-- ============================================================
-- 2. DATA QUALITY CHECKS
-- ============================================================

-- Check for duplicates
WITH duplicate_cte AS (SELECT ROW_NUMBER() OVER(partition by
					order_id,order_date,customer_name,
                    Region,City,Category,Sub_Category,
                    product_name,Quantity,unit_price,
                    Discount,Sales,Profit,payment_method) 
                    AS row_num
FROM ecommerce_sales)
SELECT * FROM duplicate_cte 
WHERE row_num>1;

-- Check for leading or trailing spaces in payment method
SELECT DISTINCT payment_method
FROM ecommerce_sales
WHERE payment_method <> TRIM(payment_method);

-- Check for missing values
SELECT * FROM ecommerce_sales
WHERE payment_method IS NULL
OR payment_method = '';

-- ============================================================
-- 3. REGIONAL SALES ANALYSIS
-- ============================================================

-- Analyze order counts and total quantity sold by region
SELECT  region,
count(order_id) AS orders_count,
sum(quantity) AS total_quantity
FROM ecommerce_sales
GROUP BY region
ORDER BY total_quantity DESC;

-- Compare order counts across cities and region
SELECT DISTINCT region, city,
count(order_id) over(partition by city) as city_orders,
count(order_id) over (partition by region) as region_orders
FROM ecommerce_sales
ORDER BY region_orders desc, city_orders desc;

-- Identify categories with the highest and lowest order counts by region
WITH category_orders AS (
    SELECT
        Region,
        Category,
        COUNT(order_id) AS orders_count
    FROM ecommerce_sales
    GROUP BY Region, Category
),
ranked_categories AS (
    SELECT
        Region,
        Category,
        orders_count,
        RANK() OVER (
            PARTITION BY Region
            ORDER BY orders_count DESC
        ) AS highest_rank,
        RANK() OVER (
            PARTITION BY Region
            ORDER BY orders_count ASC
        ) AS lowest_rank
    FROM category_orders
)
SELECT
    Region,
    Category,
    orders_count
FROM ranked_categories
WHERE highest_rank  <= 2
   OR lowest_rank  <= 2
ORDER BY region, orders_count DESC, Category ASC;

-- Analyze sales, profit and profit margin by region
SELECT region, sum(sales) as total_sales, sum(profit) as total_profit,
        (sum(profit) / sum(sales)) * 100 AS	 profit_margin
FROM ecommerce_sales
GROUP BY region
ORDER BY total_sales desc;

-- Payment method by region
SELECT region, payment_method, count(*) as payments
FROM ecommerce_sales
GROUP BY region, payment_method
ORDER BY region, payments DESC;

-- ============================================================
-- 4. ANNUAL SALES & PROFITABILITY
-- ============================================================

-- Check date range and monthly data coverage for each year
SELECT
    YEAR(order_date) AS year,
    MIN(order_date) AS first_order,
    MAX(order_date) AS last_order,
    COUNT(DISTINCT MONTH(order_date)) AS months_with_data
FROM ecommerce_sales
GROUP BY YEAR(order_date)
ORDER BY year;

-- Analyze annual sales, profit, profit margin,
-- average discount, quantity and order counts
SELECT
	year(order_date) AS YEAR,
    count(order_id) AS orders_count,
    sum(quantity) AS total_quantity,
    sum(sales) AS total_sales,
    sum(sales)/sum(quantity) AS sales_per_unit,
    sum(profit) AS total_profit,
	(SUM(profit) / SUM(sales)) * 100 AS profit_margin,
    avg(discount) AS average_discount
FROM ecommerce_sales
GROUP BY YEAR(order_date)
ORDER BY YEAR asc;

-- Analyze monthly sales trends across different years
SELECT
    YEAR(order_date) AS year,
    MONTH(order_date) AS month,
    SUM(sales) AS total_sales
FROM ecommerce_sales
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY year, month;

-- ============================================================
-- 5. TOP PERFORMING CATEGORIES
-- ============================================================

-- Identify top-performing and lowest-margin categories each year
SELECT *
FROM (
    SELECT
        YEAR(order_date) AS year,
        category,
        (SUM(profit) / SUM(sales)) * 100 AS profit_margin,
        RANK() OVER (
            PARTITION BY YEAR(order_date)
            ORDER BY (SUM(profit) / SUM(sales) * 100) DESC
        ) AS highest_rank,
        RANK() OVER (
            PARTITION BY YEAR(order_date)
            ORDER BY (SUM(profit) / SUM(sales) * 100) ASC
        ) AS lowest_rank
    FROM ecommerce_sales
    GROUP BY YEAR(order_date), category
) AS ranked_categories
WHERE highest_rank <= 2
   OR lowest_rank = 1
ORDER BY year, profit_margin DESC;
