# Silver Layer — `erp_loc_a101`

Documentation for the **data quality checks, customer ID standardization, country standardization, and transformation** process applied to the `silver.erp_loc_a101` table.

## 1. Overview

The `silver.erp_loc_a101` table is created by transforming customer location data from the `bronze.erp_loc_a101` table.

The transformation process focuses on:

* Ensuring consistency between ERP customer IDs and CRM customer keys.
* Removing unnecessary characters from customer IDs.
* Standardizing country names.
* Handling country codes with multiple representations.
* Handling missing or blank country values.
* Preparing location data for integration with customer-related tables.

---

# 2. Data Quality Checks — Bronze Layer

Before transforming the data, several data quality checks are performed on `bronze.erp_loc_a101`.

---

## 2.1 Checking Consistency Between Tables

The customer ID from the ERP location table is compared with the customer key from the CRM customer table.

```sql
SELECT TOP (5)
    cid
FROM bronze.erp_loc_a101;

SELECT TOP 5
    cst_key
FROM silver.crm_cust_info;
```

### Example Result

ERP customer ID:

```text
AW-00011000
AW-00011001
AW-00011002
AW-00011003
AW-00011004
```

CRM customer key:

```text
AW00011000
AW00011001
AW00011002
AW00011003
AW00011004
```

### Issue Identified

The ERP customer ID contains a hyphen:

```text
AW-00011000
```

while the CRM customer key does not:

```text
AW00011000
```

Therefore, the ERP customer ID needs to be standardized before it can be consistently integrated with the CRM customer data.

---

# 3. Data Standardization and Consistency — Country

```sql
SELECT DISTINCT
    cntry
FROM bronze.erp_loc_a101
ORDER BY cntry;
```

The source data contains multiple representations of the same countries.

### Example Values

```text
Australia
Canada
DE
France
Germany
United Kingdom
United States
US
USA
NULL
Blank
```

### Issues Identified

There are several inconsistencies:

* `DE` represents `Germany`.
* `US` and `USA` represent `United States`.
* `NULL` values are missing.
* Blank values contain no meaningful country information.
* Some country values contain unnecessary spaces.

These values need to be standardized in the Silver Layer.

---

# 4. Transformation Logic

## 4.1 Customer ID Standardization

The hyphen in the ERP customer ID is removed using `REPLACE()`:

```sql
REPLACE(cid, '-', '') AS cid
```

### Example

```text
AW-00011000
      ↓
AW00011000
```

This makes the ERP customer ID consistent with the CRM `cst_key`.

---

# 5. Country Standardization

The country values are standardized using `CASE`, `TRIM()`, and conditional mapping.

```sql
CASE
    WHEN TRIM(cntry) = 'DE'
        THEN 'Germany'

    WHEN TRIM(cntry) IN ('US', 'USA')
        THEN 'United States'

    WHEN TRIM(cntry) = '' OR cntry IS NULL
        THEN 'n/a'

    ELSE TRIM(cntry)
END AS cntry
```

## Standardization Rules

| Source Value     | Standardized Value |
| ---------------- | ------------------ |
| `DE`             | `Germany`          |
| `US`             | `United States`    |
| `USA`            | `United States`    |
| `Australia`      | `Australia`        |
| `Canada`         | `Canada`           |
| `France`         | `France`           |
| `Germany`        | `Germany`          |
| `United Kingdom` | `United Kingdom`   |
| `United States`  | `United States`    |
| `NULL`           | `n/a`              |
| Blank            | `n/a`              |

---

# 6. Why `TRIM()` Is Used

`TRIM()` removes leading and trailing spaces from country values.

For example:

```text
' United States '
```

becomes:

```text
'United States'
```

This ensures that values with unnecessary whitespace can be standardized correctly.

---

# 7. Why `REPLACE()` Is Used

The source customer ID contains a hyphen:

```text
AW-00011000
```

while the CRM customer key uses:

```text
AW00011000
```

The following expression removes the hyphen:

```sql
REPLACE(cid, '-', '')
```

Result:

```text
AW00011000
```

This allows the customer ID to follow the same format as the CRM customer key.

---

# 8. Bronze → Silver Transformation

The following query transforms the Bronze location data and inserts it into `silver.erp_loc_a101`.

```sql
INSERT INTO silver.erp_loc_a101 (
    cid,
    cntry
)
SELECT
    REPLACE(cid, '-', '') AS cid,

    CASE
        WHEN TRIM(cntry) = 'DE'
            THEN 'Germany'

        WHEN TRIM(cntry) IN ('US', 'USA')
            THEN 'United States'

        WHEN TRIM(cntry) = '' OR cntry IS NULL
            THEN 'n/a'

        ELSE TRIM(cntry)
    END AS cntry

FROM bronze.erp_loc_a101;
```

---

# 9. Silver Layer Validation

After the transformation, the resulting `silver.erp_loc_a101` table is validated again.

---

## 9.1 Checking Consistency Between Tables

```sql
SELECT TOP (5)
    cid
FROM silver.erp_loc_a101;

SELECT TOP 5
    cst_key
FROM silver.crm_cust_info;
```

### Expected Result

The customer IDs should follow the same format:

```text
AW00011000
AW00011001
AW00011002
AW00011003
AW00011004
```

This confirms that the customer ID in `silver.erp_loc_a101` is consistent with `silver.crm_cust_info.cst_key`.

---

## 9.2 Data Standardization and Consistency — Country

```sql
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;
```

### Expected Values

The Silver Layer should contain standardized country names such as:

```text
Australia
Canada
France
Germany
n/a
United Kingdom
United States
```

Country codes such as:

```text
DE
US
USA
```

should no longer appear.

---

# 10. Transformation Summary

| Data Issue              | Transformation | Result                       |
| ----------------------- | -------------- | ---------------------------- |
| Hyphen in customer ID   | `REPLACE()`    | `AW-00011000` → `AW00011000` |
| `DE` country code       | `CASE`         | `Germany`                    |
| `US` country code       | `CASE`         | `United States`              |
| `USA` country code      | `CASE`         | `United States`              |
| Leading/trailing spaces | `TRIM()`       | Clean country values         |
| `NULL` country          | `CASE`         | `n/a`                        |
| Blank country           | `CASE`         | `n/a`                        |
| Standard country values | `ELSE TRIM()`  | Preserve cleaned value       |

---

# 11. Final Data Quality Expectations

After the transformation process, `silver.erp_loc_a101` should meet the following requirements:

* Customer IDs follow the same format as `silver.crm_cust_info.cst_key`.
* Hyphens are removed from customer IDs.
* Country values are standardized.
* `DE` is represented as `Germany`.
* `US` and `USA` are represented as `United States`.
* Leading and trailing spaces are removed.
* Missing and blank country values are represented as `n/a`.
* Country codes are no longer present in the standardized values.

---

## Summary

The `erp_loc_a101` transformation follows this workflow:

```text
Bronze Layer
     ↓
Data Quality Checks
     ↓
Check Customer ID Consistency
     ↓
Identify Country Inconsistencies
     ↓
Remove Hyphens from Customer IDs
     ↓
Standardize Country Values
     ↓
Handle Missing Country Values
     ↓
Load into Silver Layer
     ↓
Silver Layer Validation
     ↓
Clean Customer Location Data
```
