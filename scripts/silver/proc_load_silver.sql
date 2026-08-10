/*
===============================================================================
Script:         proc_load_silver.sql
Description:    Stored Procedure for loading data from Bronze Layer
                into Silver Layer.

Purpose:
    - Clean and transform raw Bronze data.
    - Standardize data formats and values.
    - Handle invalid and missing data.
    - Remove duplicate customer records.
    - Recalculate inconsistent sales and price values.
    - Load cleaned data into Silver Layer.
    - Prevent duplicate data when the procedure is executed repeatedly.

Usage:
    EXEC silver.load_silver;

Layer:
    Bronze → Silver

Tables:
    1. silver.crm_cust_info
    2. silver.crm_prd_info
    3. silver.crm_sales_details
    4. silver.erp_cust_az12
    5. silver.erp_loc_a101
    6. silver.erp_px_cat_g1v2
===============================================================================
*/


-- ============================================================================
-- Create Stored Procedure
-- ============================================================================

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    PRINT '==========================================';
    PRINT 'Silver Layer Load Started';
    PRINT '==========================================';


    -- =========================================================================
    -- 1. TRUNCATE SILVER TABLES
    -- =========================================================================
    -- Remove existing data before loading.
    -- This prevents duplicate records when the procedure is executed again.
    --
    -- TRUNCATE is used instead of DELETE because the Silver tables are fully
    -- reloaded from the Bronze Layer every time the procedure runs.
    -- =========================================================================

    PRINT '------------------------------------------';
    PRINT 'Truncating Silver Tables';
    PRINT '------------------------------------------';

    TRUNCATE TABLE silver.crm_cust_info;
    TRUNCATE TABLE silver.crm_prd_info;
    TRUNCATE TABLE silver.crm_sales_details;
    TRUNCATE TABLE silver.erp_cust_az12;
    TRUNCATE TABLE silver.erp_loc_a101;
    TRUNCATE TABLE silver.erp_px_cat_g1v2;


    -- =========================================================================
    -- 2. LOAD silver.crm_cust_info
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.crm_cust_info';
    PRINT '------------------------------------------';

    INSERT INTO silver.crm_cust_info (
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

        -- Remove unwanted leading/trailing spaces
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,

        -- Standardize marital status
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                THEN 'Married'
            ELSE 'n/a'
        END AS cst_marital_status,

        -- Standardize gender
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F'
                THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M'
                THEN 'Male'
            ELSE 'n/a'
        END AS cst_gndr,

        cst_create_date

    FROM (
        SELECT
            *,

            -- Identify the latest record for each customer
            ROW_NUMBER() OVER (
                PARTITION BY cst_id
                ORDER BY cst_create_date DESC
            ) AS flag_last

        FROM bronze.crm_cust_info
    ) t

    -- Keep only the latest record for each customer
    -- and exclude invalid NULL customer IDs
    WHERE flag_last = 1
      AND cst_id IS NOT NULL;


    -- =========================================================================
    -- 3. LOAD silver.crm_prd_info
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.crm_prd_info';
    PRINT '------------------------------------------';

    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT

        prd_id,

        -- Convert category key format:
        -- AC-HE → AC_HE
        REPLACE(
            SUBSTRING(prd_key, 1, 5),
            '-',
            '_'
        ) AS cat_id,

        -- Remove category prefix from product key
        SUBSTRING(
            prd_key,
            7,
            LEN(prd_key)
        ) AS prd_key,

        prd_nm,

        -- Replace NULL product cost with 0
        ISNULL(prd_cost, 0) AS prd_cost,

        -- Standardize product line
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,

        -- Convert datetime into date
        CAST(prd_start_dt AS DATE) AS prd_start_dt,

        -- Derive product end date based on the next start date
        CAST(
            LEAD(prd_start_dt) OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            ) - 1
            AS DATE
        ) AS prd_end_dt

    FROM bronze.crm_prd_info;


    -- =========================================================================
    -- 4. LOAD silver.crm_sales_details
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.crm_sales_details';
    PRINT '------------------------------------------';

    INSERT INTO silver.crm_sales_details (
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

        -- Standardize Order Date
        CASE
            WHEN sls_order_dt = 0
                OR LEN(sls_order_dt) != 8
                THEN NULL
            ELSE CAST(
                CAST(sls_order_dt AS VARCHAR) AS DATE
            )
        END AS sls_order_dt,

        -- Standardize Ship Date
        CASE
            WHEN sls_ship_dt = 0
                OR LEN(sls_ship_dt) != 8
                THEN NULL
            ELSE CAST(
                CAST(sls_ship_dt AS VARCHAR) AS DATE
            )
        END AS sls_ship_dt,

        -- Standardize Due Date
        CASE
            WHEN sls_due_dt = 0
                OR LEN(sls_due_dt) != 8
                THEN NULL
            ELSE CAST(
                CAST(sls_due_dt AS VARCHAR) AS DATE
            )
        END AS sls_due_dt,

        -- Recalculate invalid or inconsistent Sales
        --
        -- Business Rule:
        -- Sales = Quantity × Price
        --
        -- If Sales is NULL, zero, negative, or inconsistent,
        -- derive Sales using Quantity × absolute Price.
        CASE
            WHEN sls_sales IS NULL
                OR sls_sales <= 0
                OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,

        sls_quantity,

        -- Recalculate invalid Price
        --
        -- If Price is NULL, zero, or negative,
        -- derive Price from Sales / Quantity.
        CASE
            WHEN sls_price IS NULL
                OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END AS sls_price

    FROM bronze.crm_sales_details;


    -- =========================================================================
    -- 5. LOAD silver.erp_cust_az12
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.erp_cust_az12';
    PRINT '------------------------------------------';

    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT

        -- Remove NAS prefix from customer ID
        CASE
            WHEN cid LIKE 'NAS%'
                THEN SUBSTRING(
                    cid,
                    4,
                    LEN(cid)
                )
            ELSE cid
        END AS cid,

        -- Future birth dates are considered invalid
        -- and are converted to NULL
        CASE
            WHEN bdate > GETDATE()
                THEN NULL
            ELSE bdate
        END AS bdate,

        -- Standardize gender
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
                THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
                THEN 'Male'
            ELSE 'n/a'
        END AS gen

    FROM bronze.erp_cust_az12;


    -- =========================================================================
    -- 6. LOAD silver.erp_loc_a101
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.erp_loc_a101';
    PRINT '------------------------------------------';

    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT

        -- Remove hyphen from customer ID
        -- Example: AW-00011000 → AW00011000
        REPLACE(cid, '-', '') AS cid,

        -- Standardize country values
        CASE
            WHEN TRIM(cntry) = 'DE'
                THEN 'Germany'

            WHEN TRIM(cntry) IN ('US', 'USA')
                THEN 'United States'

            WHEN TRIM(cntry) = ''
                OR cntry IS NULL
                THEN 'n/a'

            ELSE TRIM(cntry)
        END AS cntry

    FROM bronze.erp_loc_a101;


    -- =========================================================================
    -- 7. LOAD silver.erp_px_cat_g1v2
    -- =========================================================================
    PRINT '------------------------------------------';
    PRINT 'Loading silver.erp_px_cat_g1v2';
    PRINT '------------------------------------------';

    INSERT INTO silver.erp_px_cat_g1v2 (
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


    -- =========================================================================
    -- END OF SILVER LOAD
    -- =========================================================================

    PRINT '==========================================';
    PRINT 'Silver Layer Load Completed Successfully';
    PRINT '==========================================';

END;
GO


-- ============================================================================
-- Execute Stored Procedure
-- ============================================================================
-- Uncomment the following line when you want to run the Silver Layer ETL.
--
-- EXEC silver.load_silver;
-- ============================================================================
