-- Portuguese -> English product category names.

with source as (

    select * from {{ source('olist', 'product_category_translation') }}

),

renamed as (

    select
        trim(product_category_name)           as product_category_name_pt,
        trim(product_category_name_english)   as product_category_name_en
    from source

)

select * from renamed
