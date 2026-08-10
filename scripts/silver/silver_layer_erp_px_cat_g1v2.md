# Silver Layer — `erp_px_cat_g1v2`

Documentation for the **data quality validation and loading** process applied to the `silver.erp_px_cat_g1v2` table.

## 1. Overview

The `silver.erp_px_cat_g1v2` table is created from `bronze.erp_px_cat_g1v2`.

Unlike other Silver Layer tables, this dataset did not contain any identified data quality issues during the validation process.

The validation focused on:

* Unwanted leading or trailing spaces.
* Category value consistency.
* Subcategory value consistency.
* Maintenance value consistency.

Since no issues were identified, the data was transferred from the Bronze Layer to the Silver Layer without additional transformation.

---

# 2. Data Quality Checks — Bronze Layer

## 2.1 Check for Unwanted Spaces

**Expectation:** No Result

```sql
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE
    cat != TRIM(cat)
    OR subcat != TRIM(subcat)
    OR maintenance != TRIM(maintenance);
```

This check identifies leading or trailing spaces in:

* `cat`
* `subcat`
* `maintenance`

### Result

**No issues found.**

All checked values were already properly formatted without unwanted spaces.

---

# 3. Data Standardization and Consistency

The distinct values of the categorical columns were reviewed to identify potential inconsistencies.

## 3.1 Category

```sql
SELECT DISTINCT
    cat
FROM bronze.erp_px_cat_g1v2;
```

The values were reviewed for consistency.

**Result:** No issues found.

---

## 3.2 Subcategory

```sql
SELECT DISTINCT
    subcat
FROM bronze.erp_px_cat_g1v2;
```

The values were reviewed for consistency.

**Result:** No issues found.

---

## 3.3 Maintenance

```sql
SELECT DISTINCT
    maintenance
FROM bronze.erp_px_cat_g1v2;
```

The values were reviewed for consistency.

**Result:** No issues found.

---

# 4. Data Quality Assessment

The validation process did not identify any issues in the source data.

| Validation           | Column(s)                      | Result    |
| -------------------- | ------------------------------ | --------- |
| Unwanted spaces      | `cat`, `subcat`, `maintenance` | No issues |
| Data standardization | `cat`                          | No issues |
| Data standardization | `subcat`                       | No issues |
| Data standardization | `maintenance`                  | No issues |

Because the source data already meets the expected quality requirements, no transformation logic is required.

---

# 5. Bronze → Silver Loading

The data is transferred directly from the Bronze Layer to the Silver Layer.

```sql
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
```

No `TRIM()`, `CASE`, `REPLACE()`, or other transformation functions are required because the validation checks did not identify any issues.

---

# 6. Transformation Summary

| Column        | Issue Found | Transformation      |
| ------------- | ----------- | ------------------- |
| `id`          | None        | Keep original value |
| `cat`         | None        | Keep original value |
| `subcat`      | None        | Keep original value |
| `maintenance` | None        | Keep original value |

The table is therefore loaded using a **direct Bronze-to-Silver transfer**.

---

# 7. Final Data Quality Expectations

After loading into `silver.erp_px_cat_g1v2`:

* No unwanted leading or trailing spaces should exist.
* Category values remain consistent.
* Subcategory values remain consistent.
* Maintenance values remain consistent.
* Original values are preserved.
* No additional transformation is required.

---

## Summary

The `erp_px_cat_g1v2` transformation follows a simple workflow:

```text
Bronze Layer
     ↓
Data Quality Checks
     ↓
Check for Unwanted Spaces
     ↓
Check Data Standardization
     ↓
No Issues Found
     ↓
Direct Bronze → Silver Load
     ↓
Silver Layer
```

**Conclusion:** `bronze.erp_px_cat_g1v2` passed the defined data quality checks, so the dataset was loaded into `silver.erp_px_cat_g1v2` without additional transformation.
