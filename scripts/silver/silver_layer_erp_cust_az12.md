# Silver Layer — `erp_cust_az12`

Documentation for the **data quality checks, standardization, and transformation** process applied to the `silver.erp_cust_az12` table.

## 1. Overview

The `silver.erp_cust_az12` table is created by transforming customer demographic data from the `bronze.erp_cust_az12` table.

The transformation process focuses on:

* Ensuring consistency between ERP customer IDs and CRM customer IDs.
* Standardizing customer IDs by removing unnecessary prefixes.
* Identifying invalid future birth dates.
* Standardizing gender values.
* Handling missing or unrecognized gender values.
* Preparing the data for integration with other customer-related tables.

---

# 2. Data Quality Checks — Bronze Layer

Before transforming the data, several data quality checks are performed on `bronze.erp_cust_az12`.

---

## 2.1 Checking Consistency Between Tables

The customer ID from the ERP system is compared with the customer ID from the CRM system.

```sql
SELECT TOP(5)
    cid
FROM bronze.erp_cust_az12;

SELECT TOP(5)
    cst_id
FROM silver.crm_cust_info;
```

### Example Result

ERP customer ID:

```text
NASAW00011000
NASAW00011001
NASAW00011002
NASAW00011003
NASAW00011004
```

CRM customer ID:

```text
11000
11001
11002
11003
```

### Issue Identified

The ERP customer ID contains an additional prefix:

```text
NASAW
```

For example:

```text
NASAW00011000
```

while the corresponding CRM customer ID is:

```text
11000
```

Therefore, the ERP customer ID requires transformation before it can be consistently integrated with the CRM customer data.

---

# 3. Identify Out-of-Range Birth Dates

```sql
SELECT DISTINCT
    bdate
FROM bronze.erp_cust_az12
WHERE
    bdate < '1924-01-01'
    OR bdate > GETDATE();
```

This validation identifies birth dates that fall outside the expected range.

### Business Rule

A customer birth date is considered invalid if:

* The date is later than the current date.
* The date is earlier than the expected minimum date of `1924-01-01`.

The transformation specifically handles **future birth dates** by converting them to `NULL`.

---

# 4. Data Standardization and Consistency — Gender

```sql
SELECT DISTINCT
    gen
FROM bronze.erp_cust_az12;
```

The source data contains multiple representations of gender, such as:

```text
F
Female
M
Male
NULL
Blank
```

These values need to be standardized to ensure consistency in the Silver Layer.

### Standardization Rules

| Source Value | Standardized Value |
| ------------ | ------------------ |
| `F`          | `Female`           |
| `FEMALE`     | `Female`           |
| `M`          | `Male`             |
| `MALE`       | `Male`             |
| `NULL`       | `n/a`              |
| Blank        | `n/a`              |
| Other values | `n/a`              |

---

# 5. Transformation Logic

## 5.1 Customer ID Standardization

The ERP customer ID may contain a `NAS` prefix.

The transformation checks whether the ID starts with `NAS`:

```sql
CASE
    WHEN cid LIKE 'NAS%'
        THEN SUBSTRING(cid, 4, LEN(cid))
    ELSE cid
END AS cid
```

### Example

```text
Source:
NASAW00011000

        ↓

Remove first 3 characters:
AW00011000
```

If the customer ID does not start with `NAS`, the original value is preserved.

> **Note:** The transformation follows the existing source-system logic using `SUBSTRING(cid, 4, LEN(cid))`. This removes the first three characters rather than removing the entire `NASAW` prefix.

---

# 6. Birth Date Transformation

Future birth dates are considered invalid and are converted to `NULL`.

```sql
CASE
    WHEN bdate > GETDATE()
        THEN NULL
    ELSE bdate
END AS bdate
```

### Example

```text
Valid:
1995-06-15
        ↓
1995-06-15

Invalid:
2055-01-23
        ↓
NULL
```

This approach preserves the customer record while removing an invalid demographic value.

---

# 7. Gender Transformation

Gender values are standardized using `UPPER()` and `TRIM()`.

```sql
CASE
    WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
        THEN 'Female'
    WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
        THEN 'Male'
    ELSE 'n/a'
END AS gen
```

### Transformation Logic

```text
F / Female
     ↓
Female

M / Male
     ↓
Male

NULL / Blank / Other
     ↓
n/a
```

### Why `UPPER()` and `TRIM()`?

`TRIM()` removes unwanted leading and trailing spaces.

For example:

```text
' M '
```

becomes:

```text
'M'
```

`UPPER()` ensures that values such as:

```text
m
M
male
Male
MALE
```

can be evaluated consistently.

---

# 8. Bronze → Silver Transformation

The following query loads the transformed customer demographic data into `silver.erp_cust_az12`.

```sql
INSERT INTO silver.erp_cust_az12 (
    cid,
    bdate,
    gen
)
SELECT
    CASE
        WHEN cid LIKE 'NAS%'
            THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END AS cid,

    CASE
        WHEN bdate > GETDATE()
            THEN NULL
        ELSE bdate
    END AS bdate,

    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
            THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
            THEN 'Male'
        ELSE 'n/a'
    END AS gen

FROM bronze.erp_cust_az12;
```

---

# 9. Silver Layer Validation

After the transformation, the resulting `silver.erp_cust_az12` table is validated again.

---

## 9.1 Checking Consistency Between Tables

```sql
SELECT TOP(5)
    cid
FROM silver.erp_cust_az12;

SELECT TOP(5)
    cst_id
FROM silver.crm_cust_info;
```

This verifies that customer IDs in the Silver ERP table can be aligned with the CRM customer IDs.

---

## 9.2 Identify Out-of-Range Birth Dates

```sql
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE
    bdate < '1924-01-01'
    OR bdate > GETDATE();
```

**Expectation:** No Result

Future dates should no longer exist after the transformation because they have been converted to `NULL`.

---

## 9.3 Data Standardization and Consistency — Gender

```sql
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;
```

### Expected Values

The Silver Layer should contain standardized values:

```text
Female
Male
n/a
```

---

# 10. Transformation Summary

| Data Issue                      | Transformation                | Result                                   |
| ------------------------------- | ----------------------------- | ---------------------------------------- |
| ERP customer ID contains prefix | `LIKE 'NAS%'` + `SUBSTRING()` | Prefix removed according to source logic |
| Future birth date               | `CASE` + `GETDATE()`          | Converted to `NULL`                      |
| Short gender code               | `CASE`                        | `F` → `Female`, `M` → `Male`             |
| Full gender value               | `CASE`                        | Standardized to `Female` / `Male`        |
| Whitespace in gender            | `TRIM()`                      | Unwanted spaces removed                  |
| Different letter casing         | `UPPER()`                     | Consistent comparison                    |
| NULL / blank / unknown gender   | `ELSE`                        | Converted to `n/a`                       |

---

# 11. Final Data Quality Expectations

After the transformation process, `silver.erp_cust_az12` should meet the following requirements:

* Customer IDs are standardized according to the source-system format.
* Customer IDs can be aligned with CRM customer IDs.
* Future birth dates are converted to `NULL`.
* Gender values are standardized.
* Leading and trailing spaces are removed from gender values.
* Gender casing is normalized.
* Missing or unrecognized gender values are represented as `n/a`.

---

## Summary

The `erp_cust_az12` transformation follows this workflow:

```text
Bronze Layer
     ↓
Data Quality Checks
     ↓
Check Customer ID Consistency
     ↓
Identify Invalid Birth Dates
     ↓
Check Gender Standardization
     ↓
Standardize Customer ID
     ↓
Handle Future Birth Dates
     ↓
Standardize Gender
     ↓
Load into Silver Layer
     ↓
Silver Layer Validation
     ↓
Clean Customer Demographic Data
```
