/* =============================================================================
   01_create_warehouse_database_schema.sql
   Sprint 1 - Customer Retention Intelligence Platform

   Creates:
     - CRI_WH   : an X-Small warehouse (compute) that auto-suspends after 60s
     - CRI_DB   : the project database
     - CRI_DB.RAW : schema holding the data exactly as it arrives from the CSVs

   Later sprints: dbt will create its own STAGING / MARTS schemas in CRI_DB.

   Run in: a Snowsight SQL worksheet  (Run All = Cmd/Ctrl + Shift + Enter)
   Safe to re-run: yes (IF NOT EXISTS everywhere)
   ============================================================================= */

-- SYSADMIN is the role Snowflake recommends for creating databases & warehouses.
-- On a trial account your user already has it.
USE ROLE SYSADMIN;

-- 1. Compute ---------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS CRI_WH
    WAREHOUSE_SIZE      = 'XSMALL'   -- smallest = cheapest; plenty for ~1.5M rows
    AUTO_SUSPEND        = 60         -- seconds idle before it stops billing
    AUTO_RESUME         = TRUE       -- wakes up automatically when you run a query
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Customer Retention Intelligence Platform - dev warehouse';

-- 2. Storage ---------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS CRI_DB
    COMMENT = 'Customer Retention Intelligence Platform';

CREATE SCHEMA IF NOT EXISTS CRI_DB.RAW
    COMMENT = 'Raw Olist e-commerce data, loaded 1:1 from source CSV files';

-- 3. Set the worksheet context for the next scripts -------------------------
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;
USE SCHEMA    RAW;

-- 4. Confirm --------------------------------------------------------------
SHOW WAREHOUSES LIKE 'CRI_WH';
SHOW SCHEMAS IN DATABASE CRI_DB;
