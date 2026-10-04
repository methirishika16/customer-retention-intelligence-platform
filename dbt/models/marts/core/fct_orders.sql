-- FACT table: one row per order (all statuses).
-- Filter on is_valid_purchase = TRUE for revenue and customer metrics.

select
    order_id,
    customer_unique_id,
    customer_id,
    customer_state,
    order_status,
    is_valid_purchase,
    customer_order_number,
    is_first_purchase,

    purchased_at,
    purchase_date,
    purchase_month,
    approved_at,
    shipped_to_carrier_at,
    delivered_at,
    estimated_delivery_at,
    has_date_quality_issue,

    item_count,
    distinct_product_count,
    items_subtotal,
    freight_total,
    payment_total,
    order_revenue,
    main_payment_type,
    max_installments,

    review_score_avg,
    review_count,
    delivery_days,
    is_late_delivery,
    days_late

from {{ ref('int_orders__enriched') }}
