-- Analyze the yearly performance of products by comparing their sales 
-- to both the average sales performance of the product and the previous year's sales
WITH
    yearly_product_sales
    AS
    (
        -- Aggregate sales data by year and product
        SELECT
            YEAR(f.order_date) AS order_year,
            p.product_name,
            SUM(f.sales_amount) AS current_sales
        FROM gold.fact_sales f
            LEFT JOIN gold.dim_products p
            ON f.product_key = p.product_key
        WHERE f.order_date IS NOT NULL
        GROUP BY 
        YEAR(f.order_date),
        p.product_name
    )
SELECT
    order_year,
    product_name,
    current_sales,
    -- Calculate the average sales for each product
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    -- Calculate the difference between current sales and average sales
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    -- Determine if the current sales are above, below, or equal to the average sales
    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,
    -- Year-over-Year Analysis
    -- Get the previous year's sales for the same product
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    -- Calculate the difference between current sales and previous year's sales
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    -- Determine if the current sales have increased, decreased, or remained the same compared to the previous year
    CASE 
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;