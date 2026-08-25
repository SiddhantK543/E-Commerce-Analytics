-- BI-ready analytical output: transaction_risk_flags
-- View wrapper around sql/risk_fraud/04_transaction_risk_flags.sql so
-- the rule-based risk logic can be reused by other views (e.g.
-- vw_transaction_health) without duplicating the CTE logic inline.
-- See that file for full documentation of each signal and the
-- "rule-based framework, not ML" caveat -- it applies equally here.

create or replace view transaction_risk_flags as
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
    rm.fraud_risk_score,
    (ov.order_value > (vs.mean_value + 2 * vs.stddev_value))          as unusually_high_value,
    (coalesce(cfp.failed_payment_count, 0) >= 2)                       as repeated_failed_payment,
    (dup.order_id is not null)                                         as possible_duplicate_flag,
    (rm.fraud_risk_score > 80)                                         as high_fraud_score,
    (o.order_status in ('Returned', 'Cancelled'))                      as returned_or_cancelled,
    (sdmo.customer_id is not null)                                     as same_day_multi_order,
    (
        (case when ov.order_value > (vs.mean_value + 2 * vs.stddev_value) then 1 else 0 end) +
        (case when coalesce(cfp.failed_payment_count, 0) >= 2 then 1 else 0 end) +
        (case when dup.order_id is not null then 1 else 0 end) +
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
   and o.order_day = sdmo.order_day;
