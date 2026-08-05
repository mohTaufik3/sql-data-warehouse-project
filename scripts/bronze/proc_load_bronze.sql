-- ============================================================
-- Bronze Layer Loading Procedure
-- ============================================================
-- This stored procedure loads raw data from CRM and ERP
-- source CSV files into the Bronze layer.
--
-- Key features:
--   1. TRY...CATCH for error handling
--   2. PRINT statements for ETL process logging
--   3. Execution time tracking using GETDATE() and DATEDIFF()
--   4. Separate timing for each table load
--   5. Batch-level duration tracking for the entire Bronze load
-- ============================================================


CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

    -- Declare variables for tracking ETL execution time.
    DECLARE @start_time DATETIME, @end_time DATETIME;
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;


    BEGIN TRY

        -- ========================================================
        -- Start tracking the entire Bronze Layer loading process.
        -- ========================================================
        SET @batch_start_time = GETDATE();

        PRINT '==================================================';
        PRINT 'STARTING BRONZE LAYER LOAD';
        PRINT '==================================================';


        -- ========================================================
        -- Load CRM Customer Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.crm_cust_info
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> crm_cust_info Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- Load CRM Product Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.crm_prd_info
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> crm_prd_info Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- Load CRM Sales Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.crm_sales_details
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> crm_sales_details Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- Load ERP Customer Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> erp_cust_az12 Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- Load ERP Location Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> erp_loc_a101 Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- Load ERP Product Category Information
        -- ========================================================
        SET @start_time = GETDATE();

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\BUILD-PORTOFOLIO\DataWithBara\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> erp_px_cat_g1v2 Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- ========================================================
        -- End of Bronze Layer loading process.
        -- ========================================================
        SET @batch_end_time = GETDATE();

        PRINT '==================================================';
        PRINT 'BRONZE LAYER LOAD COMPLETED';
        PRINT 'Total Load Duration: '
            + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR)
            + ' seconds';
        PRINT '==================================================';

    END TRY


    -- ============================================================
    -- Error Handling
    -- ============================================================
    BEGIN CATCH

        PRINT '==================================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT '==================================================';

    END CATCH

END;
