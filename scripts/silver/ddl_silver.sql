-- ============================================================
-- Silver Layer Table Definitions
-- ============================================================
-- Purpose:
--   Create tables for the Silver Layer of the Data Warehouse.
--
-- Unlike the Bronze Layer, the Silver Layer is designed to
-- store cleaned, standardized, and transformed data.
--
-- Key characteristics:
--   1. Source data is cleaned and standardized.
--   2. Data types are converted where necessary.
--   3. Additional derived attributes can be introduced.
--   4. Data Warehouse metadata is added using dwh_create_date.
--
-- The tables are dropped and recreated to ensure that the
-- schema remains consistent during development and testing.
-- ============================================================


-- ============================================================
-- CRM Customer Information
-- ============================================================
-- Creates the Silver Layer table for cleaned CRM customer data.
--
-- Transformations expected in the Silver Layer may include:
--   - Removing duplicate customers
--   - Standardizing marital status
--   - Standardizing gender values
--   - Handling NULL or invalid values
--   - Keeping the latest customer record
--
-- dwh_create_date:
--   Stores the timestamp when the record is inserted into
--   the Data Warehouse.
-- ============================================================

IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id             INT,
    cst_key            NVARCHAR(50),
    cst_firstname      NVARCHAR(50),
    cst_lastname       NVARCHAR(50),
    cst_marital_status NVARCHAR(50),
    cst_gndr           NVARCHAR(50),
    cst_create_date    DATE,
    dwh_create_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
-- CRM Product Information
-- ============================================================
-- Creates the Silver Layer table for cleaned CRM product data.
--
-- cat_id:
--   Represents the extracted or derived category identifier
--   from the product key during the transformation process.
--
-- Date fields are stored as DATE because the Silver Layer
-- contains standardized date values.
-- ============================================================

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
-- CRM Sales Details
-- ============================================================
-- Creates the Silver Layer table for cleaned sales data.
--
-- Unlike the Bronze Layer, the sales date fields are stored
-- as DATE instead of INT.
--
-- This indicates that the raw numeric date representation
-- from the source system has been converted into a proper
-- SQL Server date format during the transformation process.
-- ============================================================

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,
    sls_ship_dt     DATE,
    sls_due_dt      DATE,
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
-- ERP Location Information
-- ============================================================
-- Creates the Silver Layer table for cleaned ERP location data.
--
-- Possible transformations include:
--   - Standardizing country names
--   - Removing unwanted characters
--   - Handling missing country values
--   - Standardizing customer identifiers
-- ============================================================

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid             NVARCHAR(50),
    cntry           NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
-- ERP Customer Information
-- ============================================================
-- Creates the Silver Layer table for cleaned ERP customer data.
--
-- Possible transformations include:
--   - Standardizing customer identifiers
--   - Validating birth dates
--   - Standardizing gender values
--   - Handling invalid or missing values
-- ============================================================

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid             NVARCHAR(50),
    bdate           DATE,
    gen             NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
-- ERP Product Category Information
-- ============================================================
-- Creates the Silver Layer table for cleaned ERP product
-- category data.
--
-- Possible transformations include:
--   - Standardizing category names
--   - Standardizing subcategory names
--   - Cleaning maintenance values
--   - Handling NULL or invalid values
-- ============================================================

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO
