-- The complete picture of each order, ONE row per order:
-- who bought it (the real customer), what it cost, how delivery went, how it was reviewed,
-- and whether it was the customer's 1st, 2nd, 3rd... purchase.

with orders as (

    select * from {{ ref('stg_olist__orders') }}

),

customers as (

    select * from {{ ref('stg_olist__customers') }}

),

items as (

    select * from {{ ref('int_order_items__per_order') }}

),

payments as (

    select * from {{ ref('int_order_payments__per_order') }}

),

reviews as (

    select * from {{ ref('int_order_reviews__per_order') }}

),

joined as (

    select
        orders.order_id,
        orders.customer_id,
        customers.customer_unique_id,
        customers.customer_state,
        customers.customer_city,
        customers.customer_zip_code_prefix,

        orders.order_status,
        orders.is_valid_purchase,
        orders.purchased_at,
        orders.purchase_date,
        orders.purchase_month,
        orders.approved_at,
        orders.shipped_to_carrier_at,
        orders.delivered_at,
        orders.estimated_delivery_at,
        orders.has_date_quality_issue,

        coalesce(items.item_count, 0)              as item_count,
        coalesce(items.distinct_product_count, 0)  as distinct_product_count,
        coalesce(items.items_subtotal, 0)          as items_subtotal,
        coalesce(items.freight_total, 0)           as freight_total,

        payments.payment_total,
        payments.payment_count,
        payments.main_payment_type,
        payments.max_installments,

        -- REVENUE = what the customer paid (products + freight).
        -- One order has no payment record; for it we fall back to items + freight.
        coalesce(payments.payment_total, items.items_gross_total, 0)  as order_revenue,

        reviews.review_score_avg,
        reviews.review_score_min,
        coalesce(reviews.review_count, 0)          as review_count,

        -- Delivery performance (only for delivered orders)
        datediff('day', orders.purchased_at, orders.delivered_at)    as delivery_days,
        iff(orders.delivered_at is null, null,
            orders.delivered_at::date > orders.estimated_delivery_at::date)  as is_late_delivery,
        iff(orders.delivered_at is null, null,
            greatest(datediff('day', orders.estimated_delivery_at::date, orders.delivered_at::date), 0))  as days_late

    from orders
    inner join customers on orders.customer_id = customers.customer_id
    left join items      on orders.order_id = items.order_id
    left join payments   on orders.order_id = payments.order_id
    left join reviews    on orders.order_id = reviews.order_id

),

sequenced as (

    select
        *,
        -- 1 = the customer's first valid purchase, 2 = second, ...  (NULL for canceled/unavailable)
        iff(
            is_valid_purchase,
            row_number() over (
                partition by customer_unique_id, is_valid_purchase
                order by purchased_at, order_id
            ),
            null
        ) as customer_order_number
    from joined

)

select
    *,
    coalesce(customer_order_number = 1, false)  as is_first_purchase
from sequenced
