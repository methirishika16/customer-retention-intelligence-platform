/* =============================================================================
   04_load_raw_tables.sql
   Loads every staged CSV into its RAW table with COPY INTO.

   Prerequisite: LIST @CRI_DB.RAW.OLIST_STAGE shows the 9 CSV files.

   How it works
     * TRUNCATE first, so re-running this file gives a clean reload instead of
       duplicate rows. (TRUNCATE also clears Snowflake's "already loaded" memory
       for those files, so COPY will load them again.)
     * PATTERN matches the file whether it was uploaded as .csv (Snowsight UI)
       or .csv.gz (PUT from Python).
     * ON_ERROR = ABORT_STATEMENT: if ANY row fails (wrong type, wrong column
       count), the whole table load stops and shows you the error. For a
       portfolio project we want to see problems, not silently skip rows.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- 0. Sanity check: you should see 9 files ------------------------------------
LIST @OLIST_STAGE;

/* OPTIONAL dry run - validates a file WITHOUT loading it. Empty result = no errors.
COPY INTO ORDER_REVIEWS
FROM @OLIST_STAGE
PATTERN = '.*olist_order_reviews_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
VALIDATION_MODE = RETURN_ERRORS;
*/

-- 1. CUSTOMERS ---------------------------------------------------------------
TRUNCATE TABLE IF EXISTS CUSTOMERS;
COPY INTO CUSTOMERS
FROM @OLIST_STAGE
PATTERN = '.*olist_customers_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 2. ORDERS ------------------------------------------------------------------
TRUNCATE TABLE IF EXISTS ORDERS;
COPY INTO ORDERS
FROM @OLIST_STAGE
PATTERN = '.*olist_orders_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 3. ORDER_ITEMS -------------------------------------------------------------
TRUNCATE TABLE IF EXISTS ORDER_ITEMS;
COPY INTO ORDER_ITEMS
FROM @OLIST_STAGE
PATTERN = '.*olist_order_items_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 4. ORDER_PAYMENTS ----------------------------------------------------------
TRUNCATE TABLE IF EXISTS ORDER_PAYMENTS;
COPY INTO ORDER_PAYMENTS
FROM @OLIST_STAGE
PATTERN = '.*olist_order_payments_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 5. ORDER_REVIEWS -----------------------------------------------------------
TRUNCATE TABLE IF EXISTS ORDER_REVIEWS;
COPY INTO ORDER_REVIEWS
FROM @OLIST_STAGE
PATTERN = '.*olist_order_reviews_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 6. PRODUCTS ----------------------------------------------------------------
TRUNCATE TABLE IF EXISTS PRODUCTS;
COPY INTO PRODUCTS
FROM @OLIST_STAGE
PATTERN = '.*olist_products_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 7. SELLERS -----------------------------------------------------------------
TRUNCATE TABLE IF EXISTS SELLERS;
COPY INTO SELLERS
FROM @OLIST_STAGE
PATTERN = '.*olist_sellers_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 8. GEOLOCATION (~1M rows - takes a few extra seconds) ----------------------
TRUNCATE TABLE IF EXISTS GEOLOCATION;
COPY INTO GEOLOCATION
FROM @OLIST_STAGE
PATTERN = '.*olist_geolocation_dataset[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 9. PRODUCT_CATEGORY_TRANSLATION --------------------------------------------
TRUNCATE TABLE IF EXISTS PRODUCT_CATEGORY_TRANSLATION;
COPY INTO PRODUCT_CATEGORY_TRANSLATION
FROM @OLIST_STAGE
PATTERN = '.*product_category_name_translation[.]csv([.]gz)?'
FILE_FORMAT = (FORMAT_NAME = 'FF_OLIST_CSV')
ON_ERROR = 'ABORT_STATEMENT';

-- 10. Load audit: one row per file loaded in the last 24 hours ---------------
SELECT table_name, file_name, status, row_count, row_parsed, first_error_message, last_load_time
FROM CRI_DB.INFORMATION_SCHEMA.LOAD_HISTORY
WHERE schema_name = 'RAW'
  AND last_load_time >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
ORDER BY last_load_time DESC;
