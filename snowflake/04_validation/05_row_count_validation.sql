/* =============================================================================
   05_row_count_validation.sql
   Did every row in every CSV make it into Snowflake?

   expected_rows = data rows in the CSV (header excluded), as published on Kaggle.
   WARNING: The source of truth is YOUR download: if python/inspect_dataset.py printed
      different counts, update the VALUES list below to match it.

   Pass criteria: every row shows status = 'PASS'.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- Cross-table sanity check: Olist creates one customer_id per order,
-- so CUSTOMERS and ORDERS should have the same row count.
SELECT
    (SELECT COUNT(*) FROM CUSTOMERS) AS customers_rows,
    (SELECT COUNT(*) FROM ORDERS)    AS orders_rows,
    IFF(customers_rows = orders_rows, 'PASS', 'FAIL') AS status;

WITH expected AS (
    SELECT * FROM VALUES
        ('CUSTOMERS',                      99441),
        ('ORDERS',                         99441),
        ('ORDER_ITEMS',                   112650),
        ('ORDER_PAYMENTS',                103886),
        ('ORDER_REVIEWS',                  99224),
        ('PRODUCTS',                       32951),
        ('SELLERS',                         3095),
        ('GEOLOCATION',                  1000163),
        ('PRODUCT_CATEGORY_TRANSLATION',      71)
    AS t(table_name, expected_rows)
),
actual AS (
    SELECT 'CUSTOMERS'                    AS table_name, COUNT(*) AS actual_rows FROM CUSTOMERS                    UNION ALL
    SELECT 'ORDERS',                                     COUNT(*)                FROM ORDERS                       UNION ALL
    SELECT 'ORDER_ITEMS',                                COUNT(*)                FROM ORDER_ITEMS                  UNION ALL
    SELECT 'ORDER_PAYMENTS',                             COUNT(*)                FROM ORDER_PAYMENTS               UNION ALL
    SELECT 'ORDER_REVIEWS',                              COUNT(*)                FROM ORDER_REVIEWS                UNION ALL
    SELECT 'PRODUCTS',                                   COUNT(*)                FROM PRODUCTS                     UNION ALL
    SELECT 'SELLERS',                                    COUNT(*)                FROM SELLERS                      UNION ALL
    SELECT 'GEOLOCATION',                                COUNT(*)                FROM GEOLOCATION                  UNION ALL
    SELECT 'PRODUCT_CATEGORY_TRANSLATION',               COUNT(*)                FROM PRODUCT_CATEGORY_TRANSLATION
)
SELECT
    e.table_name,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows                     AS difference,
    IFF(a.actual_rows = e.expected_rows, 'PASS', 'FAIL') AS status
FROM expected e
JOIN actual   a USING (table_name)
ORDER BY status, table_name;

