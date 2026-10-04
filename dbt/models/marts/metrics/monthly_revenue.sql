-- ONE row per month: revenue, orders, customers, AOV, items per order,
-- and the split between NEW customers (first purchase this month) and RETURNING
-- customers (first purchase in an earlier month).

with orders as (

    select * from {{ ref('fct_orders') }}
    where is_valid_purchase

),

customers as (

    select customer_unique_id, acquisition_month
    from {{ ref('dim_customers') }}

),

orders_labelled as (

    select
        orders.*,
        iff(customers.acquisition_month = orders.purchase_month, 'new', 'returning')  as customer_type
    from orders
    inner join customers on orders.customer_unique_id = customers.customer_unique_id

),

monthly as (

    select
        purchase_month,
        count(*)                                                                      as orders,
        count(distinct customer_unique_id)                                            as unique_customers,
        sum(order_revenue)                                                            as revenue,
        sum(item_count)                                                               as items,
        count(distinct iff(customer_type = 'new', customer_unique_id, null))          as new_customers,
        count(distinct iff(customer_type = 'returning', customer_unique_id, null))    as returning_customers,
        sum(iff(customer_type = 'new', order_revenue, 0))                             as new_customer_revenue,
        sum(iff(customer_type = 'returning', order_revenue, 0))                       as returning_customer_revenue
    from orders_labelled
    group by purchase_month

)

select
    purchase_month,
    orders,
    unique_customers,
    revenue,
    round(revenue / orders, 2)                                       as avg_order_value,
    round(items / orders, 2)                                         as items_per_order,
    new_customers,
    returning_customers,
    new_customer_revenue,
    returning_customer_revenue,
    round(returning_customers / unique_customers, 4)                 as returning_customer_share,
    sum(revenue) over (order by purchase_month)                      as cumulative_revenue,
    -- The first months (late 2016) and the last ones (Sep-Oct 2018) have very few orders;
    -- don't read trends from them.
    orders < 100                                                     as is_low_volume_month
from monthly
