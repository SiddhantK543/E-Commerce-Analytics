-- ============================================================
-- BI-ready analytical output: vw_transaction_health
-- Grain: ONE ROW PER ORDER.
--
-- GRAIN WARNING (see docs/architecture.md / Phase 3 notes):
-- order_items is a one-to-many child of orders. This view aggregates
-- order_items to order_value/profit BEFORE joining to orders, payments,
-- shipping, customers -- all of which are 1:1 with orders. This
-- prevents the classic bug of a multi-line order inflating order
-- counts or double-counting order_value when joined at the wrong grain.
-- Never join orders directly to order_items in a query that then does
-- COUNT(order_id) or SUM(order_value) without first aggregating
-- order_items down to one row per order_id.
--
-- Depends on:
--   sql/date_dimension/create_dim_date.sql
--   views/bi_ready/transaction_risk_flags.sql
-- ============================================================

create or replace view vw_transaction_health as
with order_financials as (
    -- Aggregate order_items DOWN to one row per order_id first.
    -- This is the critical grain-safety step for this whole view.
    select
        order_id,
        sum(total_price_usd) as order_value,
        sum(profit_usd)      as order_profit,
        count(*)             as line_item_count
    from order_items
    group by order_id
)
select
    -- Transaction information
    o.order_id,
    o.customer_id,
    dd.date_key                as order_date,
    coalesce(of.order_value, 0) as order_value,
    o.order_status,
    o.return_reason,

    -- Payment information
    p.payment_method,
    p.payment_status,

    -- Customer information
    c.customer_segment,
    c.country,

    -- Risk information
    trf.fraud_risk_score,
    trf.transaction_risk_flag,
    coalesce(trf.possible_duplicate_flag, false) as possible_duplicate_flag,

    -- Business metrics: profit
    coalesce(of.order_profit, 0) as profit,
    of.line_item_count,

    -- ------------------------------------------------------------
    -- transaction_status: business classification built ONLY from
    -- status values actually confirmed present in this project's
    -- data (order_status: Delivered / Returned / Cancelled;
    -- payment_status: Success / Failed -- see
    -- docs/business_definitions.md for the full rule set and the
    -- explicit statement that 'Refunded', 'Pending', and 'Suspicious'
    -- are NOT present as literal status values in this schema and
    -- are therefore not fabricated here).
    -- ------------------------------------------------------------
    case
        when p.payment_status = 'Failed' then 'Failed'
        when o.order_status = 'Cancelled' then 'Cancelled'
        when o.order_status = 'Returned' then 'Returned'
        when p.payment_status = 'Pending' then 'Pending'
        when p.payment_status = 'Success'
             and o.order_status not in ('Cancelled', 'Returned') then 'Successful'
        else 'Unclassified'
    end as transaction_status,

    -- ------------------------------------------------------------
    -- transaction_health_flag: a simpler, three-value summary of the
    -- above, intended for a Power BI KPI card / conditional-formatting
    -- use case. See docs/business_definitions.md for the mapping.
    -- ------------------------------------------------------------
    case
        when p.payment_status = 'Failed' then 'Lost'
        when o.order_status in ('Cancelled', 'Returned') then 'At Risk'
        when p.payment_status = 'Success'
             and o.order_status not in ('Cancelled', 'Returned') then 'Healthy'
        else 'Unclassified'
    end as transaction_health_flag,

    -- ------------------------------------------------------------
    -- Business metrics: value breakdown (see docs/business_definitions.md
    -- -- these four are mutually exclusive per order, never summed
    -- together to avoid double-counting the same order_value twice)
    -- ------------------------------------------------------------
    coalesce(of.order_value, 0) as gross_value,
    case when p.payment_status = 'Success'
              and o.order_status not in ('Cancelled', 'Returned')
         then coalesce(of.order_value, 0) else 0 end as successful_value,
    case when o.order_status in ('Cancelled', 'Returned')
         then coalesce(of.order_value, 0) else 0 end as affected_order_value,
    case when p.payment_status = 'Failed'
         then coalesce(of.order_value, 0) else 0 end as potential_lost_value

from orders o
left join order_financials of on o.order_id = of.order_id
left join payments p on o.order_id = p.order_id
left join customers c on o.customer_id = c.customer_id
left join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
left join transaction_risk_flags trf on o.order_id = trf.order_id;

-- NOTE on join types: LEFT JOIN is used throughout (not INNER) so that
-- an order missing a payment/customer/date record still appears in
-- this view rather than silently vanishing -- any resulting NULLs are
-- themselves a data-quality signal (see
-- sql/data_quality/08_missing_relationships_extended.sql).
