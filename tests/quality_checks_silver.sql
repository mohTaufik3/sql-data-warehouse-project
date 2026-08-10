/*
===============================================================================
Script:         quality_checks_silver.sql
Description:    Data quality checks for Silver Layer tables.

Purpose:
    - Validate data quality after the Silver Layer ETL process.
    - Check for NULLs and duplicates in primary keys.
    - Check for unwanted spaces.
    - Validate data standardization and consistency.
    - Validate date ranges and date relationships.
    - Validate sales, quantity, and price consistency.
    - Validate consistency between related Silver tables.

Expected Result:
    All validation queries should return NO RESULT unless otherwise stated.

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
-- 1. SILVER: crm_cust_info
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.crm_cust_info';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


-- ----------------------------------------------------------------------------
-- Check for Unwanted Spaces
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);


-- ----------------------------------------------------------------------------
-- Check Data Standardization and Consistency
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;


-- ----------------------------------------------------------------------------
-- Check for Unexpected Customer Key
-- ----------------------------------------------------------------------------

SELECT *
FROM silver.crm_cust_info
WHERE cst_key = 'PO25';


-- ============================================================================
-- 2. SILVER: crm_prd_info
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.crm_prd_info';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    prd_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;


-- ----------------------------------------------------------------------------
-- Check for Unwanted Spaces
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);


-- ----------------------------------------------------------------------------
-- Check for NULL or Negative Product Cost
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL
    OR prd_cost < 0;


-- ----------------------------------------------------------------------------
-- Check Data Standardization and Consistency
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- ----------------------------------------------------------------------------
-- Check for Invalid Date Orders
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT *
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;


-- ============================================================================
-- 3. SILVER: crm_sales_details
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.crm_sales_details';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check for Invalid Order Dates
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    sls_order_dt
FROM silver.crm_sales_details
WHERE sls_order_dt > '2050-01-01'
    OR sls_order_dt < '1900-01-01';


-- ----------------------------------------------------------------------------
-- Check for Invalid Ship Dates
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    sls_ship_dt
FROM silver.crm_sales_details
WHERE sls_ship_dt > '2050-01-01'
    OR sls_ship_dt < '1900-01-01';


-- ----------------------------------------------------------------------------
-- Check for Invalid Due Dates
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    sls_due_dt
FROM silver.crm_sales_details
WHERE sls_due_dt > '2050-01-01'
    OR sls_due_dt < '1900-01-01';


-- ----------------------------------------------------------------------------
-- Check for Invalid Date Orders
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;


-- ----------------------------------------------------------------------------
-- Check Data Consistency Between Sales, Quantity, and Price
--
-- Business Rule:
-- Sales = Quantity × Price
--
-- Values must not be NULL, zero, or negative.
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE
    sls_sales != sls_quantity * sls_price
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;


-- ============================================================================
-- 4. SILVER: erp_cust_az12
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.erp_cust_az12';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check Customer ID Consistency Between Tables
-- ----------------------------------------------------------------------------

SELECT TOP (5)
    cid
FROM silver.erp_cust_az12;

SELECT TOP (5)
    cst_id
FROM silver.crm_cust_info;


-- ----------------------------------------------------------------------------
-- Check for Invalid Birth Dates
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
    OR bdate > GETDATE();


-- ----------------------------------------------------------------------------
-- Check Data Standardization and Consistency
-- Expected Values:
-- Female
-- Male
-- n/a
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


-- ============================================================================
-- 5. SILVER: erp_loc_a101
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.erp_loc_a101';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check Customer ID Consistency Between Tables
-- ----------------------------------------------------------------------------

SELECT TOP (5)
    cid
FROM silver.erp_loc_a101;

SELECT TOP (5)
    cst_key
FROM silver.crm_cust_info;


-- ----------------------------------------------------------------------------
-- Check Data Standardization and Consistency
-- Expected Values:
-- Australia
-- Canada
-- France
-- Germany
-- United Kingdom
-- United States
-- n/a
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;


-- ============================================================================
-- 6. SILVER: erp_px_cat_g1v2
-- ============================================================================

PRINT '==============================================';
PRINT 'Quality Checks: silver.erp_px_cat_g1v2';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check for Unwanted Spaces
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT *
FROM silver.erp_px_cat_g1v2
WHERE
    cat != TRIM(cat)
    OR subcat != TRIM(subcat)
    OR maintenance != TRIM(maintenance);


-- ----------------------------------------------------------------------------
-- Check Data Standardization and Consistency
-- ----------------------------------------------------------------------------

SELECT DISTINCT
    cat
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
    subcat
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;


-- ============================================================================
-- 7. CROSS-TABLE CONSISTENCY CHECKS
-- ============================================================================

PRINT '==============================================';
PRINT 'Cross-Table Consistency Checks';
PRINT '==============================================';


-- ----------------------------------------------------------------------------
-- Check Customer IDs Between CRM and ERP Customer Data
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    cst_id
FROM silver.crm_cust_info
WHERE cst_id IS NOT NULL

EXCEPT

SELECT
    TRY_CAST(cid AS INT)
FROM silver.erp_cust_az12
WHERE cid IS NOT NULL;


-- ----------------------------------------------------------------------------
-- Check Customer Keys Between CRM and ERP Location Data
-- Expectation: No Result
-- ----------------------------------------------------------------------------

SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key IS NOT NULL

EXCEPT

SELECT
    cid
FROM silver.erp_loc_a101
WHERE cid IS NOT NULL;


-- ============================================================================
-- END OF QUALITY CHECKS
-- ============================================================================

PRINT '==============================================';
PRINT 'Silver Layer Quality Checks Completed';
PRINT '==============================================';
