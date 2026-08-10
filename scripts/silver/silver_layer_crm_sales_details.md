# Silver Layer — `crm_sales_details`

Documentation for the **data quality checks, date standardization, data consistency validation, and transformation** process applied to the `silver.crm_sales_details` table.

## 1. Overview

The `silver.crm_sales_details` table is created by transforming sales transaction data from the `bronze.crm_sales_details` table.

The transformation process ensures that sales data in the Silver Layer:

* Contains valid and standardized date values.
* Handles invalid date values appropriately.
* Maintains a logical order between order, shipping, and due dates.
* Contains valid sales, quantity, and price values.
* Maintains consistency between sales, quantity, and price.
* Recalculates invalid or inconsistent sales values.
* Recalculates invalid price values when possible.
* Prevents division-by-zero errors during price calculation.

---

# 2. Data Quality Checks — Bronze Layer

Before transforming the data, several data quality checks are performed on `bronze.crm_sales_details`.

---

## 2.1 Check for Invalid Order Dates

**Expectation:** No Result

```sql
SELECT
    NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE
    sls_order_dt <= 0
    OR LEN(sls_order_dt) != 8
    OR sls_order_dt > 20500101
    OR sls_order_dt < 19000101;
```

This check identifies order dates that:

* Are `0` or negative.
* Do not contain exactly 8 digits.
* Are beyond the expected upper date boundary.
* Are earlier than the expected lower date boundary.

The Bronze Layer stores dates in `YYYYMMDD` numeric format.

For example:

```text
20101229
```

represents:

```text
2010-12-29
```

---

## 2.2 Check for Invalid Ship Dates

**Expectation:** No Result

```sql
SELECT
    NULLIF(sls_ship_dt, 0) AS sls_ship_dt
FROM bronze.crm_sales_details
WHERE
    sls_ship_dt <= 0
    OR LEN(sls_ship_dt) != 8
    OR sls_ship_dt > 20500101
    OR sls_ship_dt < 19000101;
```

This validates the shipping date using the same criteria as the order date.

---

## 2.3 Check for Invalid Due Dates

**Expectation:** No Result

```sql
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE
    sls_due_dt <= 0
    OR LEN(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;
```

This validates the due date and identifies invalid numeric date values.

---

# 3. Check for Invalid Date Orders

The relationship between the sales transaction dates should follow a logical sequence:

```text
Order Date ≤ Ship Date
Order Date ≤ Due Date
```

Validation query:

```sql
SELECT *
FROM bronze.crm_sales_details
WHERE
    sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;
```

This identifies records where the order date occurs after either the shipping date or the due date.

---

# 4. Data Consistency Check — Sales, Quantity, and Price

The expected business relationship is:

```text
Sales = Quantity × Price
```

The following validation checks for inconsistencies:

```sql
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
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
```

This identifies records where:

* `sls_sales` is `NULL`.
* `sls_quantity` is `NULL`.
* `sls_price` is `NULL`.
* Sales are zero or negative.
* Quantity is zero or negative.
* Price is zero or negative.
* `Sales ≠ Quantity × Price`.

---

# 5. Transformation Rules

The transformation process applies several business rules to improve data quality.

## 5.1 Date Standardization

The Bronze Layer stores dates as numeric `YYYYMMDD` values.

The transformation converts them into the SQL Server `DATE` data type.

### Transformation Logic

```sql
CASE
    WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8
        THEN NULL
    ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END AS sls_order_dt
```

The same logic is applied to:

* `sls_order_dt`
* `sls_ship_dt`
* `sls_due_dt`

### Example

```text
Bronze:
20101229

        ↓

VARCHAR:
'20101229'

        ↓

DATE:
2010-12-29
```

Invalid values such as `0` or values with an unexpected length are converted to `NULL`.

---

## 5.2 Sales Transformation

The business rule is:

> If Sales is `NULL`, zero, negative, or inconsistent with Quantity × Price, derive Sales from Quantity × Price.

Implementation:

```sql
CASE
    WHEN sls_sales IS NULL
        OR sls_sales <= 0
        OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * sls_price
    ELSE sls_sales
END AS sls_sales
```

### Transformation Rules

| Condition                                | Action                       |
| ---------------------------------------- | ---------------------------- |
| `sls_sales IS NULL`                      | Calculate `quantity × price` |
| `sls_sales <= 0`                         | Calculate `quantity × price` |
| Sales inconsistent with quantity × price | Calculate `quantity × price` |
| Sales is valid                           | Keep original sales          |

---

## 5.3 Price Transformation

The business rule is:

> If Price is `NULL` or less than or equal to zero, derive Price from Sales ÷ Quantity.

Implementation:

```sql
CASE
    WHEN sls_price IS NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
    ELSE sls_price
END AS sls_price
```

### Transformation Rules

| Condition           | Action                       |
| ------------------- | ---------------------------- |
| `sls_price IS NULL` | Calculate `sales ÷ quantity` |
| `sls_price = 0`     | Calculate `sales ÷ quantity` |
| `sls_price < 0`     | Calculate `sales ÷ quantity` |
| Price is valid      | Keep original price          |

---

## 5.4 Prevent Division by Zero

The `NULLIF()` function is used when calculating price:

```sql
sls_sales / NULLIF(sls_quantity, 0)
```

This prevents a division-by-zero error.

When:

```text
sls_quantity = 0
```

the expression:

```sql
NULLIF(sls_quantity, 0)
```

returns `NULL`, preventing SQL Server from attempting to divide by zero.

---

# 6. Bronze → Silver Transformation

The following query transforms the Bronze sales data and inserts it into `silver.crm_sales_details`.

```sql
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
        WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8
            THEN NULL
        ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
    END AS sls_order_dt,

    -- Standardize Ship Date
    CASE
        WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8
            THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt,

    -- Standardize Due Date
    CASE
        WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8
            THEN NULL
        ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
    END AS sls_due_dt,

    -- Recalculate invalid or inconsistent Sales
    CASE
        WHEN sls_sales IS NULL
            OR sls_sales <= 0
            OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * sls_price
        ELSE sls_sales
    END AS sls_sales,

    sls_quantity,

    -- Recalculate invalid Price
    CASE
        WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS sls_price

FROM bronze.crm_sales_details;
```

---

# 7. Silver Layer Data Quality Checks

After the transformation, the resulting `silver.crm_sales_details` table is validated again.

Because the date columns have already been converted to the `DATE` data type, the Silver Layer validation uses actual date comparisons instead of `LEN()` or numeric `YYYYMMDD` comparisons.

---

## 7.1 Check for Invalid Order Dates

**Expectation:** No Result

```sql
SELECT
    sls_order_dt
FROM silver.crm_sales_details
WHERE
    sls_order_dt > '2050-01-01'
    OR sls_order_dt < '1900-01-01';
```

---

## 7.2 Check for Invalid Ship Dates

**Expectation:** No Result

```sql
SELECT
    sls_ship_dt
FROM silver.crm_sales_details
WHERE
    sls_ship_dt > '2050-01-01'
    OR sls_ship_dt < '1900-01-01';
```

---

## 7.3 Check for Invalid Due Dates

**Expectation:** No Result

```sql
SELECT
    sls_due_dt
FROM silver.crm_sales_details
WHERE
    sls_due_dt > '2050-01-01'
    OR sls_due_dt < '1900-01-01';
```

`NULL` values are not treated as invalid here because invalid Bronze date values are intentionally converted to `NULL` during the transformation.

---

## 7.4 Check for Invalid Date Orders

**Expectation:** No Result

```sql
SELECT *
FROM silver.crm_sales_details
WHERE
    sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;
```

This ensures that the order date does not occur after the shipping or due date.

---

## 7.5 Check Sales, Quantity, and Price Consistency

**Expectation:** No Result

```sql
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
```

This verifies that the transformation has successfully produced valid and consistent sales metrics.

---

# 8. Transformation Summary

| Data Issue                     | Transformation          | Result                                    |
| ------------------------------ | ----------------------- | ----------------------------------------- |
| Invalid order date             | `CASE` + `CAST()`       | Invalid values converted to `NULL`        |
| Invalid ship date              | `CASE` + `CAST()`       | Invalid values converted to `NULL`        |
| Invalid due date               | `CASE` + `CAST()`       | Invalid values converted to `NULL`        |
| Invalid date order             | Data quality validation | Logical date sequence enforced            |
| `NULL` / zero / negative sales | `CASE`                  | Sales derived from quantity × price       |
| Inconsistent sales             | `CASE`                  | Sales recalculated                        |
| `NULL` / zero / negative price | `CASE`                  | Price derived from sales ÷ quantity       |
| Quantity = 0                   | `NULLIF()`              | Division-by-zero prevented                |
| Bronze → Silver                | `INSERT INTO`           | Transformed data loaded into Silver Layer |

---

# 9. Final Data Quality Expectations

After the transformation process, `silver.crm_sales_details` should meet the following requirements:

* Date values are stored using the `DATE` data type.
* Invalid Bronze date values are converted to `NULL`.
* Order dates fall within the expected date range.
* Ship dates fall within the expected date range.
* Due dates fall within the expected date range.
* Order dates do not occur after ship dates.
* Order dates do not occur after due dates.
* `sls_sales` contains valid positive values.
* `sls_quantity` contains valid positive values.
* `sls_price` contains valid positive values.
* Sales values are consistent with quantity × price.
* Missing or invalid sales values are recalculated.
* Missing or invalid price values are recalculated where possible.
* Division-by-zero errors are prevented using `NULLIF()`.

---

## Summary

The `crm_sales_details` transformation follows the workflow:

```text
Bronze Layer
     ↓
Data Quality Checks
     ↓
Identify Invalid Dates
     ↓
Validate Date Relationships
     ↓
Validate Sales / Quantity / Price Consistency
     ↓
Standardize Date Values
     ↓
Fix Invalid Sales
     ↓
Fix Invalid Price
     ↓
Load into Silver Layer
     ↓
Silver Layer Validation
     ↓
Clean Sales Transaction Data
```
