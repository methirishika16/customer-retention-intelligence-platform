# Portfolio Kit

All numbers below come from the project's actual runs. Replace anything in `[INSERT …]` once it exists.

---

## Resume bullets (pick 3)

**Option A: Data / Analytics Engineer emphasis**
- Built an end-to-end customer retention platform on **Snowflake + dbt** over ~100k real e-commerce orders: 22 tested models (112 data tests), RFM segmentation and KPI marts, with revenue reconciled to the cent against an independent SQL recalculation.
- Developed a **leakage-safe logistic regression** in Python using time-based snapshots (train 2017, test 2018) to predict 180-day repeat purchases; the top decile returned **2× the base rate**, outperforming recency and RFM rules.
- Turned predictions into a **next-best-action and budget-allocation engine** (7 value × risk groups, 0-100 priority score) written back to Snowflake and visualised in Tableau. A R$25k plan reaches 2,223 customers, 99.6% of them high-value.

**Option B: Business / Data Analyst emphasis**
- Analysed 94,990 customers in SQL and Python and found that **97.8% buy only once** and the **top 20% drive 54% of revenue**, reframing retention as a second-purchase problem.
- Identified **9,135 high-value, high-risk customers (26.5% of revenue)** and showed that late deliveries cut average review scores from **4.29★ to 2.27★**, leading to 5 prioritised retention recommendations.
- Designed a **5-dashboard Tableau suite** (executive KPIs, RFM segments, cohort retention, opportunities, budget-constrained target list) backed by tested dbt models and documented assumptions.

## 60-second interview explanation

> "I built a customer retention platform on real Brazilian e-commerce data, about 100,000 orders.
> The business question was: which customers are most valuable, which are slipping away, and who should marketing contact first?
>
> I loaded the raw data into **Snowflake** and validated it with SQL, then modelled it in **dbt**. The key decision there was
> identifying the real customer, because the order-level customer ID changes every purchase. That gave me tested
> KPIs, RFM segments and cohort retention.
>
> The big finding was that **98% of customers buy only once**, so retention is really about the second purchase.
> There's no churn label, so instead of claiming churn I predicted *'will this customer buy again in 180 days?'*
> with a **logistic regression**, trained on 2017 and tested on 2018 to avoid leakage. It doubles the hit rate in the
> top decile. It's modest, and I'm upfront about that. The strongest drivers were recency and customer experience, not spend.
> Late deliveries, for example, drop reviews by two stars.
>
> Finally, I turned the scores into **next-best actions and a priority score**, so with a R$25k budget the team knows exactly
> which 2,200 customers to contact and with what offer, all shown in **Tableau**. My main recommendation was to fix delivery
> experience and run an A/B test before scaling discounts."

**Likely follow-up questions (have an answer ready):**
| Question | Short answer |
|---|---|
| Why logistic regression, not XGBoost? | Rare outcome (~1% positives) and a stakeholder audience. Interpretable odds ratios beat a black box; extra features didn't improve the out-of-time test. |
| How did you avoid leakage? | Features built "as of" a date from orders placed, deliveries arrived and reviews answered before it; train windows end before the test window starts. |
| Isn't AUC 0.59 bad? | It's weak but real (random = 0.52 on the same test). I use it to *rank* customers and say so; precise individual prediction isn't supported by this data. |
| How would you know the campaign worked? | A/B test with a holdout per action; measure incremental repeat rate. The model predicts who returns, not uplift. |
| Why `customer_unique_id`? | `customer_id` is regenerated per order; using it would make every customer look new and the repeat rate 0%. |

## LinkedIn post / project description

> **Customer Retention Intelligence Platform** | Snowflake · dbt · Python · Tableau
>
> Which customers matter most, who's slipping away, and who should marketing contact first?
> I built an end-to-end analytics pipeline on ~100k real e-commerce orders to answer that:
> ❄️ Snowflake warehouse with SQL data-quality checks
> 🔧 dbt models (112 tests) for KPIs, RFM segments and cohort retention
> 🐍 A leakage-safe repeat-purchase model, next-best-action rules and a budget-constrained priority list
> 📊 Tableau dashboards for executives and marketing
>
> Biggest insight: 98% of customers buy only once, and late deliveries cut review scores from 4.3★ to 2.3★.
> Retention here starts with getting the second purchase and the delivery right.
>
> Dashboard: `[INSERT Tableau Public link]` · Code: `[INSERT GitHub link]`

## GitHub repository "About" (max 350 characters)

> End-to-end customer retention analytics on 100k e-commerce orders: Snowflake + dbt (RFM, KPIs, cohorts, 112 tests), a leakage-safe Python repeat-purchase model, next-best-action and budget-prioritised target list, Tableau dashboards.

**Topics:** `snowflake` `dbt` `sql` `python` `scikit-learn` `tableau` `customer-retention` `rfm-analysis` `analytics-engineering` `data-portfolio`
