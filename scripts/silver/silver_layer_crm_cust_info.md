# Silver Layer — `crm_cust_info`

Documentation for the **data cleaning, standardization, deduplication, and transformation** process applied to the `silver.crm_cust_info` table.

## 1. Overview

The `silver.crm_cust_info` table is created by transforming data from the `bronze.crm_cust_info` table.

The transformation process ensures that customer data in the Silver Layer:

* Does not contain `NULL` values in the primary key.
* Does not contain duplicate customer records.
* Does not contain unwanted spaces in customer names.
* Has standardized and consistent values.
* Has standardized `cst_marital_status` values.
* Has standardized `cst_gndr` values.
* Keeps only the latest record when duplicate customer records are found.

---

## 2. Data Quality Checks — Bronze Layer

Before performing the transformation, several data quality checks are conducted on `bronze.crm_cust_info`.

### 2.1 Check for NULL or Duplicate Primary Keys

**Expectation:** No Result

```sql
SELECT
    cst_id,
    COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;
```

This query identifies:

* `cst_id` values that are `NULL`.
* `cst_id` values that occur more than once.

Since `cst_id` is used as the primary key, each customer should have a unique identifier.

> **Note:** `IS NULL` is used instead of `= NULL` because SQL requires `IS NULL` for NULL comparisons.

---

### 2.2 Check for Unwanted Spaces

**Expectation:** No Result

#### First Name

```sql
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);
```

#### Last Name

```sql
SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);
```

These queries identify customer names containing unwanted spaces at the beginning or end of the values.

---

### 2.3 Data Standardization & Consistency

#### Customer Gender

```sql
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info;
```

#### Customer Marital Status

```sql
SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info;
```

These checks are used to identify the different values available in the source data before standardization is applied.

---

### 2.4 Investigate a Specific Customer Record

```sql
SELECT *
FROM bronze.crm_cust_info
WHERE cst_key = 'PO25';
```

This query can be used to investigate a specific customer record when a potential data quality issue is identified.

---

# 3. Silver Layer

After the data cleaning and transformation process, the cleaned data is inserted into:

```text
silver.crm_cust_info
```

## 3.1 Silver Layer Data Quality Checks

The transformed data is validated again to ensure that the expected data quality requirements have been met.

### Check for NULL or Duplicate Primary Keys

**Expectation:** No Result

```sql
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;
```

This ensures that `cst_id` values are unique and not `NULL` after transformation.

---

### Check for Unwanted Spaces

**Expectation:** No Result

#### First Name

```sql
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);
```

#### Last Name

```sql
SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);
```

These checks ensure that unwanted spaces have been successfully removed.

---

### Check Standardized Values

#### Customer Gender

```sql
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;
```

#### Customer Marital Status

```sql
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;
```

Expected standardized values:

* `cst_gndr` → `Male`, `Female`, or `n/a`
* `cst_marital_status` → `Single`, `Married`, or `n/a`

---

### Review Transformed Data

```sql
SELECT *
FROM silver.crm_cust_info;
```

This query provides a final overview of the transformed customer data.

---

# 4. Data Transformation

The transformation process is based on the data quality issues identified in the Bronze Layer.

The main issues include:

* Duplicate customer records.
* Potential `NULL` or invalid values.
* Unwanted spaces in customer names.
* Inconsistent `cst_marital_status` values.
* Inconsistent `cst_gndr` values.

---

## 4.1 Deduplication

When multiple records have the same `cst_id`, only the most recent record is retained based on `cst_create_date`.

The following window function is used:

```sql
ROW_NUMBER() OVER (
    PARTITION BY cst_id
    ORDER BY cst_create_date DESC
)
```

The records are partitioned by `cst_id` and ordered by `cst_create_date` in descending order.

As a result, the most recent record receives:

```text
flag_last = 1
```

Only this record is retained in the Silver Layer.

---

## 4.2 Remove Unwanted Spaces

The `TRIM()` function is applied to:

* `cst_firstname`
* `cst_lastname`

Example:

```sql
TRIM(cst_firstname) AS cst_firstname,
TRIM(cst_lastname) AS cst_lastname
```

This removes unnecessary leading and trailing spaces from customer names.

---

## 4.3 Standardization of Marital Status

The `cst_marital_status` column is standardized using a `CASE` expression.

| Original Value | Standardized Value |
| -------------- | ------------------ |
| `S`            | `Single`           |
| `M`            | `Married`          |
| Other / NULL   | `n/a`              |

Implementation:

```sql
CASE
    WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
    WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
    ELSE 'n/a'
END AS cst_marital_status
```

`TRIM()` removes unwanted spaces, while `UPPER()` ensures that the standardization is not affected by letter casing.

---

## 4.4 Standardization of Gender

The `cst_gndr` column is standardized using a `CASE` expression.

| Original Value | Standardized Value |
| -------------- | ------------------ |
| `F`            | `Female`           |
| `M`            | `Male`             |
| Other / NULL   | `n/a`              |

Implementation:

```sql
CASE
    WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
    WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
    ELSE 'n/a'
END AS cst_gndr
```

---

# 5. Bronze → Silver Transformation

The following query performs the transformation from the Bronze Layer into the Silver Layer:

```sql
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
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM bronze.crm_cust_info
) t
WHERE flag_last = 1;
```

### Transformation Logic

The transformation performs the following operations:

1. **Deduplication**

   * Partitions records by `cst_id`.
   * Sorts records by `cst_create_date DESC`.
   * Keeps only the latest record using `flag_last = 1`.

2. **Name Cleaning**

   * Removes leading and trailing spaces from `cst_firstname` and `cst_lastname`.

3. **Marital Status Standardization**

   * `S` → `Single`
   * `M` → `Married`
   * Other values → `n/a`

4. **Gender Standardization**

   * `F` → `Female`
   * `M` → `Male`
   * Other values → `n/a`

---

# 6. Transformation Summary

| Data Issue                          | Transformation                | Result                                       |
| ----------------------------------- | ----------------------------- | -------------------------------------------- |
| Duplicate `cst_id`                  | `ROW_NUMBER()`                | Only the latest record is retained           |
| `NULL` / invalid categorical values | `CASE ... ELSE 'n/a'`         | Invalid values are handled                   |
| Unwanted spaces                     | `TRIM()`                      | Leading and trailing spaces are removed      |
| Inconsistent marital status         | `CASE` + `UPPER()` + `TRIM()` | `Single` / `Married`                         |
| Inconsistent gender                 | `CASE` + `UPPER()` + `TRIM()` | `Male` / `Female`                            |
| Bronze → Silver                     | `INSERT INTO`                 | Cleaned data is loaded into the Silver Layer |

---

# 7. Final Data Quality Expectations

After the transformation process, `silver.crm_cust_info` should meet the following requirements:

* `cst_id` contains no `NULL` values.
* No duplicate `cst_id` values exist.
* `cst_firstname` contains no unwanted leading or trailing spaces.
* `cst_lastname` contains no unwanted leading or trailing spaces.
* `cst_marital_status` contains standardized values.
* `cst_gndr` contains standardized values.
* Only the latest customer record is retained when duplicates exist.
* The data is ready for further processing within the Silver Layer.

     ↓
Clean Customer Data
```
