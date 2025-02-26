-- Data Standardization & Consistency.
-- TRIM() function is used to remove leading and trailing spaces.
-- UPPER() function is used to convert all characters to uppercase.
-- CASE WHEN statement is used to convert the values of the columns to a standard format.
-- ROW_NUMBER() function is used to select the latest record for each customer based on the create date.
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    BEGIN TRY
        TRUNCATE TABLE silver.crm_cust_info;
        INSERT INTO silver.crm_cust_info
            (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
            )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,

            CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            ELSE 'Unknown'
        END cst_marital_status,

            CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'Unknown'
        END cst_gndr,

            cst_create_date

        FROM (SELECT *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS row_num
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL)t
        WHERE row_num = 1;


        -- CRM PRODUCT INFO
        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info
            (
            prd_id,
            prd_key,
            category_id,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
            )
        SELECT
            prd_id,
            -- SUBSTRING: Extracts a substring from prd_key starting at position 7 to the end of the string
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

            -- REPLACE: Replaces all occurrences of '-' with '_' in the substring of the first 5 characters of prd_key
            REPLACE(SUBSTRING(prd_key, 1 , 5), '-', '_') AS category_id,

            prd_nm,

            -- ISNULL: Replaces NULL values in prd_cost with 0
            ISNULL(prd_cost, 0) AS prd_cost,

            CASE UPPER(TRIM(prd_line))
            WHEN 'M' Then 'Mountain'
            WHEN 'R' Then 'Road'
            WHEN 'S' Then 'Sport'
            WHEN 'T' Then 'Touring'
            ELSE 'Unknown'
        END AS prd_line,

            CAST(prd_start_dt AS DATE)prd_start_dt,

            -- LEAD: Gets the next prd_start_dt value within the same prd_key partition and orders by prd_start_dt
            -- prd_end_dt should be greater than prd_start_dt but less than the next prd_start_dt
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE) AS prd_end_dt

        FROM bronze.crm_prd_info;


        TRUNCATE TABLE silver.crm_sales_details;
        INSERT INTO silver.crm_sales_details
            (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
            )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            CASE
            WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
        END AS sls_order_dt,

            CASE
            WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
        END AS sls_ship_dt,

            CASE
            WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
            ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
        END AS sls_due_dt,

            CASE 
            WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,

            sls_quantity,

            CASE 
            WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity,0)
            ELSE sls_price
        END AS sls_price

        FROM bronze.crm_sales_details;


        TRUNCATE TABLE silver.erp_cust_az12;
        INSERT INTO silver.erp_cust_az12(
            cid,
            bdate,
            gen
        )
        SELECT
            CASE 
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
            ELSE cid
        END AS cid,

            CASE
            WHEN bdate > GETDATE() THEN NULL
            ELSE bdate
        END AS bdate,

            CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            ELSE 'Unknown'
        END AS gen

        FROM bronze.erp_cust_az12




        TRUNCATE TABLE silver.erp_loc_a101
        INSERT INTO silver.erp_loc_a101(
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'Unknown'
            ELSE TRIM(cntry)
        END AS cntry
        FROM bronze.erp_loc_a101;


        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        INSERT INTO silver.erp_px_cat_g1v2(
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;
    END TRY

    BEGIN CATCH
    PRINT '=========================================='
    PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
    PRINT 'Error Message' + ERROR_MESSAGE();
    PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
    PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
    END CATCH
END