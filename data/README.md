# Data

Raw files are **not** committed to Git (see `.gitignore`). Download them yourself.

## Source

**Brazilian E-Commerce Public Dataset by Olist** — https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
Licence: CC BY-NC-SA 4.0 (non-commercial, attribution required — fine for a portfolio project).

## How to get it

1. Sign in to Kaggle and click **Download** on the dataset page (≈ 45 MB zip).
2. Unzip it and put these **9 CSV files** directly in `data/raw/`:

| File | Loads into Snowflake table |
|---|---|
| `olist_customers_dataset.csv` | `RAW.CUSTOMERS` |
| `olist_orders_dataset.csv` | `RAW.ORDERS` |
| `olist_order_items_dataset.csv` | `RAW.ORDER_ITEMS` |
| `olist_order_payments_dataset.csv` | `RAW.ORDER_PAYMENTS` |
| `olist_order_reviews_dataset.csv` | `RAW.ORDER_REVIEWS` |
| `olist_products_dataset.csv` | `RAW.PRODUCTS` |
| `olist_sellers_dataset.csv` | `RAW.SELLERS` |
| `olist_geolocation_dataset.csv` | `RAW.GEOLOCATION` |
| `product_category_name_translation.csv` | `RAW.PRODUCT_CATEGORY_TRANSLATION` |

3. Run `python python/inspect_dataset.py` to confirm every file and column is present.
