-- One row per payment method used on an order.

with source as (

    select * from {{ source('olist', 'order_payments') }}

),

renamed as (

    select
        order_id || '-' || payment_sequential          as order_payment_key,
        order_id,
        payment_sequential                             as payment_sequence,
        lower(trim(payment_type))                      as payment_type,
        -- 2 rows have 0 installments; a payment is always at least 1 installment.
        greatest(coalesce(payment_installments, 1), 1) as payment_installments,
        payment_value::number(10, 2)                   as payment_value
    from source

)

select * from renamed
