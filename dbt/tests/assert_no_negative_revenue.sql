-- Revenue, item values and freight can never be negative.
-- Returns the offending orders (test passes when 0 rows).

select order_id, order_revenue, items_subtotal, freight_total
from {{ ref('fct_orders') }}
where order_revenue < 0
   or items_subtotal < 0
   or freight_total < 0
