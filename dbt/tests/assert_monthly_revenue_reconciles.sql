-- The months must add up to the overall KPIs, and new + returning must equal all customers each month.

with months as (
    select sum(revenue) as revenue, sum(orders) as orders
    from {{ ref('monthly_revenue') }}
),

kpis as (
    select total_revenue, total_orders
    from {{ ref('kpi_summary') }}
),

totals_mismatch as (
    select 'monthly totals do not match kpi_summary' as problem
    from months cross join kpis
    where abs(months.revenue - kpis.total_revenue) > 0.01
       or months.orders <> kpis.total_orders
),

split_mismatch as (
    select 'new + returning <> unique customers in ' || purchase_month as problem
    from {{ ref('monthly_revenue') }}
    where new_customers + returning_customers <> unique_customers
)

select * from totals_mismatch
union all
select * from split_mismatch
