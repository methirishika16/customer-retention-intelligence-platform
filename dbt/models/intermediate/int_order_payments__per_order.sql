-- Rolls payment rows up to ONE row per order: what the customer actually paid.

with payments as (

    select * from {{ ref('stg_olist__order_payments') }}

)

select
    order_id,
    sum(payment_value)                         as payment_total,
    count(*)                                   as payment_count,
    max(payment_installments)                  as max_installments,
    max_by(payment_type, payment_value)        as main_payment_type   -- method that covered the most money
from payments
group by order_id
