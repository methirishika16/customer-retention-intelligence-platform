-- DIMENSION table: ONE row per real customer (customer_unique_id) who made at least one valid purchase.
-- Everything we know about a customer's buying behaviour in one place.

with valid_orders as (

    select * from {{ ref('int_orders__enriched') }}
    where is_valid_purchase

),

-- "Today" for this dataset = the last purchase date in the data (2018), not the real current date.
as_of as (

    select max(purchase_date) as as_of_date
    from valid_orders

),

-- Where the customer lives, taken from their most recent order.
latest_location as (

    select
        customer_unique_id,
        customer_state,
        customer_city,
        customer_zip_code_prefix
    from valid_orders
    qualify row_number() over (
        partition by customer_unique_id
        order by purchased_at desc, order_id desc
    ) = 1

),

customer_orders as (

    select
        customer_unique_id,
        min(purchase_date)                       as first_purchase_date,
        max(purchase_date)                       as last_purchase_date,
        count(*)                                 as order_count,
        sum(order_revenue)                       as total_revenue,
        sum(item_count)                          as total_items,
        avg(review_score_avg)                    as avg_review_score,
        count_if(is_late_delivery)               as late_delivery_count,
        count_if(delivered_at is not null)       as delivered_order_count
    from valid_orders
    group by customer_unique_id

)

select
    c.customer_unique_id,
    l.customer_state,
    l.customer_city,
    l.customer_zip_code_prefix,

    -- Acquisition
    c.first_purchase_date,
    date_trunc('month', c.first_purchase_date)::date                as acquisition_month,
    c.last_purchase_date,

    -- Frequency
    c.order_count,
    c.order_count >= 2                                               as is_repeat_customer,

    -- Money
    c.total_revenue,
    round(c.total_revenue / c.order_count, 2)                        as avg_order_value,

    -- Basket
    c.total_items,
    round(c.total_items / c.order_count, 2)                          as items_per_order,

    -- Experience
    round(c.avg_review_score, 2)                                     as avg_review_score,
    c.late_delivery_count,
    c.delivered_order_count,

    -- Time
    datediff('day', c.last_purchase_date, a.as_of_date)              as days_since_last_purchase,
    datediff('day', c.first_purchase_date, c.last_purchase_date)     as customer_tenure_days,
    iff(c.order_count >= 2,
        round(datediff('day', c.first_purchase_date, c.last_purchase_date) / (c.order_count - 1), 1),
        null)                                                         as avg_days_between_purchases,
    a.as_of_date

from customer_orders c
inner join latest_location l on c.customer_unique_id = l.customer_unique_id
cross join as_of a
