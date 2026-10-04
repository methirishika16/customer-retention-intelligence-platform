/* =============================================================================
   11_validate_retention_scores.sql
   Sprint 3: checks the Python output written to CRI_DB.ML.

   Run AFTER `python python/run_sprint3.py`. The editor shows the LAST query:
   a PASS/FAIL table. The queries above it are for exploring. Select one and click Run.
   ============================================================================= */

USE ROLE      SYSADMIN;
USE WAREHOUSE CRI_WH;
USE DATABASE  CRI_DB;

-- 1. Model vs simple rules on the out-of-time test (higher = better)
SELECT model, ROUND(roc_auc, 3) AS roc_auc, ROUND(pr_auc, 3) AS pr_auc,
       ROUND(lift_top_10pct, 2) AS lift_top_10pct, ROUND(capture_top_20pct, 3) AS capture_top_20pct
FROM ML.MODEL_EVALUATION ORDER BY roc_auc DESC;

-- 2. Customer groups: size, money, predicted return chance, chosen action
SELECT customer_group, next_best_action, COUNT(*) AS customers,
       ROUND(SUM(total_revenue)) AS historical_revenue,
       ROUND(AVG(return_probability) * 100, 2) AS avg_return_probability_pct,
       ROUND(AVG(priority_score), 1) AS avg_priority
FROM ML.CUSTOMER_RETENTION_SCORES
GROUP BY 1, 2 ORDER BY avg_priority DESC;

-- 3. Who to contact first with a R$25,000 budget
SELECT priority_rank, customer_unique_id, customer_group, next_best_action, action_cost_brl,
       total_revenue, recency_days, ROUND(return_probability * 100, 2) AS return_probability_pct,
       priority_score, cumulative_action_cost_brl
FROM ML.CUSTOMER_RETENTION_SCORES
WHERE cumulative_action_cost_brl <= 25000
ORDER BY priority_rank
LIMIT 50;

-- 4. FINAL: PASS / FAIL checks ---------------------------------------------------
WITH s AS (SELECT * FROM ML.CUSTOMER_RETENTION_SCORES),
checks AS (
    SELECT 'One row per customer (= MARTS.DIM_CUSTOMERS)' AS check_name,
           IFF((SELECT COUNT(*) FROM s) = (SELECT COUNT(*) FROM MARTS.DIM_CUSTOMERS)
               AND (SELECT COUNT(DISTINCT customer_unique_id) FROM s) = (SELECT COUNT(*) FROM s), 0, 1) AS problems
    UNION ALL
    SELECT 'Return probability between 0 and 1', COUNT_IF(return_probability NOT BETWEEN 0 AND 1) FROM s
    UNION ALL
    SELECT 'Priority score between 0 and 100', COUNT_IF(priority_score NOT BETWEEN 0 AND 100) FROM s
    UNION ALL
    SELECT 'Priority rank is 1..N with no gaps',
           IFF(MIN(priority_rank) = 1 AND MAX(priority_rank) = COUNT(*) AND COUNT(DISTINCT priority_rank) = COUNT(*), 0, 1) FROM s
    UNION ALL
    SELECT 'Every customer has a group, action and cost',
           COUNT_IF(customer_group IS NULL OR next_best_action IS NULL OR action_cost_brl IS NULL) FROM s
    UNION ALL
    SELECT 'Revenue matches dbt (DIM_CUSTOMERS)',
           IFF(ABS((SELECT SUM(total_revenue) FROM s) - (SELECT SUM(total_revenue) FROM MARTS.DIM_CUSTOMERS)) < 0.01, 0, 1)
    UNION ALL
    SELECT 'Loyal customers have 2+ purchase days', COUNT_IF(customer_group = 'Loyal Customer' AND purchase_days < 2) FROM s
    UNION ALL
    SELECT 'High Value groups are value_tier High',
           COUNT_IF(customer_group LIKE 'High Value%' AND value_tier <> 'High') FROM s
    UNION ALL
    SELECT 'High Risk groups are risk_tier High',
           COUNT_IF(customer_group LIKE '%High Risk' AND risk_tier <> 'High') FROM s
    UNION ALL
    SELECT 'Cumulative cost never decreases with rank',
           COUNT_IF(cumulative_action_cost_brl < prev_cost)
    FROM (SELECT cumulative_action_cost_brl,
                 LAG(cumulative_action_cost_brl) OVER (ORDER BY priority_rank) AS prev_cost FROM s)
    UNION ALL
    SELECT 'Budget scenarios stay within budget', COUNT_IF(spend_brl > budget_brl) FROM ML.BUDGET_SCENARIOS
    UNION ALL
    SELECT 'Model beats random on the test set',
           IFF((SELECT roc_auc FROM ML.MODEL_EVALUATION WHERE model = 'Logistic regression')
             > (SELECT roc_auc FROM ML.MODEL_EVALUATION WHERE model = 'Random (no model)'), 0, 1)
)
SELECT check_name, problems, IFF(problems = 0, 'PASS', 'FAIL') AS status
FROM checks
ORDER BY status, check_name;
