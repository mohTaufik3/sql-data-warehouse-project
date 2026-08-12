-- Check Customer Dimension
SELECT *
FROM gold.dim_customers;


-- Check Product Dimension
SELECT *
FROM gold.dim_products;


-- Check Sales Fact
SELECT *
FROM gold.facts_sales;

SELECT COUNT(*) AS total_customers
FROM gold.dim_customers;


SELECT COUNT(*) AS total_products
FROM gold.dim_products;


SELECT COUNT(*) AS total_sales
FROM gold.facts_sales;

---

# Quality Check dim_customers

-- Check Customer Surrogate Key
-- Expectation: No Result

SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Check Customer ID
-- Expectation: No Result

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

---

# Quality Check dim_products
  
-- Check Product Surrogate Key
-- Expectation: No Result

SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Check Product Number
-- Expectation: No Result

SELECT
    product_number,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

---

# Quality Check Fact → Customer
-- Check Fact to Customer Relationship
-- Expectation: No Result

SELECT *
FROM gold.facts_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

---

# Quality Check Fact → Product

-- Check Fact to Product Relationship
-- Expectation: No Result

SELECT *
FROM gold.facts_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

---

# Quality Check Sales Calculation

-- Check Sales Calculation
-- Expectation: No Result

SELECT
    order_number,
    sales_amount,
    quantity,
    price
FROM gold.facts_sales
WHERE sales_amount != quantity * price;
