-- Cohort retention grid: ONE row per (acquisition month, months since acquisition).
--
-- A cohort = all customers whose FIRST valid purchase was in the same month.
-- retention_rate = share of the cohort that made a purchase N months later.
-- Month 0 is always 100% (that's when they were acquired).
--
-- Every cohort/month combination is present (0 when nobody bought), so Tableau's
-- heatmap has no gaps. Months after the last full month of data are excluded.

with valid_orders as (

    select customer_unique_id, purchase_month
    from {{ ref('fct_orders') }}
    where is_valid_purchase

),

customers as (

    select customer_unique_id, acquisition_month
    from {{ ref('dim_customers') }}

),

-- Last month with enough orders to trust (Sep 2018 has a single order)
last_full_month as (

    select max(purchase_month) as last_month
    from {{ ref('monthly_revenue') }}
    where not is_low_volume_month

),

cohort_sizes as (

    select acquisition_month, count(*) as cohort_customers
    from customers
    group by acquisition_month

),

customer_activity as (

    select distinct
        customers.acquisition_month,
        valid_orders.customer_unique_id,
        datediff('month', customers.acquisition_month, valid_orders.purchase_month) as months_since_acquisition
    from valid_orders
    inner join customers on valid_orders.customer_unique_id = customers.customer_unique_id

),

active_counts as (

    select acquisition_month, months_since_acquisition, count(*) as active_customers
    from customer_activity
    group by acquisition_month, months_since_acquisition

),

month_offsets as (

    select seq4() as months_since_acquisition
    from table(generator(rowcount => 25))

),

grid as (

    select
        cohort_sizes.acquisition_month,
        cohort_sizes.cohort_customers,
        month_offsets.months_since_acquisition
    from cohort_sizes
    cross join month_offsets
    cross join last_full_month
    where dateadd('month', month_offsets.months_since_acquisition, cohort_sizes.acquisition_month)
          <= last_full_month.last_month

)

select
    to_char(grid.acquisition_month, 'YYYY-MM') || '+' || grid.months_since_acquisition  as cohort_key,
    grid.acquisition_month,
    grid.months_since_acquisition,
    grid.cohort_customers,
    coalesce(active_counts.active_customers, 0)                                         as active_customers,
    round(coalesce(active_counts.active_customers, 0) / grid.cohort_customers, 5)       as retention_rate,
    grid.cohort_customers < 100                                                          as is_small_cohort
from grid
left join active_counts
    on  grid.acquisition_month = active_counts.acquisition_month
    and grid.months_since_acquisition = active_counts.months_since_acquisition
