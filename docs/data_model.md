# Data Model — RAW layer

Built only from columns that exist in the source files. Keys are tested, not enforced
(Snowflake treats PK/FK as informational).

```mermaid
erDiagram
    CUSTOMERS ||--|| ORDERS : "customer_id (one per order)"
    ORDERS ||--o{ ORDER_ITEMS : "order_id"
    ORDERS ||--o{ ORDER_PAYMENTS : "order_id"
    ORDERS ||--o{ ORDER_REVIEWS : "order_id"
    PRODUCTS ||--o{ ORDER_ITEMS : "product_id"
    SELLERS ||--o{ ORDER_ITEMS : "seller_id"
    PRODUCT_CATEGORY_TRANSLATION |o--o{ PRODUCTS : "product_category_name"
    GEOLOCATION }o..o{ CUSTOMERS : "zip_code_prefix (many-to-many)"
    GEOLOCATION }o..o{ SELLERS : "zip_code_prefix (many-to-many)"

    CUSTOMERS {
        varchar customer_id PK
        varchar customer_unique_id "the real person"
        varchar customer_zip_code_prefix
        varchar customer_city
        varchar customer_state
    }
    ORDERS {
        varchar order_id PK
        varchar customer_id FK
        varchar order_status
        timestamp order_purchase_timestamp
        timestamp order_approved_at
        timestamp order_delivered_carrier_date
        timestamp order_delivered_customer_date
        timestamp order_estimated_delivery_date
    }
    ORDER_ITEMS {
        varchar order_id PK,FK
        int order_item_id PK
        varchar product_id FK
        varchar seller_id FK
        timestamp shipping_limit_date
        number price
        number freight_value
    }
    ORDER_PAYMENTS {
        varchar order_id PK,FK
        int payment_sequential PK
        varchar payment_type
        int payment_installments
        number payment_value
    }
    ORDER_REVIEWS {
        varchar review_id PK
        varchar order_id PK,FK
        int review_score
        varchar review_comment_title
        varchar review_comment_message
        timestamp review_creation_date
        timestamp review_answer_timestamp
    }
    PRODUCTS {
        varchar product_id PK
        varchar product_category_name FK
        int product_name_lenght
        int product_description_lenght
        int product_photos_qty
        int product_weight_g
        int product_length_cm
        int product_height_cm
        int product_width_cm
    }
    SELLERS {
        varchar seller_id PK
        varchar seller_zip_code_prefix
        varchar seller_city
        varchar seller_state
    }
    GEOLOCATION {
        varchar geolocation_zip_code_prefix
        float geolocation_lat
        float geolocation_lng
        varchar geolocation_city
        varchar geolocation_state
    }
    PRODUCT_CATEGORY_TRANSLATION {
        varchar product_category_name PK
        varchar product_category_name_english
    }
```

## How to read it for retention

```
customer_unique_id (person)
   └── customer_id  (one per order)
          └── ORDERS ── ORDER_ITEMS ── PRODUCTS ── CATEGORY_TRANSLATION
                 ├──── ORDER_PAYMENTS   (monetary)
                 └──── ORDER_REVIEWS    (satisfaction)
```

To get "all orders for one customer" you always go
`CUSTOMERS.customer_unique_id → CUSTOMERS.customer_id → ORDERS.customer_id`.

## Table grains

| Table | One row per… | Key |
|---|---|---|
| CUSTOMERS | order-level customer ID | `customer_id` |
| ORDERS | order | `order_id` |
| ORDER_ITEMS | item in an order | `order_id, order_item_id` |
| ORDER_PAYMENTS | payment method used on an order | `order_id, payment_sequential` |
| ORDER_REVIEWS | review–order pair | `review_id, order_id` |
| PRODUCTS | product | `product_id` |
| SELLERS | seller | `seller_id` |
| GEOLOCATION | zip-prefix sample point (not unique) | — |
| PRODUCT_CATEGORY_TRANSLATION | category | `product_category_name` |

## Why no "dimension / fact" star schema yet?
Sprint 1 is the **RAW** layer: a faithful copy of the source. The customer-level star schema
(e.g. `dim_customers`, `fct_orders`) is built in dbt in Sprint 2, on top of these tables.
