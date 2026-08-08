# Silver Layer — `crm_prd_info`

Documentation for the **data quality checks, data cleaning, standardization, date handling, and transformation** process applied to the `silver.crm_prd_info` table.

## 1. Overview

The `silver.crm_prd_info` table is created by transforming product data from the `bronze.crm_prd_info` table.

The transformation process ensures that product data in the Silver Layer:

* Does not contain duplicate or `NULL` product IDs.
* Does not contain unwanted spaces in product names.
* Handles missing product costs.
* Does not contain negative product costs.
* Has standardized product line values.
* Has properly formatted date values.
* Has correctly derived product end dates based on the next product start date.
* Has a standardized `cat_id` and `prd_key` extracted from the original product key.

---

# 2. Source Data Exploration

Before performing data quality checks, the source tables can be inspected to understand the available data.

### Product Category Data

```sql
SELECT *
FROM bronze.erp_px_cat_g1v2;
```

### Sales Details Data

```sql
SELECT *
FROM bronze.crm_sales_details;
```

These queries provide an overview of related source data that can be used to understand the product and sales structure.

---

# 3. Data Quality Checks — Bronze Layer

Several data quality checks are performed on `bronze.crm_prd_info` before the transformation process.

## 3.1 Check for Duplicate or NULL Product IDs

**Expectation:** No Result

```sql
SELECT
    prd_id,
    COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;
```

This query identifies product IDs that:

* Are `NULL`.
* Appear more than once.

Since `prd_id` is used as the product identifier, each product should have a unique and valid ID.

---

## 3.2 Check for Unwanted Spaces

**Expectation:** No Result

```sql
SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);
```

This query identifies product names containing unwanted leading or trailing spaces.

---

## 3.3 Check for NULL or Negative Product Costs

**Expectation:** No Result

```sql
SELECT
    prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL
    OR prd_cost < 0;
```

This check identifies:

* Missing product costs.
* Negative product costs.

Product costs should not contain negative values. Missing values are handled during the transformation process.

---

## 3.4 Data Standardization & Consistency

```sql
SELECT DISTINCT
    prd_line
FROM bronze.crm_prd_info;
```

This query identifies the different product line values available in the source data before standardization.

---

## 3.5 Check for Invalid Date Orders

```sql
SELECT *
FROM bronze.crm_prd_info
WHERE prd_start_dt > prd_end_dt;
```

This check identifies records where the product start date occurs after the product end date.

A valid product date range should satisfy:

```text
prd_start_dt <= prd_end_dt
```

---

# 4. Data Transformation

The transformation process addresses the data quality issues identified in the Bronze Layer.

The main transformations include:

* Extracting `cat_id` from `prd_key`.
* Extracting and standardizing `prd_key`.
* Handling missing product costs.
* Standardizing product line values.
* Converting datetime values to `DATE`.
* Generating product end dates using the next product start date.

---

## 4.1 Extract `cat_id`

The category ID is extracted from the first five characters of the original `prd_key`.

```sql
REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id
```

The `REPLACE()` function converts the `-` separator into `_`.

For example:

```text
Original:    AC-HE
Result:      AC_HE
```

This creates a standardized category identifier.

---

## 4.2 Extract `prd_key`

The product key is extracted from the original `prd_key` starting from the seventh character.

```sql
SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key
```

This separates the product identifier from the category portion of the original key.

---

## 4.3 Handle Missing Product Costs

Missing product costs are replaced with `0` using `ISNULL()`.

```sql
ISNULL(prd_cost, 0) AS prd_cost
```

This ensures that the Silver Layer does not contain `NULL` values in `prd_cost`.

---

## 4.4 Standardize Product Line

The product line values are standardized using `CASE`, `UPPER()`, and `TRIM()`.

| Original Value | Standardized Value |
| -------------- | ------------------ |
| `M`            | `Mountain`         |
| `R`            | `Road`             |
| `S`            | `Other Sales`      |
| `T`            | `Touring`          |
| Other / NULL   | `n/a`              |

Implementation:

```sql
CASE UPPER(TRIM(prd_line))
    WHEN 'M' THEN 'Mountain'
    WHEN 'R' THEN 'Road'
    WHEN 'S' THEN 'Other Sales'
    WHEN 'T' THEN 'Touring'
    ELSE 'n/a'
END AS prd_line
```

`TRIM()` removes unwanted spaces, while `UPPER()` ensures that the mapping is not affected by letter casing.

---

## 4.5 Standardize Date Format

The product start date is explicitly converted to the `DATE` data type:

```sql
CAST(prd_start_dt AS DATE) AS prd_start_dt
```

This removes the time component when the source column contains datetime values.

---

## 4.6 Derive Product End Date

The product end date is calculated using the `LEAD()` window function.

```sql
CAST(
    LEAD(prd_start_dt)
        OVER (
            PARTITION BY prd_key
            ORDER BY prd_start_dt
        ) - 1
    AS DATE
) AS prd_end_dt
```

The logic works as follows:

1. Records are grouped by `prd_key`.
2. Records are ordered by `prd_start_dt`.
3. `LEAD()` retrieves the next start date.
4. One day is subtracted from the next start date.
5. The result becomes the current record's `prd_end_dt`.

For example:

| `prd_key` | `prd_start_dt` | Derived `prd_end_dt` |
| --------- | -------------- | -------------------- |
| Product A | 2024-01-01     | 2024-05-31           |
| Product A | 2024-06-01     | 2024-12-31           |
| Product A | 2025-01-01     | `NULL`               |

The final record has no following start date, so its `prd_end_dt` remains `NULL`.

---

# 5. Bronze → Silver Transformation

The following query performs the transformation from the Bronze Layer into the Silver Layer:

```sql
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
     prd_id
    ,REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id
    ,SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key
    ,prd_nm
    ,ISNULL(prd_cost, 0) AS prd_cost
    ,CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
     END AS prd_line
    ,CAST(prd_start_dt AS DATE) AS prd_start_dt
    ,CAST(
        LEAD(prd_start_dt)
            OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            ) - 1
        AS DATE
     ) AS prd_end_dt
FROM bronze.crm_prd_info;
```

---

# 6. Silver Layer Data Quality Checks

After the transformation, the resulting `silver.crm_prd_info` table is validated again.

## 6.1 Check for Duplicate or NULL Product IDs

**Expectation:** No Result

```sql
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;
```

This ensures that product IDs are unique and not `NULL`.

---

## 6.2 Check for Unwanted Spaces

**Expectation:** No Result

```sql
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);
```

This ensures that unwanted leading and trailing spaces have been removed.

---

## 6.3 Check for NULL or Negative Product Costs

**Expectation:** No Result

```sql
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL
    OR prd_cost < 0;
```

Because missing costs are replaced with `0`, the expectation is that this query returns no result.

---

## 6.4 Check Standardized Product Lines

```sql
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;
```

Expected values:

* `Mountain`
* `Road`
* `Other Sales`
* `Touring`
* `n/a`

---

## 6.5 Check for Invalid Date Orders

```sql
SELECT *
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;
```

**Expectation:** No Result

This ensures that the derived date ranges are logically valid.

---

## 6.6 Check Silver Layer Record Count

```sql
SELECT COUNT(*)
FROM silver.crm_prd_info;
```

This query is used to verify the total number of records loaded into the Silver Layer.

---

# 7. Transformation Summary

| Data Issue / Requirement       | Transformation                | Result                                  |
| ------------------------------ | ----------------------------- | --------------------------------------- |
| Duplicate / NULL `prd_id`      | Data quality validation       | Product IDs are validated               |
| Unwanted spaces                | `TRIM()`                      | Leading and trailing spaces are removed |
| NULL `prd_cost`                | `ISNULL()`                    | Missing costs are replaced with `0`     |
| Negative `prd_cost`            | Data quality validation       | Negative costs are identified           |
| Inconsistent `prd_line`        | `CASE` + `UPPER()` + `TRIM()` | Standardized product line values        |
| Complex `prd_key`              | `SUBSTRING()`                 | Product key is extracted                |
| Category embedded in `prd_key` | `SUBSTRING()` + `REPLACE()`   | Standardized `cat_id`                   |
| Datetime values                | `CAST(... AS DATE)`           | Standardized date format                |
| Product date range             | `LEAD()`                      | Product end date is derived             |
| Bronze → Silver                | `INSERT INTO`                 | Transformed data is loaded into Silver  |

---

# 8. Final Data Quality Expectations

After the transformation process, `silver.crm_prd_info` should meet the following requirements:

* `prd_id` contains no `NULL` values.
* No duplicate `prd_id` values exist.
* `prd_nm` contains no unwanted leading or trailing spaces.
* `prd_cost` contains no `NULL` values.
* `prd_cost` contains no negative values.
* `prd_line` contains standardized values.
* `cat_id` is extracted and standardized from the original product key.
* `prd_key` is extracted into a consistent format.
* `prd_start_dt` is stored as a `DATE`.
* `prd_end_dt` is correctly derived from the next product start date.
* No record has `prd_start_dt > prd_end_dt`.
* The final record count can be verified after loading.
