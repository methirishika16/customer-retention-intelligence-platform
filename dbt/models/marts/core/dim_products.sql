-- DIMENSION table: one row per product, with an English category name.

with products as (

    select * from {{ ref('stg_olist__products') }}

),

translation as (

    select * from {{ ref('stg_olist__product_category_translation') }}

)

select
    products.product_id,
    products.product_category_name_pt,
    -- English name; fall back to Portuguese if untranslated, or 'unknown' if no category at all.
    coalesce(
        translation.product_category_name_en,
        products.product_category_name_pt,
        'unknown'
    )                                         as product_category,
    products.product_name_length,
    products.product_description_length,
    products.product_photo_count,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm
from products
left join translation
    on products.product_category_name_pt = translation.product_category_name_pt
