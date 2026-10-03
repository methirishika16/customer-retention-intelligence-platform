/* =============================================================================
   06_null_checks.sql
   Null profile of EVERY column in the RAW layer.

   rule = 'REQUIRED' -> keys / core facts. Any null = FAIL (fix before Sprint 2).
   rule = 'OPTIONAL' -> nulls are a legitimate business state, e.g.
                        order_delivered_customer_date is null when the order
                        was never delivered. Nulls are reported as INFO.

   Pass criteria: no row has status = 'FAIL'.
   Record the INFO numbers in docs/data_dictionary.md - they matter in Sprint 2.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- Drill-down: are the missing delivery dates explained by order_status?
-- Expect: most nulls belong to non-'delivered' statuses.
SELECT
    order_status,
    COUNT(*)                                          AS orders,
    COUNT_IF(order_approved_at IS NULL)               AS null_approved_at,
    COUNT_IF(order_delivered_carrier_date IS NULL)    AS null_delivered_carrier,
    COUNT_IF(order_delivered_customer_date IS NULL)   AS null_delivered_customer
FROM ORDERS
GROUP BY order_status
ORDER BY orders DESC;

WITH null_counts AS (
    -- CUSTOMERS
    SELECT 'CUSTOMERS' AS table_name, 'customer_id' AS column_name, 'REQUIRED' AS rule, COUNT_IF(customer_id IS NULL) AS null_count, COUNT(*) AS total_rows FROM CUSTOMERS UNION ALL
    SELECT 'CUSTOMERS', 'customer_unique_id',       'REQUIRED', COUNT_IF(customer_unique_id IS NULL),       COUNT(*) FROM CUSTOMERS UNION ALL
    SELECT 'CUSTOMERS', 'customer_zip_code_prefix', 'OPTIONAL', COUNT_IF(customer_zip_code_prefix IS NULL), COUNT(*) FROM CUSTOMERS UNION ALL
    SELECT 'CUSTOMERS', 'customer_city',            'OPTIONAL', COUNT_IF(customer_city IS NULL),            COUNT(*) FROM CUSTOMERS UNION ALL
    SELECT 'CUSTOMERS', 'customer_state',           'OPTIONAL', COUNT_IF(customer_state IS NULL),           COUNT(*) FROM CUSTOMERS UNION ALL
    -- ORDERS
    SELECT 'ORDERS', 'order_id',                      'REQUIRED', COUNT_IF(order_id IS NULL),                      COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'customer_id',                   'REQUIRED', COUNT_IF(customer_id IS NULL),                   COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_status',                  'REQUIRED', COUNT_IF(order_status IS NULL),                  COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_purchase_timestamp',      'REQUIRED', COUNT_IF(order_purchase_timestamp IS NULL),      COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_approved_at',             'OPTIONAL', COUNT_IF(order_approved_at IS NULL),             COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_delivered_carrier_date',  'OPTIONAL', COUNT_IF(order_delivered_carrier_date IS NULL),  COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_delivered_customer_date', 'OPTIONAL', COUNT_IF(order_delivered_customer_date IS NULL), COUNT(*) FROM ORDERS UNION ALL
    SELECT 'ORDERS', 'order_estimated_delivery_date', 'OPTIONAL', COUNT_IF(order_estimated_delivery_date IS NULL), COUNT(*) FROM ORDERS UNION ALL
    -- ORDER_ITEMS
    SELECT 'ORDER_ITEMS', 'order_id',            'REQUIRED', COUNT_IF(order_id IS NULL),            COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'order_item_id',       'REQUIRED', COUNT_IF(order_item_id IS NULL),       COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'product_id',          'REQUIRED', COUNT_IF(product_id IS NULL),          COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'seller_id',           'REQUIRED', COUNT_IF(seller_id IS NULL),           COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'shipping_limit_date', 'OPTIONAL', COUNT_IF(shipping_limit_date IS NULL), COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'price',               'REQUIRED', COUNT_IF(price IS NULL),               COUNT(*) FROM ORDER_ITEMS UNION ALL
    SELECT 'ORDER_ITEMS', 'freight_value',       'OPTIONAL', COUNT_IF(freight_value IS NULL),       COUNT(*) FROM ORDER_ITEMS UNION ALL
    -- ORDER_PAYMENTS
    SELECT 'ORDER_PAYMENTS', 'order_id',             'REQUIRED', COUNT_IF(order_id IS NULL),             COUNT(*) FROM ORDER_PAYMENTS UNION ALL
    SELECT 'ORDER_PAYMENTS', 'payment_sequential',   'REQUIRED', COUNT_IF(payment_sequential IS NULL),   COUNT(*) FROM ORDER_PAYMENTS UNION ALL
    SELECT 'ORDER_PAYMENTS', 'payment_type',         'REQUIRED', COUNT_IF(payment_type IS NULL),         COUNT(*) FROM ORDER_PAYMENTS UNION ALL
    SELECT 'ORDER_PAYMENTS', 'payment_installments', 'OPTIONAL', COUNT_IF(payment_installments IS NULL), COUNT(*) FROM ORDER_PAYMENTS UNION ALL
    SELECT 'ORDER_PAYMENTS', 'payment_value',        'REQUIRED', COUNT_IF(payment_value IS NULL),        COUNT(*) FROM ORDER_PAYMENTS UNION ALL
    -- ORDER_REVIEWS
    SELECT 'ORDER_REVIEWS', 'review_id',               'REQUIRED', COUNT_IF(review_id IS NULL),               COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'order_id',                'REQUIRED', COUNT_IF(order_id IS NULL),                COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'review_score',            'REQUIRED', COUNT_IF(review_score IS NULL),            COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'review_comment_title',    'OPTIONAL', COUNT_IF(review_comment_title IS NULL),    COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'review_comment_message',  'OPTIONAL', COUNT_IF(review_comment_message IS NULL),  COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'review_creation_date',    'OPTIONAL', COUNT_IF(review_creation_date IS NULL),    COUNT(*) FROM ORDER_REVIEWS UNION ALL
    SELECT 'ORDER_REVIEWS', 'review_answer_timestamp', 'OPTIONAL', COUNT_IF(review_answer_timestamp IS NULL), COUNT(*) FROM ORDER_REVIEWS UNION ALL
    -- PRODUCTS
    SELECT 'PRODUCTS', 'product_id',                 'REQUIRED', COUNT_IF(product_id IS NULL),                 COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_category_name',      'OPTIONAL', COUNT_IF(product_category_name IS NULL),      COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_name_lenght',        'OPTIONAL', COUNT_IF(product_name_lenght IS NULL),        COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_description_lenght', 'OPTIONAL', COUNT_IF(product_description_lenght IS NULL), COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_photos_qty',         'OPTIONAL', COUNT_IF(product_photos_qty IS NULL),         COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_weight_g',           'OPTIONAL', COUNT_IF(product_weight_g IS NULL),           COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_length_cm',          'OPTIONAL', COUNT_IF(product_length_cm IS NULL),          COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_height_cm',          'OPTIONAL', COUNT_IF(product_height_cm IS NULL),          COUNT(*) FROM PRODUCTS UNION ALL
    SELECT 'PRODUCTS', 'product_width_cm',           'OPTIONAL', COUNT_IF(product_width_cm IS NULL),           COUNT(*) FROM PRODUCTS UNION ALL
    -- SELLERS
    SELECT 'SELLERS', 'seller_id',              'REQUIRED', COUNT_IF(seller_id IS NULL),              COUNT(*) FROM SELLERS UNION ALL
    SELECT 'SELLERS', 'seller_zip_code_prefix', 'OPTIONAL', COUNT_IF(seller_zip_code_prefix IS NULL), COUNT(*) FROM SELLERS UNION ALL
    SELECT 'SELLERS', 'seller_city',            'OPTIONAL', COUNT_IF(seller_city IS NULL),            COUNT(*) FROM SELLERS UNION ALL
    SELECT 'SELLERS', 'seller_state',           'OPTIONAL', COUNT_IF(seller_state IS NULL),           COUNT(*) FROM SELLERS UNION ALL
    -- GEOLOCATION
    SELECT 'GEOLOCATION', 'geolocation_zip_code_prefix', 'REQUIRED', COUNT_IF(geolocation_zip_code_prefix IS NULL), COUNT(*) FROM GEOLOCATION UNION ALL
    SELECT 'GEOLOCATION', 'geolocation_lat',             'OPTIONAL', COUNT_IF(geolocation_lat IS NULL),             COUNT(*) FROM GEOLOCATION UNION ALL
    SELECT 'GEOLOCATION', 'geolocation_lng',             'OPTIONAL', COUNT_IF(geolocation_lng IS NULL),             COUNT(*) FROM GEOLOCATION UNION ALL
    SELECT 'GEOLOCATION', 'geolocation_city',            'OPTIONAL', COUNT_IF(geolocation_city IS NULL),            COUNT(*) FROM GEOLOCATION UNION ALL
    SELECT 'GEOLOCATION', 'geolocation_state',           'OPTIONAL', COUNT_IF(geolocation_state IS NULL),           COUNT(*) FROM GEOLOCATION UNION ALL
    -- PRODUCT_CATEGORY_TRANSLATION
    SELECT 'PRODUCT_CATEGORY_TRANSLATION', 'product_category_name',         'REQUIRED', COUNT_IF(product_category_name IS NULL),         COUNT(*) FROM PRODUCT_CATEGORY_TRANSLATION UNION ALL
    SELECT 'PRODUCT_CATEGORY_TRANSLATION', 'product_category_name_english', 'REQUIRED', COUNT_IF(product_category_name_english IS NULL), COUNT(*) FROM PRODUCT_CATEGORY_TRANSLATION
)
SELECT
    table_name,
    column_name,
    rule,
    null_count,
    total_rows,
    ROUND(100 * null_count / NULLIF(total_rows, 0), 2) AS null_pct,
    CASE
        WHEN null_count = 0       THEN 'PASS'
        WHEN rule = 'REQUIRED'    THEN 'FAIL'
        ELSE                           'INFO'
    END AS status
FROM null_counts
ORDER BY
    CASE status WHEN 'FAIL' THEN 1 WHEN 'INFO' THEN 2 ELSE 3 END,
    table_name, column_name;

