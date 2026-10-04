# Sprint 2 — Results

Run on 2026-10-04 with dbt 1.12.5 and dbt-snowflake 1.12.1.

## Build
`dbt build` → **PASS = 128, WARN = 0, ERROR = 0**
- 21 models: 13 views (9 staging + 4 intermediate) and 8 tables (4 core marts + 4 metric marts)
- 107 data tests: generic `unique`, `not_null`, `relationships`, `accepted_values` + 6 custom tests
- *Sprint 4 added `cohort_retention` (+5 tests): the project now has **22 models and 112 tests** (`dbt build` PASS = 134).*

| Custom test | Checks |
|---|---|
| `assert_no_negative_revenue` | No negative revenue, item value or freight |
| `assert_no_impossible_order_dates` | No purchases outside 2016–today; no step before the purchase |
| `assert_no_duplicate_order_ids` | Each order appears once in `fct_orders` |
| `assert_customer_revenue_reconciles` | Revenue and order count match between `fct_orders` and `dim_customers` |
| `assert_monthly_revenue_reconciles` | Months add up to `kpi_summary`; new + returning = unique customers |
| `assert_rfm_covers_every_customer` | `customer_rfm` has exactly one row per customer |

## Independent validation (`snowflake/05_dbt_validation/10_validate_dbt_models.sql`)
Recalculated straight from RAW, compared with the marts: **9 / 9 PASS**.

| Check | RAW | dbt |
|---|---:|---:|
| Valid orders | 98,207 | 98,207 |
| Unique customers | 94,990 | 94,990 |
| Revenue (BRL) | 15,739,280.47 | 15,739,280.47 |
| Repeat customers | 2,888 | 2,888 |
| All orders in fct_orders | 99,441 | 99,441 |
| Item revenue in category_performance | 13,494,400.74 | 13,494,400.74 |

## Headline numbers (valid purchases, 2016-09-04 → 2018-09-03)

| KPI | Value |
|---|---:|
| Total revenue | R$ 15.74M |
| Orders | 98,207 |
| Unique customers | 94,990 |
| Average order value | R$ 160.27 |
| Items per order | 1.14 |
| Repeat purchase rate | **3.04%** (2,888 customers) |
| Orders per customer | 1.034 |
| Median gap between purchases (repeaters) | 32 days |

## Customer value & retention

- **High-value customers: 19,715 (20.8%) generate 54.4% of revenue.**
- **Priority 1** (high value & Cooling, 181–365 days quiet): **7,292 customers, R$ 3.08M** of historical revenue.
- Priority 2 (high value & Inactive, or repeat buyers going quiet): 4,854 customers, R$ 2.00M.

| RFM segment | Customers | Revenue (R$) | Avg days since last purchase |
|---|---:|---:|---:|
| High-Value Recent | 10,267 | 4,513,472 | 137 |
| High-Value Lapsing | 7,152 | 3,208,498 | 402 |
| Recent One-Time Buyers | 29,613 | 2,867,816 | 95 |
| Needs Attention | 15,046 | 1,435,370 | 224 |
| Hibernating | 14,972 | 1,422,650 | 321 |
| Lost | 15,052 | 1,400,939 | 478 |
| Champions | 1,003 | 374,089 | 93 |
| At-Risk Repeat Customers | 1,041 | 308,718 | 387 |
| Loyal Customers | 844 | 207,726 | 187 |

## Observations to carry into Sprint 3
- Retention is mostly about winning the **second** purchase (97% buy once).
- The returning-customer share grew from ~0.1% (Jan 2017) to ~3% (mid 2018).
- Top categories by item revenue: health_beauty, watches_gifts, bed_bath_table, sports_leisure, computers_accessories.
- office_furniture has the lowest average review (3.62) among the top 15 categories. Worth checking against repeat rate.
