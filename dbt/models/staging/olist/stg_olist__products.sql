-- One row per product. Fixes the source typos ("lenght") and treats 0 weight as unknown.

with source as (

    select * from {{ source('olist', 'products') }}

),

renamed as (

    select
        product_id,
        nullif(trim(product_category_name), '')   as product_category_name_pt,
        product_name_lenght                       as product_name_length,
        product_description_lenght                as product_description_length,
        product_photos_qty                        as product_photo_count,
        nullif(product_weight_g, 0)               as product_weight_g,      -- 4 products had weight 0
        product_length_cm,
        product_height_cm,
        product_width_cm
    from source

)

select * from renamed
