-- customer_rfm must have exactly one row for every customer in dim_customers.

with counts as (
    select
        (select count(*) from {{ ref('dim_customers') }}) as customers,
        (select count(*) from {{ ref('customer_rfm') }})  as rfm_rows
)

select * from counts
where customers <> rfm_rows
