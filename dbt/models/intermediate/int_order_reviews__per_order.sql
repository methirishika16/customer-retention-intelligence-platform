-- Rolls review rows up to ONE row per order (a few orders have more than one review).

with reviews as (

    select * from {{ ref('stg_olist__order_reviews') }}

)

select
    order_id,
    avg(review_score)          as review_score_avg,
    min(review_score)          as review_score_min,
    count(*)                   as review_count
from reviews
group by order_id
