/* =============================================================================
   10_validate_dbt_models.sql
   Sprint 2: do the dbt model numbers make sense?

   Run AFTER `dbt build` succeeds. It compares the MARTS tables with the RAW
   data loaded in Sprint 1, calculated a second, independent way.

   The editor shows only the LAST query's result: the final PASS/FAIL table.
   The queries above it are "look and sanity-check" queries. To see one, select
   it and click Run.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;

-- 1. Headline KPIs: eyeball them. Do they look like a mid-size Brazilian marketplace?
SELECT * FROM MARTS.KPI_SUMMARY;

-- 2. RFM segments: how many customers, how much money, how recent?
SELECT
    rfm_segment,
    COUNT(*)                                   AS customers,
    ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct_customers,
    ROUND(SUM(total_revenue), 0)               AS revenue,
    ROUND(AVG(days_since_last_purchase), 0)    AS avg_days_since_last_purchase,
    ROUND(AVG(order_count), 2)                 AS avg_orders
FROM MARTS.CUSTOMER_RFM
GROUP BY rfm_segment
ORDER BY revenue DESC;

-- 3. Activity thresholds: is 180 / 365 days sensible?
--    Look at the typical gap between purchases among repeat customers.
SELECT
    COUNT(*)                                                        AS repeat_customers,
    APPROX_PERCENTILE(avg_days_between_purchases, 0.50)             AS p50_gap_days,
    APPROX_PERCENTILE(avg_days_between_purchases, 0.75)             AS p75_gap_days,
    APPROX_PERCENTILE(avg_days_between_purchases, 0.90)             AS p90_gap_days
FROM MARTS.DIM_CUSTOMERS
WHERE is_repeat_customer;

-- 4. Top 10 high-value customers to contact first
SELECT customer_unique_id, customer_state, order_count, total_revenue,
       days_since_last_purchase, rfm_cell, rfm_segment, activity_status, retention_priority
FROM MARTS.CUSTOMER_RFM
WHERE is_high_value
ORDER BY retention_priority, total_revenue DESC
LIMIT 10;

-- 5. Monthly trend (low-volume months flagged)
SELECT * FROM MARTS.MONTHLY_REVENUE ORDER BY purchase_month;

-- 6. Top categories
SELECT * FROM MARTS.CATEGORY_PERFORMANCE ORDER BY revenue_rank LIMIT 15;

-- 7. FINAL: independent recalculation from RAW vs. the dbt marts ---------------
WITH raw_valid_orders AS (
    SELECT o.order_id, c.customer_unique_id
    FROM RAW.ORDERS o
    JOIN RAW.CUSTOMERS c ON o.customer_id = c.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
raw_revenue AS (
    -- Recalculate revenue straight from RAW payments (+ items for the order with no payment)
    SELECT SUM(COALESCE(p.paid, i.gross, 0)) AS revenue
    FROM raw_valid_orders v
    LEFT JOIN (SELECT order_id, SUM(payment_value) AS paid FROM RAW.ORDER_PAYMENTS GROUP BY 1) p ON v.order_id = p.order_id
    LEFT JOIN (SELECT order_id, SUM(price + freight_value) AS gross FROM RAW.ORDER_ITEMS GROUP BY 1) i ON v.order_id = i.order_id
),
raw_repeat AS (
    SELECT COUNT(*) AS repeat_customers
    FROM (SELECT customer_unique_id FROM raw_valid_orders GROUP BY 1 HAVING COUNT(*) >= 2)
),
k AS (SELECT * FROM MARTS.KPI_SUMMARY),
checks AS (
    SELECT 'Orders: RAW vs KPI_SUMMARY' AS check_name,
           (SELECT COUNT(*) FROM raw_valid_orders)::FLOAT AS raw_value,
           (SELECT total_orders FROM k)::FLOAT            AS dbt_value
    UNION ALL
    SELECT 'Unique customers: RAW vs KPI_SUMMARY',
           (SELECT COUNT(DISTINCT customer_unique_id) FROM raw_valid_orders),
           (SELECT unique_customers FROM k)
    UNION ALL
    SELECT 'Revenue: RAW vs KPI_SUMMARY',
           (SELECT ROUND(revenue, 2) FROM raw_revenue),
           (SELECT ROUND(total_revenue, 2) FROM k)
    UNION ALL
    SELECT 'Repeat customers: RAW vs KPI_SUMMARY',
           (SELECT repeat_customers FROM raw_repeat),
           (SELECT repeat_customers FROM k)
    UNION ALL
    SELECT 'All orders: RAW vs FCT_ORDERS',
           (SELECT COUNT(*) FROM RAW.ORDERS),
           (SELECT COUNT(*) FROM MARTS.FCT_ORDERS)
    UNION ALL
    SELECT 'Customers: DIM_CUSTOMERS vs CUSTOMER_RFM rows',
           (SELECT COUNT(*) FROM MARTS.DIM_CUSTOMERS),
           (SELECT COUNT(*) FROM MARTS.CUSTOMER_RFM)
    UNION ALL
    SELECT 'Item revenue: RAW items (valid orders) vs CATEGORY_PERFORMANCE',
           (SELECT ROUND(SUM(i.price), 2) FROM RAW.ORDER_ITEMS i JOIN raw_valid_orders v ON i.order_id = v.order_id),
           (SELECT ROUND(SUM(item_revenue), 2) FROM MARTS.CATEGORY_PERFORMANCE)
    UNION ALL
    SELECT 'Monthly new customers sum vs unique customers',
           (SELECT SUM(new_customers) FROM MARTS.MONTHLY_REVENUE),
           (SELECT unique_customers FROM k)
    UNION ALL
    SELECT 'R-score 5 share is ~20% (x100)',
           20,
           (SELECT ROUND(100 * COUNT_IF(r_score = 5) / COUNT(*)) FROM MARTS.CUSTOMER_RFM)
)
SELECT
    check_name,
    raw_value,
    dbt_value,
    CASE
        WHEN check_name LIKE 'R-score%' THEN IFF(ABS(raw_value - dbt_value) <= 5, 'PASS', 'WARN')
        WHEN ABS(raw_value - dbt_value) <= 0.01 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM checks
ORDER BY status, check_name;
