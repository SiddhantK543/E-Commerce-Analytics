-- ============================================================
-- Domain: Payments
-- File: sql/payments/advanced_payment_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- This file ADDS new angles beyond sql/payments/payment_health.sql
-- (Phase 3) rather than recreating its KPI logic. Overall
-- success/failure rate and method-level performance already live in
-- payment_health.sql -- see that file for those. This file covers:
-- failure trend over time, failure by order-value bucket, and a
-- payment-method x risk-flag cross-tab (reusing the Phase 3
-- transaction_risk_flags view rather than recomputing risk logic).
--
-- GRAIN: order grain, using vw_transaction_health (already grain-safe
-- -- one row per order with order_value pre-aggregated) as the base
-- wherever possible, per the Phase 4 instruction to reuse the
-- transaction-health framework rather than re-deriving it.
-- ============================================================


-- 1. Payment failures over time (monthly trend, with LAG-based
-- period-over-period comparison)
with monthly_failures as (
    select
        dd.year,
        dd.month_number,
        count(*) filter (where vth.payment_status = 'Failed') as failed_payments,
        count(*) as total_payments
    from vw_transaction_health vth
    inner join dim_date dd on dd.date_key = vth.order_date
    group by dd.year, dd.month_number
)
select
    year,
    month_number,
    failed_payments,
    total_payments,
    round(100.0 * failed_payments / nullif(total_payments, 0), 2) as failure_rate_pct,
    lag(failed_payments) over (order by year, month_number) as previous_month_failed_payments,
    (failed_payments - lag(failed_payments) over (order by year, month_number)) as change_in_failed_payments
from monthly_failures
order by year, month_number;

-- ------------------------------------------------------------------

-- 2. Payment failure by order-value bucket (does failure correlate
-- with transaction size?)
select
    case
        when order_value < 50 then '1. Under $50'
        when order_value < 150 then '2. $50-$149.99'
        when order_value < 300 then '3. $150-$299.99'
        else '4. $300+'
    end as order_value_bucket,
    count(*) as total_orders,
    count(*) filter (where payment_status = 'Failed') as failed_orders,
    round(
        100.0 * count(*) filter (where payment_status = 'Failed') / count(*),
        2
    ) as failure_rate_pct
from vw_transaction_health
group by 1
order by 1;

-- ------------------------------------------------------------------

-- 3. Payment method performance cross-tabbed with the Phase 3 risk
-- framework (reusing transaction_risk_flags rather than recomputing)
select
    vth.payment_method,
    trf.transaction_risk_flag,
    count(*) as order_count,
    round(sum(vth.order_value), 2) as total_order_value
from vw_transaction_health vth
inner join transaction_risk_flags trf on vth.order_id = trf.order_id
group by vth.payment_method, trf.transaction_risk_flag
order by vth.payment_method, trf.transaction_risk_flag;

-- ------------------------------------------------------------------

-- 4. Coupon usage vs. payment failure relationship (rate comparison,
-- extending sql/payments/payment_health.sql query 7's raw count with
-- a proper failure-RATE comparison between coupon and non-coupon
-- orders)
select
    m.coupon_used,
    count(*) as total_orders,
    count(*) filter (where vth.payment_status = 'Failed') as failed_orders,
    round(
        100.0 * count(*) filter (where vth.payment_status = 'Failed') / count(*),
        2
    ) as failure_rate_pct
from vw_transaction_health vth
inner join marketing m on vth.order_id = m.order_id
group by m.coupon_used
order by m.coupon_used;
