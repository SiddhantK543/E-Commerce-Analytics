-- BI-ready dimension: dim_shipping
-- One row per order's shipping details.

create or replace view dim_shipping as
select
    order_id,
    shipping_method,
    shipping_cost_usd,
    delivery_days,
    warehouse,
    shipping_status
from shipping;
