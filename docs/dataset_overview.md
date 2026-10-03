# Dataset Overview — Olist Brazilian E-Commerce

## Why this dataset

| Requirement for retention analysis | Olist provides it? | Column(s) |
|---|:---:|---|
| A stable ID for the *person* across orders | ✅ | `customers.customer_unique_id` |
| When each purchase happened (Recency) | ✅ | `orders.order_purchase_timestamp` |
| How often someone buys (Frequency) | ✅ | count of orders per `customer_unique_id` |
| How much they spend (Monetary) | ✅ | `order_payments.payment_value`, `order_items.price` |
| Customer experience signals | ✅ | `order_reviews.review_score`, delivered vs. estimated delivery dates |
| What they buy | ✅ | `order_items.product_id` → `products.product_category_name` |
| Where they are | ✅ | `customers.customer_state`, `customer_city` |

Real (anonymised) marketplace data, ~100k orders, **Sept 2016 – Oct 2018**, all money in **Brazilian Reais (BRL)**.
Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce · Licence CC BY-NC-SA 4.0.

**What it does NOT have** (so we will not pretend it does): customer names, emails, age, gender, marketing
campaigns, website sessions, subscriptions, or an explicit "churned" flag. Churn/inactivity must be
*derived* from purchase behaviour.

---

## The 9 files and the columns that matter most

### `olist_customers_dataset.csv` → `RAW.CUSTOMERS`
| Column | Why it matters |
|---|---|
| `customer_id` | ⚠️ **Not the person.** Olist issues a new `customer_id` for *every order*. Use it only to join to `ORDERS`. |
| `customer_unique_id` | ✅ **The real customer.** Group by this for every retention metric. |
| `customer_state`, `customer_city`, `customer_zip_code_prefix` | Regional segmentation. |

### `olist_orders_dataset.csv` → `RAW.ORDERS` — the heart of retention
| Column | Why it matters |
|---|---|
| `order_id` | One row per order. |
| `customer_id` | Links order → customer → `customer_unique_id`. |
| `order_status` | Filter to real purchases (e.g. exclude `canceled`/`unavailable` from revenue). |
| `order_purchase_timestamp` | **Recency & frequency.** First/last purchase, gaps between purchases, cohorts. |
| `order_delivered_customer_date` vs `order_estimated_delivery_date` | **Late delivery** — a likely driver of customers not coming back. |
| `order_approved_at`, `order_delivered_carrier_date` | Fulfilment speed. Null when the order never reached that step. |

### `olist_order_items_dataset.csv` → `RAW.ORDER_ITEMS`
| Column | Why it matters |
|---|---|
| `order_id` + `order_item_id` | One row per item in an order (item 1, 2, 3…). |
| `price`, `freight_value` | Product revenue and shipping cost per item. |
| `product_id`, `seller_id` | What was bought and from whom. |

### `olist_order_payments_dataset.csv` → `RAW.ORDER_PAYMENTS`
| Column | Why it matters |
|---|---|
| `payment_value` | **Monetary value** — what the customer actually paid. Sum per order (an order can have several rows). |
| `payment_type` | `credit_card`, `boleto` (bank slip), `voucher`, `debit_card`, `not_defined`. |
| `payment_installments` | Spreading payments is common in Brazil; may relate to basket size. |

### `olist_order_reviews_dataset.csv` → `RAW.ORDER_REVIEWS`
| Column | Why it matters |
|---|---|
| `review_score` | 1–5 satisfaction. Low scores are an early churn-risk signal. |
| `review_comment_message` | Free text in Portuguese, mostly empty. Out of scope for now. |

### `olist_products_dataset.csv` → `RAW.PRODUCTS`
`product_category_name` (Portuguese) for category preferences. Physical attributes
(`product_weight_g`, dimensions, `product_photos_qty`) are less important for retention.

### `product_category_name_translation.csv` → `RAW.PRODUCT_CATEGORY_TRANSLATION`
Portuguese → English category names for dashboards.

### `olist_sellers_dataset.csv` → `RAW.SELLERS`
Seller location. Secondary for customer retention; kept because order items reference it.

### `olist_geolocation_dataset.csv` → `RAW.GEOLOCATION`
Lat/long per zip prefix, for maps in Tableau. ~1M rows, **many rows per zip prefix**. Must be aggregated
(e.g. average lat/lng per prefix) before joining, or it will multiply rows.

---

## Known quirks (document, don't "fix" in RAW)

1. **`customer_id` ≠ customer.** Use `customer_unique_id`. This is the #1 mistake people make with this dataset.
2. **Most customers buy only once.** Repeat purchasers are a small minority, so "retention" here is
   mostly about the *second* purchase. That is a realistic and interesting finding. Measure it in Sprint 2.
3. **Typos in source column names.** `product_name_lenght`, `product_description_lenght`. Kept in RAW,
   renamed in dbt staging.
4. **Zip codes are 5-digit prefixes**, stored as text so leading zeros are not lost.
5. **`review_id` is not unique on its own.** Some review IDs appear on several orders, and some orders have
   several reviews. RAW grain = (`review_id`, `order_id`).
6. **Multiple payments per order.** Always `SUM(payment_value)` by `order_id`.
7. **Freight is per item**, split across items when an order has several.
8. **Nulls with meaning.** Delivery dates are null for orders that were never delivered. Some products have no category.
9. **A few categories have no English translation.** `09_relationship_checks.sql` lists them.
10. **Thin months at the edges.** Very few orders in late 2016 and at the very end of 2018. This affects the
    "as-of date" used to measure recency.

Run `python python/inspect_dataset.py` to generate `docs/dataset_profile.md` with exact counts from your copy.
