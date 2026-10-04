-- One row per order: clearer names, clean dates, a few simple flags.

with source as (

    select * from {{ source('olist', 'orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        lower(trim(order_status))        as order_status,
        order_purchase_timestamp         as purchased_at,
        order_approved_at                as approved_at,
        order_delivered_carrier_date     as shipped_to_carrier_at_raw,
        order_delivered_customer_date    as delivered_at_raw,
        order_estimated_delivery_date    as estimated_delivery_at
    from source

),

cleaned as (

    select
        order_id,
        customer_id,
        order_status,

        purchased_at,
        approved_at,
        -- Sprint 1 found carrier/delivery dates earlier than the purchase itself.
        -- That is impossible, so the bad value becomes NULL (unknown) instead of a wrong number.
        iff(shipped_to_carrier_at_raw < purchased_at, null, shipped_to_carrier_at_raw) as shipped_to_carrier_at,
        iff(delivered_at_raw < purchased_at, null, delivered_at_raw)                   as delivered_at,
        estimated_delivery_at,

        -- TRUE if any date in the order looked wrong in the source (kept for transparency).
        (
            coalesce(shipped_to_carrier_at_raw < purchased_at, false)
            or coalesce(delivered_at_raw < purchased_at, false)
            or coalesce(delivered_at_raw < shipped_to_carrier_at_raw, false)
            or (order_status = 'delivered' and delivered_at_raw is null)
        )                                                    as has_date_quality_issue,

        -- Handy date parts for grouping
        purchased_at::date                                   as purchase_date,
        date_trunc('month', purchased_at)::date              as purchase_month,

        -- A real purchase = anything that was not canceled or unavailable.
        order_status not in ('canceled', 'unavailable')      as is_valid_purchase

    from renamed

)

select * from cleaned
