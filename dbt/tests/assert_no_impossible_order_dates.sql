-- After staging cleanup, no order should have impossible dates:
-- purchases outside the dataset period or in the future, or steps before the purchase.

select order_id, purchased_at, approved_at, shipped_to_carrier_at, delivered_at
from {{ ref('fct_orders') }}
where purchased_at < '2016-01-01'
   or purchased_at > current_timestamp()
   or approved_at < purchased_at
   or shipped_to_carrier_at < purchased_at
   or delivered_at < purchased_at
