-- ONE row per customer: everything in dim_customers PLUS
--   RFM scores, an RFM segment, a high-value flag, an activity status and a retention priority.
--
-- RFM in plain words:
--   R (Recency)   = how recently did they buy?      fewer days since last purchase -> higher score
--   F (Frequency) = how many orders did they place?  more orders -> higher score
--   M (Monetary)  = how much did they spend?         more money  -> higher score
-- Each score is 1 (worst) to 5 (best).

with customers as (

    select * from {{ ref('dim_customers') }}

),

scored as (

    select
        *,

        -- R and M: quintiles (each score covers ~20% of customers).
        -- PERCENT_RANK keeps customers with identical values in the same score.
        least(5, floor(percent_rank() over (order by days_since_last_purchase desc) * 5) + 1)::int  as r_score,
        least(5, floor(percent_rank() over (order by total_revenue asc) * 5) + 1)::int              as m_score,

        -- F: fixed buckets, NOT quintiles. About 97% of customers ordered exactly once,
        -- so quintiles would give equal customers different scores.
        case
            when order_count >= 5 then 5
            when order_count = 4  then 4
            when order_count = 3  then 3
            when order_count = 2  then 2
            else 1
        end                                                                                          as f_score

    from customers

),

segmented as (

    select
        *,
        r_score::varchar || f_score::varchar || m_score::varchar      as rfm_cell,
        r_score + f_score + m_score                                    as rfm_total_score,

        -- Segments are checked top to bottom; the first match wins.
        case
            when f_score >= 2 and r_score >= 4 and m_score >= 4 then 'Champions'
            when f_score >= 2 and r_score >= 3                  then 'Loyal Customers'
            when f_score >= 2                                   then 'At-Risk Repeat Customers'
            when m_score = 5  and r_score >= 3                  then 'High-Value Recent'      -- one-time, top-20% spend
            when m_score = 5                                    then 'High-Value Lapsing'     -- one-time, top-20% spend, gone quiet
            when r_score >= 4                                   then 'Recent One-Time Buyers'
            when r_score = 3                                    then 'Needs Attention'
            when r_score = 2                                    then 'Hibernating'
            else                                                     'Lost'
        end                                                            as rfm_segment,

        -- High value = top 20% spenders, or repeat buyers in the top 40% of spend.
        (m_score = 5 or (f_score >= 2 and m_score >= 4))               as is_high_value,

        case
            when days_since_last_purchase <= {{ var('active_days') }}   then 'Active'
            when days_since_last_purchase <= {{ var('inactive_days') }} then 'Cooling'
            else                                                             'Inactive'
        end                                                            as activity_status

    from scored

)

select
    *,
    -- Rule-based v1 of "who should we prioritise?" (refined with Python in Sprint 3).
    case
        when is_high_value and activity_status = 'Cooling'                          then 1  -- valuable & slipping away
        when is_high_value and activity_status = 'Inactive'                         then 2  -- valuable but already gone quiet
        when is_repeat_customer and activity_status in ('Cooling', 'Inactive')      then 2  -- proven repeat buyers going quiet
        when is_high_value and activity_status = 'Active'                           then 3  -- nurture
        else                                                                             4  -- standard / low priority
    end                                                                as retention_priority
from segmented
