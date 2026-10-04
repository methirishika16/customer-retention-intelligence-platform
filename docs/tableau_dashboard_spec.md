# Tableau Dashboard Specification

Five dashboards (plus an optional model appendix) built on the data exported by
`python python/export_tableau_data.py`. Every number quoted here comes from the
pipeline run on 2026-10-04. Places marked **`[INSERT …]`** are only known once you build
the workbook (screenshots, links).

---

## 0. Global design

| Setting | Value |
|---|---|
| Dashboard size | Fixed **1200 × 800** (renders well on Tableau Public and in a README screenshot) |
| Layout | Title + subtitle band (top) → filter row → KPI row (where used) → 2-3 views |
| Font | Tableau Book / Tableau Medium for titles. Titles 18pt, subtitles 11pt grey `#52514e` |
| Background | `#fcfcfb`; light grid lines `#e6e5e0`; no borders on sheets |
| Currency | BRL, format `R$ #,##0` (`R$ #,##0.0,,"M"` for millions) |
| Navigation | A text button bar under the title linking the 5 dashboards (Dashboard → Navigation object) |

### Colour roles (use consistently on every dashboard)
| Role | Colour | Used for |
|---|---|---|
| Primary measure | blue `#2a78d6` | revenue, customers, any single-series bar or line |
| Highlight / attention | orange `#eb6834` | High risk, "the thing to look at", the selected budget |
| Value tier (ordinal) | High `#104281` · Medium `#2a78d6` · Low `#86b6ef` | value tier, priority bands |
| Risk tier | High `#eb6834` · Medium `#a8a79f` · Low `#d6d5cf` | risk is shown as *attention*, not as a rainbow |
| Heatmaps | sequential blue `#cde2fb` → `#0d366b` | cohort retention, R × M matrix |
| Comparison series (2 max) | blue `#2a78d6` + aqua `#1baf7a` | new vs returning |

Rules: never a dual axis (two y-scales); label values directly where there are 7 or fewer marks; every
colour that carries meaning also has a legend or label.

---

## 1. Data sources and relationships

Add these CSVs from `tableau/data/` as separate data sources. **Don't join** them. Each view uses one source.

| Source | Grain | Rows | Powers |
|---|---|---:|---|
| `customers.csv` | customer | 94,990 | Most views (segments, risk, actions, priority) |
| `kpi_summary.csv` | 1 row | 1 | Executive KPI tiles |
| `monthly_revenue.csv` | month | 24 | Trends, new vs returning |
| `cohort_retention.csv` | cohort × month offset | 278 | Cohort heatmap |
| `category_performance.csv` | product category | 74 | Category opportunities |
| `budget_scenarios.csv` | budget | 4 | Budget reference table |
| `model_*.csv` | small | 4-10 | Model appendix |

Data types to check after import: `*_date`, `*_month` → Date; `customer_unique_id` → String;
`return_probability`, `retention_rate` → Number (decimal), shown as %.

### Calculated fields (create in `customers.csv`)
```text
Customers                 = COUNTD([Customer Unique Id])
Revenue                   = SUM([Total Revenue])
Revenue Share             = SUM([Total Revenue]) / TOTAL(SUM([Total Revenue]))          // table calc
High-Value Customers      = COUNTD(IF [Value Tier] = "High" THEN [Customer Unique Id] END)
High-Risk Revenue         = SUM(IF [Risk Tier] = "High" THEN [Total Revenue] END)       // HISTORICAL revenue of high-risk customers
Avg Return Probability    = AVG([Return Probability])
Expected Revenue 180d     = SUM([Expected Revenue 180D])                                // prediction, if nothing is done
Lifecycle Stage           = IF [Customer Group] = "Loyal Customer" THEN "Loyal"
                            ELSEIF [Customer Group] = "New Customer" THEN "New"
                            ELSEIF [Risk Tier] = "High" THEN "At-risk"
                            ELSE "Other one-time" END
Revenue Band              = IF [Total Revenue] < 50 THEN "1: < R$50"
                            ELSEIF [Total Revenue] < 100 THEN "2: R$50-99"
                            ELSEIF [Total Revenue] < 200 THEN "3: R$100-199"
                            ELSEIF [Total Revenue] < 500 THEN "4: R$200-499"
                            ELSEIF [Total Revenue] < 1000 THEN "5: R$500-999"
                            ELSE "6: R$1,000+" END
Within Budget             = [Cumulative Action Cost Brl] <= [p.Marketing Budget]
Budget Spend              = SUM(IF [Within Budget] THEN [Action Cost Brl] END)
Customers In Budget       = COUNTD(IF [Within Budget] THEN [Customer Unique Id] END)
Running Cost (filtered)   = RUNNING_SUM(SUM([Action Cost Brl]))     // table calc, compute along Priority Rank
```
**Parameter** `p.Marketing Budget`: Float, range 0-200,000, step 5,000, default **25,000**, display `R$ #,##0`.
Show it as a slider on Dashboard 5.

Why two cumulative-cost fields? `cumulative_action_cost_brl` is pre-computed for the **whole** list (fast, exact).
If the user filters (e.g. one state), use `Running Cost (filtered)` so the budget applies to the filtered list.

---

## 2. Dashboard 1: Executive Overview

**Title:** Customer Retention Intelligence: Executive Overview
**Subtitle:** Olist marketplace · valid purchases Sep 2016 – Aug 2018 · revenue in BRL
**Business question:** How big is the business, and does it keep its customers?

| # | View | Chart type | Dimensions | Measures | Business question |
|---|---|---|---|---|---|
| 1.1 | KPI row (6 tiles) | **Big numbers (BANs)**, one sheet per tile | — | `total_revenue`, `total_orders`, `unique_customers`, `avg_order_value`, `repeat_purchase_rate` (kpi_summary); `High-Value Customers` + its revenue share (customers) | What are the headline numbers? |
| 1.2 | Monthly revenue | **Line** (blue, 2px) with end-point label | `purchase_month` (continuous month) | `revenue` | Is revenue growing? |
| 1.3 | New vs returning customers | **Stacked bar** by month (blue = new, aqua = returning) | `purchase_month` | `new_customers`, `returning_customers` (Measure Names/Values) | Is growth coming from new or returning customers? |
| 1.4 | Returning share | **Line** | `purchase_month` | `returning_customer_share` | Is the returning share improving? |

**Filters:** `purchase_month` range slider · `is_low_volume_month` = False (set as a context filter; hides 2016-09, 2016-12, 2018-09).
**Tile values (actual):** Revenue R$ 15.74M · Orders 98,207 · Customers 94,990 · AOV R$ 160.27 · Repeat purchase rate 3.04% · High-value customers 19,715 (54% of revenue).
**Annotation on 1.3:** "Returning customers grew from ~0.1% to ~3% of monthly buyers, still a small minority."

## 3. Dashboard 2: Customer Segmentation

**Title:** Who Are Our Customers?
**Subtitle:** RFM segments, value distribution and lifecycle stage · 94,990 customers as of 2018-09-03
**Business question:** Which customers are most valuable, and how are they distributed?

| # | View | Chart type | Dimensions | Measures | Business question |
|---|---|---|---|---|---|
| 2.1 | RFM segments | **Horizontal bar** sorted by revenue; label = customers + revenue share | `rfm_segment` | `Revenue`, `Customers` (in label/tooltip) | Which segments hold the money? |
| 2.2 | Recency × Monetary matrix | **Highlight table / heatmap** 5 × 5 | `r_score` (columns), `m_score` (rows) | `Customers` (colour, sequential blue), `Revenue` (label) | Where are valuable customers that haven't bought recently? (top-left cells) |
| 2.3 | Value distribution | **Bar** (ordered bands, not a histogram of raw values, which is too skewed) | `Revenue Band` | `Customers`; tooltip `Revenue` | How is spend distributed? |
| 2.4 | Lifecycle mix | **Horizontal bar** (100% of customers), 4 bars | `Lifecycle Stage` | `Customers`, `Revenue Share` | How many are loyal vs new vs at-risk? |

**Filters:** `customer_state` (multi-select dropdown) · `value_tier` · `activity_status`.
**Actions:** clicking a segment in 2.1 filters 2.2-2.4 (Dashboard → Actions → Filter, on select).
**Why not F in the matrix?** 97.8% of customers have F = 1, so an R × F grid would be one stripe. R × M carries the information.

## 4. Dashboard 3: Retention Intelligence

**Title:** Who Is Slipping Away?
**Subtitle:** Predicted return likelihood, high-value customers at risk and cohort retention · risk = relative ranking, not a churn label
**Business question:** Which customers are becoming inactive, and how well do we retain each cohort?

| # | View | Chart type | Dimensions | Measures | Business question |
|---|---|---|---|---|---|
| 3.1 | Risk distribution | **Bar** (3 bars, High in orange) | `risk_tier` | `Customers`; tooltip `Avg Return Probability` | How is risk spread across the base? |
| 3.2 | Value × risk matrix | **Highlight table** 3 × 3, High/High cell outlined in orange | `value_tier` (rows), `risk_tier` (columns) | `Customers` (label), `Revenue` (label line 2), colour = `Revenue` | **How much valuable business sits with high-risk customers?** |
| 3.3 | Activity by value tier | **100% stacked horizontal bar** | `value_tier` | `Customers` split by `activity_status` (Active blue, Cooling orange, Inactive grey) | Are high-value customers going quiet? |
| 3.4 | Cohort retention | **Heatmap** (sequential blue), month 0 hidden | `acquisition_month` (rows), `months_since_acquisition` 1-12 (columns) | `retention_rate` (colour + label as %) | Do newer cohorts come back more than older ones? |

**Filters:** `customer_state` · `value_tier` (3.1-3.3) · on 3.4: `is_small_cohort` = False and `months_since_acquisition` 1-12.
**Key numbers (actual):** High value × High risk = **9,315 customers, R$ 4.27M historical revenue**.
High-value customers by status: Active 7,933 · **Cooling 7,292 (R$ 3.08M)** · Inactive 4,490.
Cohort month-1 retention averages **0.48%**; among 2017-2018 cohorts it ranges from 0.22% (Dec 2017) to 0.71% (Oct 2017).
**Caption (required):** "Risk tiers rank customers by the model's predicted chance of buying again in 180 days.
No customer is labelled 'churned': the data has no churn event."

## 5. Dashboard 4: Growth Opportunities

**Title:** Where Is the Opportunity?
**Subtitle:** Retention groups, recommended next-best actions and category performance
**Business question:** Which groups deserve attention, and what should we do for each?

| # | View | Chart type | Dimensions | Measures | Business question |
|---|---|---|---|---|---|
| 4.1 | Opportunity map | **Scatter / bubble** (7 labelled bubbles) | `customer_group` (detail + label) | X = `Revenue` (historical), Y = `Avg Return Probability`, size = `Customers` | Which groups combine high value with a realistic chance of returning? |
| 4.2 | Recommended actions | **Horizontal bar** sorted by customers; label = customers · total cost | `next_best_action` | `Customers`, `SUM(Action Cost Brl)` (label) | What does each action cover and cost? |
| 4.3 | Group → action detail | **Text table** | `customer_group`, `next_best_action`, `action_reason` | `Customers`, `Revenue`, `Expected Revenue 180d` | Why does each group get its action? |
| 4.4 | Category performance | **Horizontal bar**, top 15 by `item_revenue`, colour = `avg_review_score` (sequential; low scores stand out) | `product_category` | `item_revenue`, `avg_review_score` | Which categories drive revenue, and which disappoint customers? |

**Filters:** `customer_group` · `next_best_action` · `customer_state`.
**Actions:** select a bubble in 4.1 → filters 4.2 and 4.3.
**Key numbers (actual):** "High Value – High Risk" is the largest revenue group: **9,135 customers, 26.5% of historical revenue**.
8,415 valuable customers left a 1-2★ review → *Service recovery*. Late deliveries average **2.27★ vs 4.29★** on time.
**Tooltip wording:** call `Expected Revenue 180d` "expected revenue if no action is taken (model estimate)".

## 6. Dashboard 5: Marketing Prioritization

**Title:** Who Should We Contact First?
**Subtitle:** Customers ranked by priority score · move the budget slider to see who is covered · action costs are illustrative
**Business question:** With a limited budget, which customers do we target, with what action, and what does it cover?

| # | View | Chart type | Dimensions | Measures | Business question |
|---|---|---|---|---|---|
| 5.1 | Budget control | **Parameter slider** `p.Marketing Budget` | — | — | How much can we spend? |
| 5.2 | Budget KPI row | **BANs** (4 tiles) | — | `Customers In Budget`, `Budget Spend`, high-value customers in budget, revenue share of covered customers | What does this budget buy? |
| 5.3 | Budget curve | **Line** of cumulative cost vs rank, with a **reference line** at the parameter (orange) | `priority_rank` (continuous) | `cumulative_action_cost_brl` | How fast does spend accumulate down the list? |
| 5.4 | Action mix in budget | **Horizontal bar** | `next_best_action` | `Customers In Budget` | Which actions does the budget fund? |
| 5.5 | Priority list | **Text table**, top 100 rows within budget | `priority_rank`, `customer_unique_id` (first 8 characters), `customer_state`, `customer_group`, `next_best_action` | `priority_score`, `total_revenue`, `recency_days`, `return_probability` (%), `action_cost_brl` | **Exactly who do we contact, in what order?** |

**Filters:** `Within Budget` = True (on 5.4-5.5) · `customer_state` · `next_best_action` · `value_tier`.
When a dimension filter is active, switch 5.5's budget logic to `Running Cost (filtered)`.
**Reference (actual, from `budget_scenarios.csv`):**

| Budget | Customers reached | High-value | Share of historical revenue |
|---:|---:|---:|---:|
| R$ 10,000 | 796 | 796 | 3.2% |
| R$ 25,000 | 2,223 | 2,213 | 7.8% |
| R$ 50,000 | 5,528 | 5,202 | 16.0% |
| R$ 100,000 | 12,393 | 9,082 | 29.2% |

**Caption (required):** "Priority = 45% value + 35% predicted return likelihood + 20% urgency. Costs per action are
placeholders; the incremental effect of each action must be measured with an A/B test."

## 7. Optional appendix: Model Card

**Title:** How Good Is the Model?  **Subtitle:** Out-of-time test on customers as of 2018-03-01 (next 180 days)

| View | Chart | Fields |
|---|---|---|
| Lift by decile | Bar, decile 1 highlighted, reference line at 1.0 | `decile`, `lift` (model_lift_by_decile) |
| Model vs rules | Text table | `model`, `roc_auc`, `lift_top_10pct`, `capture_top_20pct` (model_evaluation) |
| Drivers | Diverging bar around 1.0 | `feature`, `odds_ratio_per_sd`, colour = `stable_direction` (model_coefficients) |

---

## 8. Build order (beginner steps)

1. Install **Tableau Public** (free) from public.tableau.com, or use Tableau Desktop.
2. Run `python python/export_tableau_data.py` → CSVs appear in `tableau/data/`.
3. Tableau → Connect → *Text file* → `customers.csv`. Repeat (Data → New Data Source) for the others.
4. Create the calculated fields and the `p.Marketing Budget` parameter from section 1.
5. Build each **sheet** (one view = one sheet), named like `1.2 Monthly revenue`.
6. Build each **dashboard** at 1200 × 800: drag in sheets, add title/subtitle text objects, filters, captions.
7. Add filter actions (Dashboard → Actions) and the navigation buttons.
8. File → Save to Tableau Public → copy the link into the README: **`[INSERT Tableau Public link]`**.
9. Export each dashboard as an image (Dashboard → Export Image) into `docs/images/dashboard/`:
   `01_executive_overview.png` … `05_marketing_prioritization.png` → **`[INSERT screenshots]`**.
10. Optionally save the workbook *without* data as `tableau/customer_retention.twb` (packaged `.twbx` files are git-ignored).

### Tableau Desktop / Cloud alternative (live Snowflake)
Connect → Snowflake → server `<org>-<account>.snowflakecomputing.com`, warehouse `CRI_WH`, database `CRI_DB`,
then use `ML.CUSTOMER_RETENTION_SCORES` and the `MARTS.*` tables instead of the CSVs. Field names are identical.
