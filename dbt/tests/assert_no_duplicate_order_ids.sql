-- Each order must appear exactly once in the fact table
-- (a bad join upstream would duplicate orders and inflate revenue).

select order_id, count(*) as occurrences
from {{ ref('fct_orders') }}
group by order_id
having count(*) > 1
