-- BI-ready dimension: dim_marketing
-- One row per order's campaign/coupon attribution.

create or replace view dim_marketing as
select
    order_id,
    coupon_used,
    coupon_code,
    campaign_source,
    traffic_source
from marketing;
