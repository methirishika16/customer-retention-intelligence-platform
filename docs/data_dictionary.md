# Data Dictionary — `CRI_DB.RAW`

All columns come directly from the Olist CSV files; none are invented or derived.
Money is in BRL. Timestamps are `TIMESTAMP_NTZ` (no time zone in source; local Brazil time).

**Key:** PK = primary key (informational in Snowflake, tested in `07_duplicate_checks.sql`) ·
FK = foreign key (tested in `09_relationship_checks.sql`) · **Req** = must never be null (tested in `06_null_checks.sql`)

---

## CUSTOMERS
Source `olist_customers_dataset.csv` · Grain: one row per order-level customer ID (= one per order) · Expected rows: 99,441

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `customer_id` | VARCHAR | PK | ✅ | Customer key issued **per order**. Joins to `ORDERS.customer_id`. |
| `customer_unique_id` | VARCHAR | | ✅ | Identifier of the actual customer (person). Repeats across that person's orders. |
| `customer_zip_code_prefix` | VARCHAR | | | First 5 digits of the customer's zip code. |
| `customer_city` | VARCHAR | | | Customer city (lower-case Portuguese). |
| `customer_state` | VARCHAR | | | Customer state, 2-letter code (e.g. `SP`, `RJ`). |

## ORDERS
Source `olist_orders_dataset.csv` · Grain: one row per order · Expected rows: 99,441

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `order_id` | VARCHAR | PK | ✅ | Unique order identifier. |
| `customer_id` | VARCHAR | FK → CUSTOMERS | ✅ | Order-level customer key. |
| `order_status` | VARCHAR | | ✅ | `delivered`, `shipped`, `canceled`, `unavailable`, `invoiced`, `processing`, `created`, `approved`. |
| `order_purchase_timestamp` | TIMESTAMP_NTZ | | ✅ | When the customer placed the order. |
| `order_approved_at` | TIMESTAMP_NTZ | | | When payment was approved. Null if never approved. |
| `order_delivered_carrier_date` | TIMESTAMP_NTZ | | | When the order was handed to the logistics partner. |
| `order_delivered_customer_date` | TIMESTAMP_NTZ | | | When the customer received the order. Null if not delivered. |
| `order_estimated_delivery_date` | TIMESTAMP_NTZ | | | Delivery date promised to the customer at purchase. |

## ORDER_ITEMS
Source `olist_order_items_dataset.csv` · Grain: one row per item within an order · Expected rows: 112,650

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `order_id` | VARCHAR | PK, FK → ORDERS | ✅ | Order the item belongs to. |
| `order_item_id` | INTEGER | PK | ✅ | Sequential item number within the order (1, 2, 3…). |
| `product_id` | VARCHAR | FK → PRODUCTS | ✅ | Product purchased. |
| `seller_id` | VARCHAR | FK → SELLERS | ✅ | Seller who fulfilled the item. |
| `shipping_limit_date` | TIMESTAMP_NTZ | | | Deadline for the seller to hand the item to the carrier. |
| `price` | NUMBER(10,2) | | ✅ | Item price. |
| `freight_value` | NUMBER(10,2) | | | Freight for this item (split across items when an order has several). |

## ORDER_PAYMENTS
Source `olist_order_payments_dataset.csv` · Grain: one row per payment method used on an order · Expected rows: 103,886

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `order_id` | VARCHAR | PK, FK → ORDERS | ✅ | Order paid. |
| `payment_sequential` | INTEGER | PK | ✅ | Sequence number when more than one payment method is used. |
| `payment_type` | VARCHAR | | ✅ | `credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined`. |
| `payment_installments` | INTEGER | | | Number of installments chosen. |
| `payment_value` | NUMBER(10,2) | | ✅ | Amount paid in this payment row. |

## ORDER_REVIEWS
Source `olist_order_reviews_dataset.csv` · Grain: one row per (review, order) · Expected rows: 99,224

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `review_id` | VARCHAR | PK | ✅ | Review identifier. **Not unique alone** (source quirk). |
| `order_id` | VARCHAR | PK, FK → ORDERS | ✅ | Order reviewed. |
| `review_score` | INTEGER | | ✅ | Satisfaction score from 1 (worst) to 5 (best). |
| `review_comment_title` | VARCHAR | | | Review title in Portuguese. Mostly null. |
| `review_comment_message` | VARCHAR | | | Review text in Portuguese. Mostly null. |
| `review_creation_date` | TIMESTAMP_NTZ | | | When the satisfaction survey was sent to the customer. |
| `review_answer_timestamp` | TIMESTAMP_NTZ | | | When the customer answered the survey. |

## PRODUCTS
Source `olist_products_dataset.csv` · Grain: one row per product · Expected rows: 32,951

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `product_id` | VARCHAR | PK | ✅ | Unique product identifier. |
| `product_category_name` | VARCHAR | FK → TRANSLATION | | Category in Portuguese. Null for some products. |
| `product_name_lenght` | INTEGER | | | Number of characters in the product name. *(source spelling)* |
| `product_description_lenght` | INTEGER | | | Number of characters in the product description. *(source spelling)* |
| `product_photos_qty` | INTEGER | | | Number of product photos published. |
| `product_weight_g` | INTEGER | | | Weight in grams. |
| `product_length_cm` | INTEGER | | | Length in centimetres. |
| `product_height_cm` | INTEGER | | | Height in centimetres. |
| `product_width_cm` | INTEGER | | | Width in centimetres. |

## SELLERS
Source `olist_sellers_dataset.csv` · Grain: one row per seller · Expected rows: 3,095

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `seller_id` | VARCHAR | PK | ✅ | Unique seller identifier. |
| `seller_zip_code_prefix` | VARCHAR | | | First 5 digits of the seller's zip code. |
| `seller_city` | VARCHAR | | | Seller city. |
| `seller_state` | VARCHAR | | | Seller state, 2-letter code. |

## GEOLOCATION
Source `olist_geolocation_dataset.csv` · Grain: **no unique key**, many rows per zip prefix · Expected rows: 1,000,163

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `geolocation_zip_code_prefix` | VARCHAR | | ✅ | First 5 digits of a zip code. Joins to customer/seller zip prefixes. |
| `geolocation_lat` | FLOAT | | | Latitude. |
| `geolocation_lng` | FLOAT | | | Longitude. |
| `geolocation_city` | VARCHAR | | | City name. |
| `geolocation_state` | VARCHAR | | | State, 2-letter code. |

## PRODUCT_CATEGORY_TRANSLATION
Source `product_category_name_translation.csv` · Grain: one row per category · Expected rows: 71

| Column | Type | Key | Req | Description |
|---|---|---|:---:|---|
| `product_category_name` | VARCHAR | PK | ✅ | Category name in Portuguese. |
| `product_category_name_english` | VARCHAR | | ✅ | Category name in English. |

---

## Validation results (fill in after running Sprint 1)

| Check | Script | Result | Notes |
|---|---|---|---|
| Row counts | `05_row_count_validation.sql` | ✅ PASS | |
| Required columns not null | `06_null_checks.sql` | ✅ PASS | 13 INFO — see validation_results.md |
| Primary keys unique | `07_duplicate_checks.sql` | ✅ PASS | |
| Schema & value domains | `08_data_type_validation.sql` | ✅ PASS | 7 WARN — see validation_results.md |
| Relationships | `09_relationship_checks.sql` | ✅ PASS | 5 WARN — see validation_results.md |
