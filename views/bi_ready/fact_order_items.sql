-- BI-ready fact: fact_order_items
-- Grain: one row per (order_id, product_id) line item -- this is the
-- true transactional grain and the main table Power BI's revenue/
-- profit visuals should aggregate from.

create or replace view fact_order_items as
select
    oi.order_id,
    oi.product_id,
    o.customer_id,
    dd.date_key       as order_date,
    oi.quantity,
    oi.unit_price_usd,
    oi.discount_percent,
    oi.discount_amount_usd,
    oi.total_price_usd,
    oi.cost_usd,
    oi.profit_usd,
    oi.tax_usd,
    oi.profit_margin_percent
from order_items oi
inner join orders o on oi.order_id = o.order_id
left join dim_date dd
    on dd.date_key = make_date(o.order_year, o.order_month, o.order_day);
