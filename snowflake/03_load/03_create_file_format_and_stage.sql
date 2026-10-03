/* =============================================================================
   03_create_file_format_and_stage.sql

   FILE FORMAT = instructions for how Snowflake should read the CSVs.
   STAGE       = a storage area inside Snowflake where you upload the files
                 before COPY INTO loads them into tables.

   After running this file you must UPLOAD the 9 CSVs to the stage
   (manual step - see README, Sprint 1, step 5), then run 04_load_raw_tables.sql.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

CREATE OR REPLACE FILE FORMAT FF_OLIST_CSV
    TYPE                           = CSV
    FIELD_DELIMITER                = ','
    SKIP_HEADER                    = 1           -- first line is the column header
    FIELD_OPTIONALLY_ENCLOSED_BY   = '"'         -- review text contains commas & line breaks inside quotes
    NULL_IF                        = ('')        -- empty field -> NULL
    EMPTY_FIELD_AS_NULL            = TRUE
    ENCODING                       = 'UTF8'      -- Portuguese accents (Sao Paulo)
    TIMESTAMP_FORMAT               = 'YYYY-MM-DD HH24:MI:SS'
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE        -- fail loudly if a file doesn't match its table
    COMPRESSION                    = AUTO        -- reads plain .csv and .csv.gz
    COMMENT = 'Olist Kaggle CSV files';

CREATE STAGE IF NOT EXISTS OLIST_STAGE
    FILE_FORMAT = FF_OLIST_CSV
    DIRECTORY   = (ENABLE = TRUE)                -- lets Snowsight show a file browser for the stage
    COMMENT     = 'Internal stage for the Olist CSV files';

-- Confirm
SHOW FILE FORMATS IN SCHEMA CRI_DB.RAW;

-- NEXT (manual): upload the 9 CSV files to @CRI_DB.RAW.OLIST_STAGE
-- (Snowsight UI or python/upload_to_stage.py), then run 04_load_raw_tables.sql.
-- Check with:  LIST @OLIST_STAGE;   -- should show 9 files
SHOW STAGES IN SCHEMA CRI_DB.RAW;
