/* =============================================================================
   02_create_raw_tables.sql
   Creates the 9 RAW tables - one per Olist CSV file.

   Design rules for the RAW layer
     * Column names and ORDER match the CSV header exactly
       (COPY INTO maps CSV columns to table columns by position).
     * No columns are added, renamed or dropped. Source typos are kept
       (e.g. product_name_lenght) - we clean names later in dbt.
     * Zip code prefixes are VARCHAR, not numbers, so leading zeros survive.
     * Money = NUMBER(10,2). Counts / sequence numbers = INTEGER.
       Dates = TIMESTAMP_NTZ (source has no time zone).
     * PRIMARY KEY constraints are INFORMATIONAL ONLY in Snowflake - they are
       NOT enforced. That is why 07_duplicate_checks.sql exists.
     * No NOT NULL constraints: RAW should accept the data as delivered;
       06_null_checks.sql tells us if a key column is null.

   WARNING: CREATE OR REPLACE drops any data already in the table. Re-run this file
      only when you want to rebuild from scratch, then re-run 04_load_raw_tables.sql.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- olist_customers_dataset.csv ------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id               VARCHAR  COMMENT 'Order-level customer key; one per order. Joins to ORDERS.customer_id',
    customer_unique_id        VARCHAR  COMMENT 'The real person. Same value across all of a customer''s orders',
    customer_zip_code_prefix  VARCHAR  COMMENT 'First 5 digits of the customer zip code',
    customer_city             VARCHAR  COMMENT 'Customer city name',
    customer_state            VARCHAR  COMMENT 'Customer state (2-letter Brazilian UF code)',
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
) COMMENT = 'Source: olist_customers_dataset.csv';

-- olist_orders_dataset.csv ---------------------------------------------------
CREATE OR REPLACE TABLE ORDERS (
    order_id                       VARCHAR        COMMENT 'Unique order identifier',
    customer_id                    VARCHAR        COMMENT 'FK to CUSTOMERS.customer_id',
    order_status                   VARCHAR        COMMENT 'delivered, shipped, canceled, unavailable, invoiced, processing, created, approved',
    order_purchase_timestamp       TIMESTAMP_NTZ  COMMENT 'When the order was placed',
    order_approved_at              TIMESTAMP_NTZ  COMMENT 'When payment was approved',
    order_delivered_carrier_date   TIMESTAMP_NTZ  COMMENT 'When the order was handed to the logistics partner',
    order_delivered_customer_date  TIMESTAMP_NTZ  COMMENT 'Actual delivery date to the customer',
    order_estimated_delivery_date  TIMESTAMP_NTZ  COMMENT 'Delivery date promised to the customer at purchase',
    CONSTRAINT pk_orders PRIMARY KEY (order_id)
) COMMENT = 'Source: olist_orders_dataset.csv';

-- olist_order_items_dataset.csv ----------------------------------------------
CREATE OR REPLACE TABLE ORDER_ITEMS (
    order_id             VARCHAR        COMMENT 'FK to ORDERS.order_id',
    order_item_id        INTEGER        COMMENT 'Item sequence number within the order (1, 2, 3...)',
    product_id           VARCHAR        COMMENT 'FK to PRODUCTS.product_id',
    seller_id            VARCHAR        COMMENT 'FK to SELLERS.seller_id',
    shipping_limit_date  TIMESTAMP_NTZ  COMMENT 'Deadline for the seller to hand the item to the carrier',
    price                NUMBER(10,2)   COMMENT 'Item price (BRL)',
    freight_value        NUMBER(10,2)   COMMENT 'Freight charged for this item (BRL); split across items when an order has several',
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id)
) COMMENT = 'Source: olist_order_items_dataset.csv';

-- olist_order_payments_dataset.csv -------------------------------------------
CREATE OR REPLACE TABLE ORDER_PAYMENTS (
    order_id              VARCHAR       COMMENT 'FK to ORDERS.order_id',
    payment_sequential    INTEGER       COMMENT 'Sequence when an order is paid with more than one method',
    payment_type          VARCHAR       COMMENT 'credit_card, boleto, voucher, debit_card, not_defined',
    payment_installments  INTEGER       COMMENT 'Number of installments chosen',
    payment_value         NUMBER(10,2)  COMMENT 'Amount paid in this payment row (BRL)',
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential)
) COMMENT = 'Source: olist_order_payments_dataset.csv';

-- olist_order_reviews_dataset.csv --------------------------------------------
CREATE OR REPLACE TABLE ORDER_REVIEWS (
    review_id                VARCHAR        COMMENT 'Review identifier (NOT unique on its own in the source)',
    order_id                 VARCHAR        COMMENT 'FK to ORDERS.order_id',
    review_score             INTEGER        COMMENT 'Satisfaction score 1-5',
    review_comment_title     VARCHAR        COMMENT 'Review title (Portuguese, often empty)',
    review_comment_message   VARCHAR        COMMENT 'Review text (Portuguese, often empty)',
    review_creation_date     TIMESTAMP_NTZ  COMMENT 'When the satisfaction survey was sent',
    review_answer_timestamp  TIMESTAMP_NTZ  COMMENT 'When the customer answered the survey',
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id, order_id)
) COMMENT = 'Source: olist_order_reviews_dataset.csv';

-- olist_products_dataset.csv  (column-name typos "lenght" are from the source)
CREATE OR REPLACE TABLE PRODUCTS (
    product_id                  VARCHAR  COMMENT 'Unique product identifier',
    product_category_name       VARCHAR  COMMENT 'Category name in Portuguese; FK to PRODUCT_CATEGORY_TRANSLATION',
    product_name_lenght         INTEGER  COMMENT 'Number of characters in the product name',
    product_description_lenght  INTEGER  COMMENT 'Number of characters in the product description',
    product_photos_qty          INTEGER  COMMENT 'Number of published product photos',
    product_weight_g            INTEGER  COMMENT 'Weight in grams',
    product_length_cm           INTEGER  COMMENT 'Length in cm',
    product_height_cm           INTEGER  COMMENT 'Height in cm',
    product_width_cm            INTEGER  COMMENT 'Width in cm',
    CONSTRAINT pk_products PRIMARY KEY (product_id)
) COMMENT = 'Source: olist_products_dataset.csv';

-- olist_sellers_dataset.csv --------------------------------------------------
CREATE OR REPLACE TABLE SELLERS (
    seller_id               VARCHAR  COMMENT 'Unique seller identifier',
    seller_zip_code_prefix  VARCHAR  COMMENT 'First 5 digits of the seller zip code',
    seller_city             VARCHAR  COMMENT 'Seller city name',
    seller_state            VARCHAR  COMMENT 'Seller state (2-letter UF code)',
    CONSTRAINT pk_sellers PRIMARY KEY (seller_id)
) COMMENT = 'Source: olist_sellers_dataset.csv';

-- olist_geolocation_dataset.csv  (many rows per zip prefix - no unique key)
CREATE OR REPLACE TABLE GEOLOCATION (
    geolocation_zip_code_prefix  VARCHAR  COMMENT 'First 5 digits of a zip code (repeats many times)',
    geolocation_lat              FLOAT    COMMENT 'Latitude',
    geolocation_lng              FLOAT    COMMENT 'Longitude',
    geolocation_city             VARCHAR  COMMENT 'City name',
    geolocation_state            VARCHAR  COMMENT 'State (2-letter UF code)'
) COMMENT = 'Source: olist_geolocation_dataset.csv';

-- product_category_name_translation.csv --------------------------------------
CREATE OR REPLACE TABLE PRODUCT_CATEGORY_TRANSLATION (
    product_category_name          VARCHAR  COMMENT 'Category name in Portuguese',
    product_category_name_english  VARCHAR  COMMENT 'Category name in English',
    CONSTRAINT pk_product_category_translation PRIMARY KEY (product_category_name)
) COMMENT = 'Source: product_category_name_translation.csv';

-- Confirm: should list 9 tables
SHOW TABLES IN SCHEMA CRI_DB.RAW;
