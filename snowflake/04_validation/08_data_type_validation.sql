/* =============================================================================
   08_data_type_validation.sql

   Part A - SCHEMA CONTRACT: every table has exactly the columns we designed,
            in the right position, with the right data type.
            (If COPY INTO succeeded, every value already converted to its type -
            e.g. a non-date in a TIMESTAMP column would have aborted the load.)
   Part B - VALUE / DOMAIN checks: the values make sense for their type
            (scores 1-5, no negative prices, 2-letter states, 5-digit zips,
            dates inside the dataset period, logical date order).

   Status:
     FAIL -> schema is wrong or a value is impossible. Fix before Sprint 2.
     WARN -> real-world messiness in the source. Document it; handle in dbt.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- A. Schema contract ---------------------------------------------------------
-- INFORMATION_SCHEMA reports VARCHAR as TEXT and INTEGER as NUMBER with scale 0.
CREATE OR REPLACE TEMPORARY TABLE EXPECTED_COLUMNS AS
    SELECT * FROM VALUES
        ('CUSTOMERS', 1, 'CUSTOMER_ID', 'TEXT', NULL),
        ('CUSTOMERS', 2, 'CUSTOMER_UNIQUE_ID', 'TEXT', NULL),
        ('CUSTOMERS', 3, 'CUSTOMER_ZIP_CODE_PREFIX', 'TEXT', NULL),
        ('CUSTOMERS', 4, 'CUSTOMER_CITY', 'TEXT', NULL),
        ('CUSTOMERS', 5, 'CUSTOMER_STATE', 'TEXT', NULL),
        ('ORDERS', 1, 'ORDER_ID', 'TEXT', NULL),
        ('ORDERS', 2, 'CUSTOMER_ID', 'TEXT', NULL),
        ('ORDERS', 3, 'ORDER_STATUS', 'TEXT', NULL),
        ('ORDERS', 4, 'ORDER_PURCHASE_TIMESTAMP', 'TIMESTAMP_NTZ', NULL),
        ('ORDERS', 5, 'ORDER_APPROVED_AT', 'TIMESTAMP_NTZ', NULL),
        ('ORDERS', 6, 'ORDER_DELIVERED_CARRIER_DATE', 'TIMESTAMP_NTZ', NULL),
        ('ORDERS', 7, 'ORDER_DELIVERED_CUSTOMER_DATE', 'TIMESTAMP_NTZ', NULL),
        ('ORDERS', 8, 'ORDER_ESTIMATED_DELIVERY_DATE', 'TIMESTAMP_NTZ', NULL),
        ('ORDER_ITEMS', 1, 'ORDER_ID', 'TEXT', NULL),
        ('ORDER_ITEMS', 2, 'ORDER_ITEM_ID', 'NUMBER', 0),
        ('ORDER_ITEMS', 3, 'PRODUCT_ID', 'TEXT', NULL),
        ('ORDER_ITEMS', 4, 'SELLER_ID', 'TEXT', NULL),
        ('ORDER_ITEMS', 5, 'SHIPPING_LIMIT_DATE', 'TIMESTAMP_NTZ', NULL),
        ('ORDER_ITEMS', 6, 'PRICE', 'NUMBER', 2),
        ('ORDER_ITEMS', 7, 'FREIGHT_VALUE', 'NUMBER', 2),
        ('ORDER_PAYMENTS', 1, 'ORDER_ID', 'TEXT', NULL),
        ('ORDER_PAYMENTS', 2, 'PAYMENT_SEQUENTIAL', 'NUMBER', 0),
        ('ORDER_PAYMENTS', 3, 'PAYMENT_TYPE', 'TEXT', NULL),
        ('ORDER_PAYMENTS', 4, 'PAYMENT_INSTALLMENTS', 'NUMBER', 0),
        ('ORDER_PAYMENTS', 5, 'PAYMENT_VALUE', 'NUMBER', 2),
        ('ORDER_REVIEWS', 1, 'REVIEW_ID', 'TEXT', NULL),
        ('ORDER_REVIEWS', 2, 'ORDER_ID', 'TEXT', NULL),
        ('ORDER_REVIEWS', 3, 'REVIEW_SCORE', 'NUMBER', 0),
        ('ORDER_REVIEWS', 4, 'REVIEW_COMMENT_TITLE', 'TEXT', NULL),
        ('ORDER_REVIEWS', 5, 'REVIEW_COMMENT_MESSAGE', 'TEXT', NULL),
        ('ORDER_REVIEWS', 6, 'REVIEW_CREATION_DATE', 'TIMESTAMP_NTZ', NULL),
        ('ORDER_REVIEWS', 7, 'REVIEW_ANSWER_TIMESTAMP', 'TIMESTAMP_NTZ', NULL),
        ('PRODUCTS', 1, 'PRODUCT_ID', 'TEXT', NULL),
        ('PRODUCTS', 2, 'PRODUCT_CATEGORY_NAME', 'TEXT', NULL),
        ('PRODUCTS', 3, 'PRODUCT_NAME_LENGHT', 'NUMBER', 0),
        ('PRODUCTS', 4, 'PRODUCT_DESCRIPTION_LENGHT', 'NUMBER', 0),
        ('PRODUCTS', 5, 'PRODUCT_PHOTOS_QTY', 'NUMBER', 0),
        ('PRODUCTS', 6, 'PRODUCT_WEIGHT_G', 'NUMBER', 0),
        ('PRODUCTS', 7, 'PRODUCT_LENGTH_CM', 'NUMBER', 0),
        ('PRODUCTS', 8, 'PRODUCT_HEIGHT_CM', 'NUMBER', 0),
        ('PRODUCTS', 9, 'PRODUCT_WIDTH_CM', 'NUMBER', 0),
        ('SELLERS', 1, 'SELLER_ID', 'TEXT', NULL),
        ('SELLERS', 2, 'SELLER_ZIP_CODE_PREFIX', 'TEXT', NULL),
        ('SELLERS', 3, 'SELLER_CITY', 'TEXT', NULL),
        ('SELLERS', 4, 'SELLER_STATE', 'TEXT', NULL),
        ('GEOLOCATION', 1, 'GEOLOCATION_ZIP_CODE_PREFIX', 'TEXT', NULL),
        ('GEOLOCATION', 2, 'GEOLOCATION_LAT', 'FLOAT', NULL),
        ('GEOLOCATION', 3, 'GEOLOCATION_LNG', 'FLOAT', NULL),
        ('GEOLOCATION', 4, 'GEOLOCATION_CITY', 'TEXT', NULL),
        ('GEOLOCATION', 5, 'GEOLOCATION_STATE', 'TEXT', NULL),
        ('PRODUCT_CATEGORY_TRANSLATION', 1, 'PRODUCT_CATEGORY_NAME', 'TEXT', NULL),
        ('PRODUCT_CATEGORY_TRANSLATION', 2, 'PRODUCT_CATEGORY_NAME_ENGLISH', 'TEXT', NULL)
    AS t(table_name, ordinal_position, column_name, data_type, numeric_scale);

-- A2. Column-by-column detail (select this query and click Run to see it)
WITH expected AS (SELECT * FROM EXPECTED_COLUMNS),
actual AS (
    SELECT table_name, ordinal_position, column_name, data_type,
           IFF(data_type = 'NUMBER', numeric_scale, NULL) AS numeric_scale
    FROM CRI_DB.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'RAW' AND table_name <> 'EXPECTED_COLUMNS'
)
SELECT
    COALESCE(e.table_name, a.table_name)    AS table_name,
    COALESCE(e.column_name, a.column_name)  AS column_name,
    e.ordinal_position AS expected_position, a.ordinal_position AS actual_position,
    e.data_type        AS expected_type,     a.data_type        AS actual_type,
    e.numeric_scale    AS expected_scale,    a.numeric_scale    AS actual_scale,
    CASE
        WHEN a.column_name IS NULL                         THEN 'FAIL - missing column'
        WHEN e.column_name IS NULL                         THEN 'FAIL - unexpected column'
        WHEN e.ordinal_position <> a.ordinal_position      THEN 'FAIL - wrong position'
        WHEN e.data_type <> a.data_type                    THEN 'FAIL - wrong type'
        WHEN NOT EQUAL_NULL(e.numeric_scale, a.numeric_scale) THEN 'FAIL - wrong scale'
        ELSE 'PASS'
    END AS status
FROM expected e
FULL OUTER JOIN actual a
    ON  e.table_name  = a.table_name
    AND e.column_name = a.column_name
ORDER BY status, table_name, expected_position;

-- C. Dataset period (useful for choosing the "as-of" date for recency in Sprint 2)
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,
    DATEDIFF(day, MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) AS days_covered
FROM ORDERS;

-- Orders per month - look for thin months at the start/end of the data
SELECT DATE_TRUNC(month, order_purchase_timestamp)::DATE AS order_month, COUNT(*) AS orders
FROM ORDERS
GROUP BY 1
ORDER BY 1;

-- B. Value / domain checks ---------------------------------------------------
-- violations = number of rows breaking the rule. 0 = PASS.
WITH actual_columns AS (
    SELECT table_name, ordinal_position, column_name, data_type,
           IFF(data_type = 'NUMBER', numeric_scale, NULL) AS numeric_scale
    FROM CRI_DB.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'RAW' AND table_name <> 'EXPECTED_COLUMNS'
),
schema_mismatches AS (
    SELECT COUNT(*) AS n
    FROM EXPECTED_COLUMNS e
    FULL OUTER JOIN actual_columns a
        ON e.table_name = a.table_name AND e.column_name = a.column_name
    WHERE a.column_name IS NULL OR e.column_name IS NULL
       OR e.ordinal_position <> a.ordinal_position
       OR e.data_type <> a.data_type
       OR NOT EQUAL_NULL(e.numeric_scale, a.numeric_scale)
),
checks AS (
    -- Schema contract (Part A summarised: 0 = all 52 columns as designed)
    SELECT 'FAIL' AS severity, 'Schema contract: 52 columns with expected names, positions, types' AS rule_name,
           n AS violations FROM schema_mismatches UNION ALL
    -- Numbers
    SELECT 'FAIL', 'ORDER_REVIEWS.review_score between 1 and 5',
           COUNT_IF(review_score NOT BETWEEN 1 AND 5) AS violations FROM ORDER_REVIEWS UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.price > 0',                      COUNT_IF(price <= 0)                FROM ORDER_ITEMS    UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.freight_value >= 0',             COUNT_IF(freight_value < 0)         FROM ORDER_ITEMS    UNION ALL
    SELECT 'FAIL', 'ORDER_ITEMS.order_item_id >= 1',             COUNT_IF(order_item_id < 1)         FROM ORDER_ITEMS    UNION ALL
    SELECT 'FAIL', 'ORDER_PAYMENTS.payment_value >= 0',          COUNT_IF(payment_value < 0)         FROM ORDER_PAYMENTS UNION ALL
    SELECT 'FAIL', 'ORDER_PAYMENTS.payment_sequential >= 1',     COUNT_IF(payment_sequential < 1)    FROM ORDER_PAYMENTS UNION ALL
    SELECT 'WARN', 'ORDER_PAYMENTS.payment_installments >= 1',   COUNT_IF(payment_installments < 1)  FROM ORDER_PAYMENTS UNION ALL
    SELECT 'WARN', 'ORDER_PAYMENTS.payment_value > 0',           COUNT_IF(payment_value = 0)         FROM ORDER_PAYMENTS UNION ALL
    SELECT 'WARN', 'PRODUCTS.product_weight_g > 0',              COUNT_IF(product_weight_g <= 0)     FROM PRODUCTS       UNION ALL
    SELECT 'FAIL', 'PRODUCTS dimensions/counts >= 0',
           COUNT_IF(product_name_lenght < 0 OR product_description_lenght < 0 OR product_photos_qty < 0
                    OR product_length_cm < 0 OR product_height_cm < 0 OR product_width_cm < 0)    FROM PRODUCTS       UNION ALL
    -- Allowed values (categorical columns)
    SELECT 'FAIL', 'ORDERS.order_status in known list',
           COUNT_IF(order_status NOT IN ('delivered','shipped','canceled','unavailable','invoiced','processing','created','approved')) FROM ORDERS UNION ALL
    SELECT 'FAIL', 'ORDER_PAYMENTS.payment_type in known list',
           COUNT_IF(payment_type NOT IN ('credit_card','boleto','voucher','debit_card','not_defined')) FROM ORDER_PAYMENTS UNION ALL
    -- Text formats
    SELECT 'WARN', 'CUSTOMERS.customer_zip_code_prefix is 5 digits', COUNT_IF(NOT REGEXP_LIKE(customer_zip_code_prefix, '[0-9]{5}')) FROM CUSTOMERS UNION ALL
    SELECT 'WARN', 'SELLERS.seller_zip_code_prefix is 5 digits',     COUNT_IF(NOT REGEXP_LIKE(seller_zip_code_prefix, '[0-9]{5}'))   FROM SELLERS   UNION ALL
    SELECT 'WARN', 'GEOLOCATION.geolocation_zip_code_prefix is 5 digits', COUNT_IF(NOT REGEXP_LIKE(geolocation_zip_code_prefix, '[0-9]{5}')) FROM GEOLOCATION UNION ALL
    SELECT 'FAIL', 'CUSTOMERS.customer_state is 2 uppercase letters', COUNT_IF(NOT REGEXP_LIKE(customer_state, '[A-Z]{2}'))  FROM CUSTOMERS UNION ALL
    SELECT 'FAIL', 'SELLERS.seller_state is 2 uppercase letters',     COUNT_IF(NOT REGEXP_LIKE(seller_state, '[A-Z]{2}'))    FROM SELLERS   UNION ALL
    SELECT 'FAIL', 'ID columns are 32-char hex (customers)',
           COUNT_IF(NOT REGEXP_LIKE(customer_id, '[0-9a-f]{32}') OR NOT REGEXP_LIKE(customer_unique_id, '[0-9a-f]{32}')) FROM CUSTOMERS UNION ALL
    SELECT 'FAIL', 'ID columns are 32-char hex (orders)',
           COUNT_IF(NOT REGEXP_LIKE(order_id, '[0-9a-f]{32}') OR NOT REGEXP_LIKE(customer_id, '[0-9a-f]{32}'))   FROM ORDERS UNION ALL
    -- Coordinates
    SELECT 'FAIL', 'GEOLOCATION lat/lng are valid coordinates',
           COUNT_IF(geolocation_lat NOT BETWEEN -90 AND 90 OR geolocation_lng NOT BETWEEN -180 AND 180) FROM GEOLOCATION UNION ALL
    SELECT 'WARN', 'GEOLOCATION lat/lng fall roughly inside Brazil',
           COUNT_IF(geolocation_lat NOT BETWEEN -34 AND 6 OR geolocation_lng NOT BETWEEN -74 AND -34)   FROM GEOLOCATION UNION ALL
    -- Dates: inside the dataset period and in a logical order
    SELECT 'FAIL', 'ORDERS.order_purchase_timestamp between 2016 and 2018',
           COUNT_IF(order_purchase_timestamp NOT BETWEEN '2016-01-01' AND '2018-12-31 23:59:59') FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDERS.order_approved_at >= purchase',
           COUNT_IF(order_approved_at < order_purchase_timestamp) FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDERS.delivered_carrier >= purchase',
           COUNT_IF(order_delivered_carrier_date < order_purchase_timestamp) FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDERS.delivered_customer >= delivered_carrier',
           COUNT_IF(order_delivered_customer_date < order_delivered_carrier_date) FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDERS.delivered_customer >= purchase',
           COUNT_IF(order_delivered_customer_date < order_purchase_timestamp) FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDERS status=delivered has a delivery date',
           COUNT_IF(order_status = 'delivered' AND order_delivered_customer_date IS NULL) FROM ORDERS UNION ALL
    SELECT 'WARN', 'ORDER_REVIEWS.answer >= creation',
           COUNT_IF(review_answer_timestamp < review_creation_date) FROM ORDER_REVIEWS
)
SELECT
    rule_name,
    severity,
    violations,
    IFF(violations = 0, 'PASS', severity) AS status
FROM checks
ORDER BY CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, rule_name;

