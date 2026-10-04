-- Revenue must be the same whether summed by order or by customer.
-- Fails if dim_customers lost or double-counted any orders.

with by_order as (
    select sum(order_revenue) as revenue, count(*) as orders
    from {{ ref('fct_orders') }}
    where is_valid_purchase
),

by_customer as (
    select sum(total_revenue) as revenue, sum(order_count) as orders
    from {{ ref('dim_customers') }}
)

select *
from by_order
cross join by_customer
where abs(by_order.revenue - by_customer.revenue) > 0.01
   or by_order.orders <> by_customer.orders
