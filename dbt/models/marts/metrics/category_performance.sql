-- ONE row per product category (English): sales, customers, prices and satisfaction.
--
-- Category revenue uses ITEM PRICES (+ freight separately). Payments are recorded per
-- order, not per item, so they cannot be split by category.
-- Review scores are per order: an order with items from 2 categories counts for both.

with items as (

    select * from {{ ref('stg_olist__order_items') }}

),

orders as (

    select order_id, customer_unique_id, review_score_avg
    from {{ ref('fct_orders') }}
    where is_valid_purchase

),

products as (

    select product_id, product_category
    from {{ ref('dim_products') }}

),

item_detail as (

    select
        products.product_category,
        items.order_id,
        items.product_id,
        orders.customer_unique_id,
        items.item_price,
        items.freight_value
    from items
    inner join orders   on items.order_id = orders.order_id
    inner join products on items.product_id = products.product_id

),

category_sales as (

    select
        product_category,
        count(*)                              as items_sold,
        count(distinct order_id)              as orders,
        count(distinct customer_unique_id)    as unique_customers,
        count(distinct product_id)            as products_sold,
        sum(item_price)                       as item_revenue,
        sum(freight_value)                    as freight_revenue,
        avg(item_price)                       as avg_item_price
    from item_detail
    group by product_category

),

category_reviews as (

    select
        category_orders.product_category,
        avg(orders.review_score_avg)          as avg_review_score
    from (select distinct product_category, order_id from item_detail) as category_orders
    inner join orders on category_orders.order_id = orders.order_id
    group by category_orders.product_category

)

select
    s.product_category,
    s.items_sold,
    s.orders,
    s.unique_customers,
    s.products_sold,
    s.item_revenue,
    s.freight_revenue,
    round(s.avg_item_price, 2)                                         as avg_item_price,
    round(s.item_revenue / sum(s.item_revenue) over (), 4)             as item_revenue_share,
    rank() over (order by s.item_revenue desc)                         as revenue_rank,
    round(r.avg_review_score, 2)                                       as avg_review_score
from category_sales s
left join category_reviews r on s.product_category = r.product_category
