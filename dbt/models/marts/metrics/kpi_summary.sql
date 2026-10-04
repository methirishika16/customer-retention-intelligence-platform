-- ONE row with the headline business KPIs for the whole dataset (valid purchases only).

with orders as (

    select * from {{ ref('fct_orders') }}
    where is_valid_purchase

),

customers as (

    select * from {{ ref('dim_customers') }}

),

order_kpis as (

    select
        min(purchase_date)                    as first_purchase_date,
        max(purchase_date)                    as last_purchase_date,
        count(*)                              as total_orders,
        count(distinct customer_unique_id)    as unique_customers,
        sum(order_revenue)                    as total_revenue,
        sum(item_count)                       as total_items
    from orders

),

customer_kpis as (

    select
        count_if(is_repeat_customer)                 as repeat_customers,
        avg(order_count)                             as avg_orders_per_customer,
        avg(total_revenue)                           as avg_revenue_per_customer,
        median(days_since_last_purchase)             as median_days_since_last_purchase,
        median(avg_days_between_purchases)           as median_days_between_purchases_repeaters
    from customers

)

select
    o.first_purchase_date,
    o.last_purchase_date,
    o.total_revenue,
    o.total_orders,
    o.unique_customers,
    round(o.total_revenue / o.total_orders, 2)                   as avg_order_value,
    round(o.total_items / o.total_orders, 2)                     as items_per_order,
    c.repeat_customers,
    round(c.repeat_customers / o.unique_customers, 4)            as repeat_purchase_rate,
    round(c.avg_orders_per_customer, 3)                          as avg_orders_per_customer,   -- purchase frequency
    round(c.avg_revenue_per_customer, 2)                         as avg_revenue_per_customer,
    c.median_days_since_last_purchase,
    c.median_days_between_purchases_repeaters
from order_kpis o
cross join customer_kpis c
