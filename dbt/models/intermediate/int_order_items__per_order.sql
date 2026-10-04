-- Rolls item rows up to ONE row per order: how many items, and what they cost.

with items as (

    select * from {{ ref('stg_olist__order_items') }}

)

select
    order_id,
    count(*)                              as item_count,
    count(distinct product_id)            as distinct_product_count,
    count(distinct seller_id)             as seller_count,
    sum(item_price)                       as items_subtotal,       -- products only
    sum(freight_value)                    as freight_total,        -- shipping only
    sum(item_price + freight_value)       as items_gross_total     -- products + shipping
from items
group by order_id
