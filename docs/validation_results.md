# Sprint 1 — Validation Results

Results of running `snowflake/04_validation/*.sql` against `CRI_DB.RAW` on 2026-10-03.

## 05 Row counts — ✅ PASS
All 9 tables match the source CSV row counts (e.g. CUSTOMERS = ORDERS = 99,441; GEOLOCATION = 1,000,163).

## 06 Null checks — ✅ PASS (0 FAIL · 39 PASS · 13 INFO)
No required (key) column has nulls. Expected, business-meaningful nulls:

| Table | Column | Nulls | % | Why it's expected | Sprint 2 handling |
|---|---|---:|---:|---|---|
| ORDERS | order_approved_at | 160 | 0.16 | Payment never approved (mostly canceled) | Keep null |
| ORDERS | order_delivered_carrier_date | 1,783 | 1.79 | Order never shipped | Keep null |
| ORDERS | order_delivered_customer_date | 2,965 | 2.98 | Order never delivered | Exclude from delivery-time metrics |
| ORDER_REVIEWS | review_comment_message | 58,247 | 58.70 | Customers gave a score without text | Use `review_score` only |
| ORDER_REVIEWS | review_comment_title | 87,656 | 88.34 | Title is optional | Ignore |
| PRODUCTS | product_category_name | 610 | 1.85 | Uncategorised products | Label `unknown` |
| PRODUCTS | product_name_lenght, product_description_lenght, product_photos_qty | 610 each | 1.85 | Same 610 products as above | Keep null |
| PRODUCTS | product_weight_g, product_length_cm, product_height_cm, product_width_cm | 2 each | 0.01 | Missing dimensions | Keep null |

## 07 Duplicate checks — ✅ PASS
All 8 primary keys unique (duplicate_keys = 0). Repeat customer_unique_id values, shared review_ids and duplicate GEOLOCATION rows are expected source characteristics (Sections B–C of the script).
## 08 Data type validation — ✅ PASS (0 FAIL · 22 PASS · 7 WARN)
Schema contract passed: all 52 columns have the designed name, position and type.
All hard value rules passed (review_score 1–5, prices > 0, valid statuses/payment types, 2-letter states, 32-char hex IDs, valid coordinates, purchase dates 2016–2018).

Real-world data quality issues to handle in dbt (Sprint 2):

| Rule | Violations | Interpretation | Sprint 2 handling |
|---|---:|---|---|
| ORDERS.delivered_carrier >= purchase | 166 | Carrier date recorded before purchase — timestamp entry error | Don't use carrier date for lead-time metrics, or flag rows |
| GEOLOCATION lat/lng roughly inside Brazil | 42 | Mis-geocoded points | Filter outliers before averaging per zip prefix |
| ORDERS.delivered_customer >= delivered_carrier | 23 | Delivery recorded before carrier pickup | Flag; delivery-delay metric uses purchase → delivered_customer only |
| ORDER_PAYMENTS.payment_value > 0 | 9 | Zero-value payment rows (vouchers / not_defined) | Keep; they don't affect sums |
| ORDERS status=delivered has a delivery date | 8 | "delivered" but no delivery date | Exclude from delivery-time metrics |
| PRODUCTS.product_weight_g > 0 | 4 | Weight recorded as 0 | Treat as null |
| ORDER_PAYMENTS.payment_installments >= 1 | 2 | 0 installments | Treat as 1 |

## 09 Relationship checks — ✅ PASS (0 FAIL · 6 PASS · 5 WARN)
Every order has a customer; every item, payment and review points to a real order; every item points to a real product and seller.

| Check | Rows | Interpretation | Sprint 2 handling |
|---|---:|---|---|
| ORDERS with no ORDER_ITEMS | 775 | Mostly canceled / unavailable orders | Exclude from revenue & purchase counts |
| ORDERS with no ORDER_REVIEWS | 768 | Customer didn't answer the survey | Review score = null, not 0 |
| CUSTOMERS zip prefix not in GEOLOCATION | 278 | Geolocation sample is incomplete | Map shows these as unknown location |
| PRODUCTS category with no English translation | 13 | Translation file misses a couple of categories | Fall back to Portuguese name |
| ORDERS with no ORDER_PAYMENTS | 1 | Single missing payment record | Monetary value from items for this order |

---

## Sprint 1 verdict: ✅ COMPLETE — 0 FAIL across all 5 validation scripts.

