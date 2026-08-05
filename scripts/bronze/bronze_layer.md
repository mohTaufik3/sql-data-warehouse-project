# Bronze Layer – Data Warehouse

## 1. Overview

The **Bronze Layer** is the first layer in the Data Warehouse architecture. It is responsible for storing raw data directly from source systems without significant transformation.

In this project, the Bronze Layer receives data from two source systems:

* **CRM (Customer Relationship Management)**
* **ERP (Enterprise Resource Planning)**

The source data is stored in CSV files and loaded into SQL Server using the `BULK INSERT` statement.

### Bronze Layer Architecture

```text
Source CSV Files
       │
       ├── CRM
       │   ├── cust_info.csv
       │   ├── prd_info.csv
       │   └── sales_details.csv
       │
       └── ERP
           ├── CUST_AZ12.csv
           ├── LOC_A101.csv
           └── PX_CAT_G1V2.csv
                    │
                    ▼
             BULK INSERT
                    │
                    ▼
             Bronze Layer
                    │
                    ├── crm_cust_info
                    ├── crm_prd_info
                    ├── crm_sales_details
                    ├── erp_cust_az12
                    ├── erp_loc_a101
                    └── erp_px_cat_g1v2
```

The Bronze Layer is intentionally kept close to the original source data. Data cleaning, transformation, standardization, and business logic are handled in later layers.

---

# 2. Bronze Layer Objectives

The main objectives of the Bronze Layer are:

1. Store raw data from source systems.
2. Preserve the original source data structure as much as possible.
3. Provide a reliable starting point for downstream data transformation.
4. Separate raw data ingestion from data cleaning and business logic.
5. Make the ETL process easier to monitor and troubleshoot.

---

# 3. Source Systems

The project uses two primary source systems.

## 3.1 CRM

The CRM source contains customer, product, and sales-related information.

| Source File         | Target Table               | Description                   |
| ------------------- | -------------------------- | ----------------------------- |
| `cust_info.csv`     | `bronze.crm_cust_info`     | Customer information          |
| `prd_info.csv`      | `bronze.crm_prd_info`      | Product information           |
| `sales_details.csv` | `bronze.crm_sales_details` | Sales transaction information |

## 3.2 ERP

The ERP source contains additional customer, location, and product category information.

| Source File       | Target Table             | Description                   |
| ----------------- | ------------------------ | ----------------------------- |
| `CUST_AZ12.csv`   | `bronze.erp_cust_az12`   | ERP customer information      |
| `LOC_A101.csv`    | `bronze.erp_loc_a101`    | Customer location information |
| `PX_CAT_G1V2.csv` | `bronze.erp_px_cat_g1v2` | Product category information  |

---

# 4. Loading Data Using BULK INSERT

SQL Server provides the `BULK INSERT` statement to efficiently load large amounts of data from external files into database tables.

The basic syntax is:

```sql
BULK INSERT schema.table_name
FROM 'file_path'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);
```

## 4.1 BULK INSERT Options

### `FIRSTROW = 2`

```sql
FIRSTROW = 2
```

The CSV files contain a header row.

For example:

```text
cst_id,cst_key,cst_firstname,cst_lastname
1,AW00011000,John,Doe
2,AW00011001,Jane,Smith
```

The first row contains column names rather than actual data.

Therefore:

```sql
FIRSTROW = 2
```

tells SQL Server to start loading data from the second row.

---

### `FIELDTERMINATOR = ','`

```sql
FIELDTERMINATOR = ','
```

This tells SQL Server that the columns in the CSV file are separated by commas.

For example:

```text
1,AW00011000,John,Doe
```

is interpreted as:

```text
1
AW00011000
John
Doe
```

---

### `TABLOCK`

```sql
TABLOCK
```

Requests a table-level lock during the bulk loading operation and can improve the performance of bulk data loading.

---

# 5. Creating the Bronze Loading Procedure

Instead of manually executing every `BULK INSERT` statement, the loading process is grouped into a stored procedure:

```sql
CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    ...
END;
```

The procedure is named:

```text
bronze.load_bronze
```

This follows the naming convention:

```text
schema.procedure_name
```

The procedure acts as a single entry point for loading all raw data into the Bronze Layer.

---

# 6. Execution Time Tracking

The ETL process includes execution time tracking to measure how long each loading operation takes.

Two variables are used:

```sql
DECLARE @start_time DATETIME,
        @end_time DATETIME;
```

The start time is recorded before the operation:

```sql
SET @start_time = GETDATE();
```

The end time is recorded after the operation:

```sql
SET @end_time = GETDATE();
```

The duration is calculated using:

```sql
DATEDIFF(SECOND, @start_time, @end_time)
```

For example:

```sql
PRINT '>> Load Duration: '
    + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
    + ' seconds';
```

This helps identify:

* Slow loading operations
* Performance bottlenecks
* Changes in ETL execution time
* Potential performance issues

---

# 7. Batch-Level Execution Time

In addition to measuring each individual table, the entire Bronze Layer loading process can be measured.

Variables:

```sql
DECLARE @batch_start_time DATETIME,
        @batch_end_time DATETIME;
```

Start the timer before the first `BULK INSERT`:

```sql
SET @batch_start_time = GETDATE();
```

Stop the timer after the last `BULK INSERT`:

```sql
SET @batch_end_time = GETDATE();
```

Then calculate the total duration:

```sql
DATEDIFF(SECOND, @batch_start_time, @batch_end_time)
```

This provides the total execution time for the entire Bronze Layer loading process.

---

# 8. Error Handling with TRY...CATCH

The procedure uses SQL Server's `TRY...CATCH` mechanism to handle errors.

Basic structure:

```sql
BEGIN TRY

    -- ETL operations

END TRY

BEGIN CATCH

    -- Error handling

END CATCH
```

SQL Server executes the statements inside the `TRY` block.

If an error occurs, execution moves to the `CATCH` block.

This makes the ETL process easier to debug.

---

# 9. Error Logging

The `CATCH` block uses SQL Server error functions to provide useful debugging information.

### Error message

```sql
ERROR_MESSAGE()
```

Returns the descriptive error message.

### Error number

```sql
ERROR_NUMBER()
```

Returns the SQL Server error number.

### Error state

```sql
ERROR_STATE()
```

Returns the error state number.

### Error line

```sql
ERROR_LINE()
```

Returns the line number where the error occurred.

Example:

```sql
PRINT 'Error Message: ' + ERROR_MESSAGE();
PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
```

This information can help identify exactly where and why the ETL process failed.

---

# 10. Complete Bronze Loading Procedure

The following procedure combines:

* `BULK INSERT`
* Execution time tracking
* Batch duration tracking
* `TRY...CATCH`
* Error logging
* ETL progress logging

---

# 11. How to Execute the Procedure

After creating the procedure, execute it using:

```sql
EXEC bronze.load_bronze;
```

This command triggers the entire Bronze Layer loading process.

You do not need to execute every `BULK INSERT` statement manually.

The procedure will execute the loading process in sequence:

```text
EXEC bronze.load_bronze
        │
        ▼
CRM Customer
        │
        ▼
CRM Product
        │
        ▼
CRM Sales
        │
        ▼
ERP Customer
        │
        ▼
ERP Location
        │
        ▼
ERP Product Category
        │
        ▼
Bronze Layer Completed
```

---

# 12. Verifying the Loaded Data

After the procedure completes successfully, verify the data using `SELECT`.

For example:

```sql
SELECT TOP 5 *
FROM bronze.crm_cust_info;
```

You can check other tables using:

```sql
SELECT TOP 5 *
FROM bronze.crm_prd_info;

SELECT TOP 5 *
FROM bronze.crm_sales_details;

SELECT TOP 5 *
FROM bronze.erp_cust_az12;

SELECT TOP 5 *
FROM bronze.erp_loc_a101;

SELECT TOP 5 *
FROM bronze.erp_px_cat_g1v2;
```

---

# 13. Checking Row Counts

To verify how many records were loaded:

```sql
SELECT COUNT(*) AS total_records
FROM bronze.crm_cust_info;
```

The same approach can be used for the other tables:

```sql
SELECT COUNT(*) AS total_records
FROM bronze.crm_prd_info;

SELECT COUNT(*) AS total_records
FROM bronze.crm_sales_details;

SELECT COUNT(*) AS total_records
FROM bronze.erp_cust_az12;

SELECT COUNT(*) AS total_records
FROM bronze.erp_loc_a101;

SELECT COUNT(*) AS total_records
FROM bronze.erp_px_cat_g1v2;
```

---

# 14. Important: Avoiding Duplicate Data

One important consideration when using `BULK INSERT` is that executing the procedure multiple times can insert the same data repeatedly.

For example:

```text
First execution
CSV → Bronze Table
100 records

Second execution
CSV → Bronze Table
100 additional records

Total = 200 records
```

If the source file has not changed, the second execution may create duplicate records.

Before reloading the Bronze Layer, the table can be cleared using:

```sql
TRUNCATE TABLE bronze.crm_cust_info;
```

The same approach can be applied to the other tables.

However, `TRUNCATE TABLE` should be used carefully because it removes all records from the target table.

---

# 15. Recommended Reload Sequence

If the Bronze Layer needs to be completely reloaded from the source files:

```text
1. Clear existing Bronze tables
          ↓
2. Execute bronze.load_bronze
          ↓
3. BULK INSERT source CSV files
          ↓
4. Check execution logs
          ↓
5. Verify row counts
          ↓
6. Preview sample records
```

---

# 16. Example Verification Workflow

### Step 1 – Execute the procedure

```sql
EXEC bronze.load_bronze;
```

### Step 2 – Check the execution messages

Look at the **Messages** tab in SSMS.

Expected output:

```text
==================================================
STARTING BRONZE LAYER LOAD
==================================================

>> crm_cust_info Load Duration: 1 seconds
>> crm_prd_info Load Duration: 0 seconds
>> crm_sales_details Load Duration: 2 seconds
>> erp_cust_az12 Load Duration: 1 seconds
>> erp_loc_a101 Load Duration: 0 seconds
>> erp_px_cat_g1v2 Load Duration: 0 seconds

==================================================
BRONZE LAYER LOAD COMPLETED
Total Load Duration: 4 seconds
==================================================
```

### Step 3 – Check the row count

```sql
SELECT COUNT(*)
FROM bronze.crm_cust_info;
```

### Step 4 – Preview the data

```sql
SELECT TOP 5 *
FROM bronze.crm_cust_info;
```

---

# 17. Understanding the ETL Flow

The Bronze Layer represents the **Extract and Load** portion of the overall ETL process.

```text
                SOURCE SYSTEMS
                     │
             ┌───────┴───────┐
             │               │
            CRM             ERP
             │               │
             └───────┬───────┘
                     │
                     ▼
               CSV FILES
                     │
                     ▼
                BULK INSERT
                     │
                     ▼
             ┌───────────────┐
             │ BRONZE LAYER  │
             │               │
             │ Raw Data      │
             │ Unprocessed   │
             └───────┬───────┘
                     │
                     ▼
             SILVER LAYER
             Cleaning &
             Transformation
                     │
                     ▼
              GOLD LAYER
              Business-Ready
              Data & Analytics
```

The Bronze Layer should generally avoid business transformations. Its primary responsibility is to capture and preserve source data so that downstream processes can work from a consistent raw-data foundation.

---

# 18. Key SQL Server Concepts Used

This Bronze Layer implementation introduces several important SQL Server concepts:

| Concept                     | Purpose                                   |
| --------------------------- | ----------------------------------------- |
| `CREATE OR ALTER PROCEDURE` | Create or update a stored procedure       |
| `BULK INSERT`               | Load data from external files             |
| `TRY...CATCH`               | Handle runtime errors                     |
| `GETDATE()`                 | Retrieve the current date and time        |
| `DATEDIFF()`                | Calculate the difference between dates    |
| `DECLARE`                   | Declare variables                         |
| `SET`                       | Assign values to variables                |
| `PRINT`                     | Display execution messages                |
| `ERROR_MESSAGE()`           | Retrieve error details                    |
| `ERROR_NUMBER()`            | Retrieve SQL Server error number          |
| `ERROR_STATE()`             | Retrieve error state                      |
| `ERROR_LINE()`              | Retrieve the line where an error occurred |
| `TRUNCATE TABLE`            | Remove all records from a table           |
| `TOP`                       | Limit the number of returned rows         |

---

# 19. Notes for GitHub

The current implementation uses local Windows file paths such as:

```text
D:\BUILD-PORTOFOLIO\DataWithBara\...
```

These paths are specific to the development environment and will not work automatically on another machine.

For a more portable implementation, the file paths should eventually be moved into a configuration mechanism or adjusted according to the local environment.

Additionally, the source CSV files may contain sensitive or proprietary data. Before publishing the repository publicly, verify that the data is safe to share.

---

# 20. Summary

The Bronze Layer is responsible for ingesting raw source data into the Data Warehouse.

The implementation in this project provides:

* Raw data ingestion from CRM and ERP CSV files.
* Centralized loading through a stored procedure.
* Bulk loading using `BULK INSERT`.
* ETL execution-time monitoring.
* Batch-level duration tracking.
* Error handling using `TRY...CATCH`.
* Error logging using SQL Server error functions.
* Data validation through row counts and sample queries.

The main execution command is:

```sql
EXEC bronze.load_bronze;
```

This procedure provides a reusable foundation for the next stages of the Data Warehouse pipeline, where the raw Bronze data can be cleaned and transformed into the **Silver Layer**, followed by business-ready datasets in the **Gold Layer**.
