/* =============================================================================
   09_relationship_checks.sql
   Do the tables join the way the data model says they do?
   (Snowflake doesn't enforce FOREIGN KEYs either, so we test them.)

   orphan_rows = child rows whose key is not found in the parent table.
   Pass criteria: no row has status = 'FAIL'.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- Drill-down: which categories are missing an English translation?
SELECT p.product_category_name, COUNT(*) AS products
FROM PRODUCTS p
LEFT JOIN PRODUCT_CATEGORY_TRANSLATION t ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL
GROUP BY 1;

-- Drill-down: what status do orders without items have?
SELECT o.order_status, COUNT(*) AS orders_without_items
FROM ORDERS o
WHERE NOT EXISTS (SELECT 1 FROM ORDER_ITEMS i WHERE i.order_id = o.order_id)
GROUP BY 1
ORDER BY 2 DESC;

-- Payment reconciliation: does what customers paid match items + freight?
-- Small differences are normal (vouchers, installment interest). Large ones are worth noting.
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM ORDER_ITEMS GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM ORDER_PAYMENTS GROUP BY order_id
)
SELECT
    COUNT(*)                                             AS orders_compared,
    COUNT_IF(ABS(i.items_total - p.paid_total) <= 1)     AS within_1_brl,
    COUNT_IF(ABS(i.items_total - p.paid_total) > 1)      AS differ_more_than_1_brl
FROM item_totals i
JOIN payment_totals p USING (order_id);

WITH checks AS (
    SELECT 'FAIL' AS severity, 'ORDERS.customer_id -> CUSTOMERS' AS relationship,
           COUNT(*) AS orphan_rows
    FROM ORDERS o LEFT JOIN CUSTOMERS c ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL
    UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.order_id -> ORDERS', COUNT(*)
    FROM ORDER_ITEMS i LEFT JOIN ORDERS o ON i.order_id = o.order_id
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.product_id -> PRODUCTS', COUNT(*)
    FROM ORDER_ITEMS i LEFT JOIN PRODUCTS p ON i.product_id = p.product_id
    WHERE p.product_id IS NULL
    UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.seller_id -> SELLERS', COUNT(*)
    FROM ORDER_ITEMS i LEFT JOIN SELLERS s ON i.seller_id = s.seller_id
    WHERE s.seller_id IS NULL
    UNION ALL
    SELECT 'FAIL', 'ORDER_PAYMENTS.order_id -> ORDERS', COUNT(*)
    FROM ORDER_PAYMENTS p LEFT JOIN ORDERS o ON p.order_id = o.order_id
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'FAIL', 'ORDER_REVIEWS.order_id -> ORDERS', COUNT(*)
    FROM ORDER_REVIEWS r LEFT JOIN ORDERS o ON r.order_id = o.order_id
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'WARN', 'PRODUCTS.product_category_name -> TRANSLATION (non-null only)', COUNT(*)
    FROM PRODUCTS p LEFT JOIN PRODUCT_CATEGORY_TRANSLATION t ON p.product_category_name = t.product_category_name
    WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL
    UNION ALL
    SELECT 'WARN', 'CUSTOMERS.zip prefix found in GEOLOCATION', COUNT(*)
    FROM CUSTOMERS c
    WHERE NOT EXISTS (SELECT 1 FROM GEOLOCATION g WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix)
    -- Reverse direction: parents with no children (informational)
    UNION ALL
    SELECT 'WARN', 'ORDERS with no ORDER_ITEMS', COUNT(*)
    FROM ORDERS o
    WHERE NOT EXISTS (SELECT 1 FROM ORDER_ITEMS i WHERE i.order_id = o.order_id)
    UNION ALL
    SELECT 'WARN', 'ORDERS with no ORDER_PAYMENTS', COUNT(*)
    FROM ORDERS o
    WHERE NOT EXISTS (SELECT 1 FROM ORDER_PAYMENTS p WHERE p.order_id = o.order_id)
    UNION ALL
    SELECT 'WARN', 'ORDERS with no ORDER_REVIEWS', COUNT(*)
    FROM ORDERS o
    WHERE NOT EXISTS (SELECT 1 FROM ORDER_REVIEWS r WHERE r.order_id = o.order_id)
)
SELECT
    relationship,
    severity,
    orphan_rows,
    IFF(orphan_rows = 0, 'PASS', severity) AS status
FROM checks
ORDER BY CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, relationship;

