-- One row per order-level customer_id.
-- Remember: customer_id changes with every order; customer_unique_id is the real person.

with source as (

    select * from {{ source('olist', 'customers') }}

),

renamed as (

    select
        customer_id,
        customer_unique_id,
        lpad(trim(customer_zip_code_prefix), 5, '0')  as customer_zip_code_prefix,
        lower(trim(customer_city))                    as customer_city,
        upper(trim(customer_state))                   as customer_state
    from source

)

select * from renamed
