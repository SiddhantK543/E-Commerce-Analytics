-- ============================================================
-- Domain: Risk / Fraud
-- File: sql/risk_fraud/04_transaction_risk_flags.sql
-- Added in Phase 3.
--
-- THIS IS A RULE-BASED ANALYTICAL FRAMEWORK, NOT A MACHINE-LEARNING
-- FRAUD MODEL. Every signal below is a simple, explainable rule built
-- directly on existing columns. None of this should be described as
-- "ML-based fraud detection" -- it is a first-pass risk-triage layer
-- that a human reviewer would still act on.
--
-- Signals implemented (only those supported by existing columns):
--   1. unusually_high_value   -- order_value > (overall mean + 2*stddev)
--   2. repeated_failed_payment -- this customer has 2+ failed-payment
--                                 orders anywhere in the dataset
--   3. possible_duplicate      -- this order contains at least one line
--                                 item matching the duplicate-candidate
--                                 logic in 03_duplicate_transaction_detection.sql
--   4. high_fraud_score        -- risk_management.fraud_risk_score > 80
--                                 (illustrative threshold, see caveat
--                                 in sql/risk_fraud/02_high_risk_combo_flags.sql)
--   5. failed_payment_high_value -- payment failed AND order_value is
--                                   itself unusually high (signal 1)
--   6. returned_or_cancelled   -- order_status in ('Returned','Cancelled')
--   7. same_day_multi_order    -- this customer placed more than one
--                                 order on the same calendar day
--                                 (a coarse proxy for "unusual
--                                 transaction frequency" -- the schema
--                                 only has day-level granularity, not
--                                 timestamps, so anything finer-grained
--                                 than "same day" cannot be determined)
--
-- transaction_risk_flag combines these into three tiers:
--   'High Risk' -- 2 or more signals fire, OR high_fraud_score alone
--   'Review'    -- exactly 1 signal fires
--   'Normal'    -- no signals fire
-- These thresholds are a documented starting point, not derived from
-- statistical optimization against real outcomes (there is no labeled
-- fraud outcome column to optimize against).
--
-- GRAIN: one row per order (order-level risk assessment).
-- ============================================================

with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
),
value_stats as (
    select avg(order_value) as mean_value, stddev_pop(order_value) as stddev_value
    from order_value
),
customer_failed_payments as (
    select o.customer_id, count(*) as failed_payment_count
    from orders o
    inner join payments p on o.order_id = p.order_id
    where p.payment_status = 'Failed'
    group by o.customer_id
),
duplicate_orders as (
    -- Orders containing at least one line item flagged as a possible
    -- duplicate by 03_duplicate_transaction_detection.sql's logic
    select distinct oi.order_id
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join payments pay on o.order_id = pay.order_id
    where exists (
        select 1
        from order_items oi2
        inner join orders o2 on oi2.order_id = o2.order_id
        inner join payments pay2 on o2.order_id = pay2.order_id
        where oi2.product_id = oi.product_id
          and oi2.total_price_usd = oi.total_price_usd
          and o2.customer_id = o.customer_id
          and o2.order_year = o.order_year
          and o2.order_month = o.order_month
          and o2.order_day = o.order_day
          and pay2.payment_method = pay.payment_method
          and oi2.order_id <> oi.order_id
    )
),
same_day_multi_order as (
    select customer_id, order_year, order_month, order_day, count(*) as orders_that_day
    from orders
    group by customer_id, order_year, order_month, order_day
    having count(*) > 1
)
select
    o.order_id,
    o.customer_id,
    round(ov.order_value, 2) as order_value,
    o.order_status,
    p.payment_status,
    rm.fraud_risk_score,

    (ov.order_value > (vs.mean_value + 2 * vs.stddev_value))          as unusually_high_value,
    (coalesce(cfp.failed_payment_count, 0) >= 2)                       as repeated_failed_payment,
    (dup.order_id is not null)                                         as possible_duplicate,
    (rm.fraud_risk_score > 80)                                         as high_fraud_score,
    (p.payment_status = 'Failed'
        and ov.order_value > (vs.mean_value + 2 * vs.stddev_value))    as failed_payment_high_value,
    (o.order_status in ('Returned', 'Cancelled'))                      as returned_or_cancelled,
    (sdmo.customer_id is not null)                                     as same_day_multi_order,

    (
        (case when ov.order_value > (vs.mean_value + 2 * vs.stddev_value) then 1 else 0 end) +
        (case when coalesce(cfp.failed_payment_count, 0) >= 2 then 1 else 0 end) +
        (case when dup.order_id is not null then 1 else 0 end) +
        (case when rm.fraud_risk_score > 80 then 1 else 0 end) +
        (case when o.order_status in ('Returned', 'Cancelled') then 1 else 0 end) +
        (case when sdmo.customer_id is not null then 1 else 0 end)
    ) as signals_triggered,

    case
        when rm.fraud_risk_score > 80 then 'High Risk'
        when (
            (case when ov.order_value > (vs.mean_value + 2 * vs.stddev_value) then 1 else 0 end) +
            (case when coalesce(cfp.failed_payment_count, 0) >= 2 then 1 else 0 end) +
            (case when dup.order_id is not null then 1 else 0 end) +
            (case when o.order_status in ('Returned', 'Cancelled') then 1 else 0 end) +
            (case when sdmo.customer_id is not null then 1 else 0 end)
        ) >= 2 then 'High Risk'
        when (
            (case when ov.order_value > (vs.mean_value + 2 * vs.stddev_value) then 1 else 0 end) +
            (case when coalesce(cfp.failed_payment_count, 0) >= 2 then 1 else 0 end) +
            (case when dup.order_id is not null then 1 else 0 end) +
            (case when o.order_status in ('Returned', 'Cancelled') then 1 else 0 end) +
            (case when sdmo.customer_id is not null then 1 else 0 end)
        ) = 1 then 'Review'
        else 'Normal'
    end as transaction_risk_flag

from orders o
left join order_value ov on o.order_id = ov.order_id
cross join value_stats vs
left join payments p on o.order_id = p.order_id
left join risk_management rm on o.order_id = rm.order_id
left join customer_failed_payments cfp on o.customer_id = cfp.customer_id
left join duplicate_orders dup on o.order_id = dup.order_id
left join same_day_multi_order sdmo
    on o.customer_id = sdmo.customer_id
   and o.order_year = sdmo.order_year
   and o.order_month = sdmo.order_month
   and o.order_day = sdmo.order_day
order by signals_triggered desc, order_value desc;
