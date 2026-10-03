/* =============================================================================
   07_duplicate_checks.sql
   Snowflake does NOT enforce PRIMARY KEY constraints, so we test them here.

   Section A - primary-key uniqueness (FAIL if violated)
   Section B - expected repetition that is actually business information (INFO)
   Section C - fully duplicated rows (exact copies of a whole row)
   Section D - drill-down queries to look at examples

   Pass criteria: no row in Section A has status = 'FAIL'.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- B. Expected repetition (business information, not errors) -----------------
SELECT 'Customers (people) with more than one order'           AS check_name,
       COUNT(*)                                                 AS value,
       'INFO'                                                   AS status
FROM (SELECT customer_unique_id FROM CUSTOMERS GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Distinct customer_unique_id (real customers)', COUNT(DISTINCT customer_unique_id), 'INFO' FROM CUSTOMERS
UNION ALL
SELECT 'review_id values appearing on more than one order (source quirk)',
       COUNT(*), 'INFO'
FROM (SELECT review_id FROM ORDER_REVIEWS GROUP BY 1 HAVING COUNT(DISTINCT order_id) > 1)
UNION ALL
SELECT 'Orders with more than one review', COUNT(*), 'INFO'
FROM (SELECT order_id FROM ORDER_REVIEWS GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Orders paid with more than one payment row', COUNT(*), 'INFO'
FROM (SELECT order_id FROM ORDER_PAYMENTS GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Distinct zip prefixes in GEOLOCATION (vs ~1M rows)', COUNT(DISTINCT geolocation_zip_code_prefix), 'INFO'
FROM GEOLOCATION;

-- C. Fully duplicated rows ---------------------------------------------------
-- GEOLOCATION is expected to have many (same zip + coordinates repeated); others should be 0.
SELECT 'CUSTOMERS' AS table_name, (SELECT COUNT(*) FROM CUSTOMERS) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM CUSTOMERS)) AS exact_duplicate_rows UNION ALL
SELECT 'ORDERS',         (SELECT COUNT(*) FROM ORDERS)         - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM ORDERS))         UNION ALL
SELECT 'ORDER_ITEMS',    (SELECT COUNT(*) FROM ORDER_ITEMS)    - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM ORDER_ITEMS))    UNION ALL
SELECT 'ORDER_PAYMENTS', (SELECT COUNT(*) FROM ORDER_PAYMENTS) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM ORDER_PAYMENTS)) UNION ALL
SELECT 'ORDER_REVIEWS',  (SELECT COUNT(*) FROM ORDER_REVIEWS)  - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM ORDER_REVIEWS))  UNION ALL
SELECT 'PRODUCTS',       (SELECT COUNT(*) FROM PRODUCTS)       - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM PRODUCTS))       UNION ALL
SELECT 'SELLERS',        (SELECT COUNT(*) FROM SELLERS)        - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM SELLERS))        UNION ALL
SELECT 'GEOLOCATION',    (SELECT COUNT(*) FROM GEOLOCATION)    - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM GEOLOCATION))    UNION ALL
SELECT 'PRODUCT_CATEGORY_TRANSLATION', (SELECT COUNT(*) FROM PRODUCT_CATEGORY_TRANSLATION) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM PRODUCT_CATEGORY_TRANSLATION))
ORDER BY exact_duplicate_rows DESC;

-- D. Drill-downs (run individually if a check above looks odd) ---------------
-- Customers with the most orders - your future "loyal" segment
SELECT customer_unique_id, COUNT(*) AS orders
FROM CUSTOMERS
GROUP BY customer_unique_id
ORDER BY orders DESC
LIMIT 10;

-- Example review_ids shared by several orders
SELECT review_id, COUNT(DISTINCT order_id) AS orders, MIN(review_score) AS min_score, MAX(review_score) AS max_score
FROM ORDER_REVIEWS
GROUP BY review_id
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY orders DESC
LIMIT 10;

-- A. Primary-key uniqueness --------------------------------------------------
-- duplicate_keys = rows - distinct keys. 0 means the key is unique.
WITH key_checks AS (
    SELECT 'CUSTOMERS'      AS table_name, 'customer_id'                  AS key_columns, COUNT(*) AS total_rows, COUNT(DISTINCT customer_id)                    AS distinct_keys FROM CUSTOMERS      UNION ALL
    SELECT 'ORDERS',                       'order_id',                                    COUNT(*),               COUNT(DISTINCT order_id)                                        FROM ORDERS         UNION ALL
    SELECT 'ORDER_ITEMS',                  'order_id + order_item_id',                    COUNT(*),               COUNT(DISTINCT order_id, order_item_id)                         FROM ORDER_ITEMS    UNION ALL
    SELECT 'ORDER_PAYMENTS',               'order_id + payment_sequential',               COUNT(*),               COUNT(DISTINCT order_id, payment_sequential)                    FROM ORDER_PAYMENTS UNION ALL
    SELECT 'ORDER_REVIEWS',                'review_id + order_id',                        COUNT(*),               COUNT(DISTINCT review_id, order_id)                             FROM ORDER_REVIEWS  UNION ALL
    SELECT 'PRODUCTS',                     'product_id',                                  COUNT(*),               COUNT(DISTINCT product_id)                                      FROM PRODUCTS       UNION ALL
    SELECT 'SELLERS',                      'seller_id',                                   COUNT(*),               COUNT(DISTINCT seller_id)                                       FROM SELLERS        UNION ALL
    SELECT 'PRODUCT_CATEGORY_TRANSLATION', 'product_category_name',                       COUNT(*),               COUNT(DISTINCT product_category_name)                           FROM PRODUCT_CATEGORY_TRANSLATION
)
SELECT
    table_name,
    key_columns,
    total_rows,
    distinct_keys,
    total_rows - distinct_keys                         AS duplicate_keys,
    IFF(total_rows = distinct_keys, 'PASS', 'FAIL')    AS status
FROM key_checks
ORDER BY status, table_name;
