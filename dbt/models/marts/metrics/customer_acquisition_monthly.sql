-- ONE row per acquisition month (the month of a customer's FIRST purchase):
-- how many customers were acquired, how many of them later bought again,
-- and how much they have spent so far.
--
-- Caution: newer cohorts have had less time to come back, so their repeat rate
-- is naturally lower. Compare cohorts using months_observed.

with customers as (

    select * from {{ ref('dim_customers') }}

)

select
    acquisition_month,
    count(*)                                                       as new_customers,
    count_if(is_repeat_customer)                                   as customers_who_returned,
    round(count_if(is_repeat_customer) / count(*), 4)              as cohort_repeat_rate,
    sum(total_revenue)                                             as cohort_revenue_to_date,
    round(avg(total_revenue), 2)                                   as avg_revenue_per_customer,
    datediff('month', acquisition_month, max(as_of_date))          as months_observed
from customers
group by acquisition_month
