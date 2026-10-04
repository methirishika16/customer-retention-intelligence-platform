-- One row per item in an order.

with source as (

    select * from {{ source('olist', 'order_items') }}

),

renamed as (

    select
        order_id || '-' || order_item_id      as order_item_key,      -- single-column unique key
        order_id,
        order_item_id                         as order_item_number,   -- 1, 2, 3... within the order
        product_id,
        seller_id,
        shipping_limit_date                   as shipping_limit_at,
        price::number(10, 2)                  as item_price,
        freight_value::number(10, 2)          as freight_value
    from source

)

select * from renamed
