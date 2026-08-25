-- BI-ready analytical output: transaction_health
-- One row per order, combining payment status, shipping status, and
-- order status into a single view for the "Transaction & Payment
-- Health" dashboard page -- avoids Power BI needing to join four
-- tables live for what is fundamentally a single-order-grain view.
--
-- SUPERSEDED (Phase 3): this simple version has no order_value,
-- profit, or business-classification (transaction_status /
-- transaction_health_flag). For the full Phase 3 transaction-health
-- object, use views/bi_ready/vw_transaction_health.sql instead. This
-- view is kept for backward compatibility / lighter-weight use cases
-- (e.g. a shipping+marketing-only lookup) where the aggregated
-- financials aren't needed.

create or replace view transaction_health as
select
    o.order_id,
    o.customer_id,
    dd.date_key as order_date,
    o.order_status,
    o.return_reason,
    p.payment_method,
    p.payment_status,
    p.currency,
    s.shipping_method,
    s.shipping_status,
    s.delivery_days,
    m.coupon_used,
    m.campaign_source
from orders o
left join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
left join payments p on o.order_id = p.order_id
left join shipping s on o.order_id = s.order_id
left join marketing m on o.order_id = m.order_id;
