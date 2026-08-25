-- ============================================================
-- Domain: Payments
-- File: sql/payments/payment_health.sql
-- Purpose: comprehensive payment-health analysis for the "Transaction
-- & Payment Health" dashboard page.
--
-- GRAIN WARNING: order_items is one-to-many with orders. Every query
-- below that needs order_value aggregates order_items to one row per
-- order_id in a CTE BEFORE joining to payments (which is 1:1 with
-- orders) -- this avoids inflating revenue or order counts.
--
-- TERMINOLOGY (see docs/business_definitions.md for full definitions):
--   Gross transaction value = order_value for ALL orders, regardless
--                              of payment outcome
--   Successful revenue      = order_value only for orders where
--                              payment_status = 'Success'
--   Potential lost revenue  = order_value only for orders where
--                              payment_status = 'Failed'
-- These three are never summed together or conflated below.
-- ============================================================


-- 1. Total transactions, successful payments, failed payments, and
--    success/failure rates (order-level counts, using payments as the
--    driving table since it is already 1:1 with orders)

select
    count(*) as total_transactions,
    sum(case when payment_status = 'Success' then 1 else 0 end) as successful_payments,
    sum(case when payment_status = 'Failed' then 1 else 0 end) as failed_payments,
    round(
        100.0 * sum(case when payment_status = 'Success' then 1 else 0 end) / count(*),
        2
    ) as payment_success_rate_pct,
    round(
        100.0 * sum(case when payment_status = 'Failed' then 1 else 0 end) / count(*),
        2
    ) as payment_failure_rate_pct
from payments;

-- ------------------------------------------------------------------

-- 2. Payment method performance: transactions, success rate, and
--    revenue by payment method

with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    p.payment_method,
    count(*) as total_transactions,
    sum(case when p.payment_status = 'Success' then 1 else 0 end) as successful_payments,
    sum(case when p.payment_status = 'Failed' then 1 else 0 end) as failed_payments,
    round(
        100.0 * sum(case when p.payment_status = 'Success' then 1 else 0 end) / count(*),
        2
    ) as success_rate_pct,
    round(sum(ov.order_value), 2) as gross_transaction_value,
    round(
        sum(case when p.payment_status = 'Success' then ov.order_value else 0 end), 2
    ) as successful_revenue,
    round(
        sum(case when p.payment_status = 'Failed' then ov.order_value else 0 end), 2
    ) as potential_lost_revenue
from payments p
left join order_value ov on p.order_id = ov.order_id
group by p.payment_method
order by total_transactions desc;

-- ------------------------------------------------------------------

-- 3. Failed payments by month (requires dim_date; run
--    sql/date_dimension/create_dim_date.sql first)

select
    dd.year,
    dd.month_number,
    dd.month_short_name,
    count(*) as failed_payment_count
from payments p
inner join orders o on p.order_id = o.order_id
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
where p.payment_status = 'Failed'
group by dd.year, dd.month_number, dd.month_short_name
order by dd.year, dd.month_number;

-- ------------------------------------------------------------------

-- 4. Failed payments by customer segment

select
    c.customer_segment,
    count(*) as failed_payment_count
from payments p
inner join orders o on p.order_id = o.order_id
inner join customers c on o.customer_id = c.customer_id
where p.payment_status = 'Failed'
group by c.customer_segment
order by failed_payment_count desc;

-- ------------------------------------------------------------------

-- 5. Failed payments by country

select
    c.country,
    count(*) as failed_payment_count
from payments p
inner join orders o on p.order_id = o.order_id
inner join customers c on o.customer_id = c.customer_id
where p.payment_status = 'Failed'
group by c.country
order by failed_payment_count desc;

-- ------------------------------------------------------------------

-- 6. Failed payments by marketing campaign / traffic source

select
    m.campaign_source,
    m.traffic_source,
    count(*) as failed_payment_count
from payments p
inner join marketing m on p.order_id = m.order_id
where p.payment_status = 'Failed'
group by m.campaign_source, m.traffic_source
order by failed_payment_count desc;

-- ------------------------------------------------------------------

-- 7. Failed payments involving a coupon (extends the original
-- project's medium_questions.sql Q8/Q9, now folded into this unified
-- payment-health module)

with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    count(*) as failed_coupon_orders,
    round(sum(ov.order_value), 2) as potential_lost_revenue
from payments p
inner join marketing m on p.order_id = m.order_id
left join order_value ov on p.order_id = ov.order_id
where p.payment_status = 'Failed'
  and m.coupon_used = 'Yes';

-- ------------------------------------------------------------------

-- 8. Overall gross vs. successful vs. potential-lost revenue summary
--    (the single most important payment-health reconciliation query --
--    these three figures should NEVER be added together, since
--    successful_revenue + potential_lost_revenue + (any Pending/
--    Unclassified order_value) = gross_transaction_value)

with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    round(sum(ov.order_value), 2) as gross_transaction_value,
    round(sum(case when p.payment_status = 'Success' then ov.order_value else 0 end), 2) as successful_revenue,
    round(sum(case when p.payment_status = 'Failed' then ov.order_value else 0 end), 2) as potential_lost_revenue,
    round(
        sum(case when p.payment_status not in ('Success', 'Failed') or p.payment_status is null
                 then ov.order_value else 0 end), 2
    ) as other_unclassified_value
from orders o
left join order_value ov on o.order_id = ov.order_id
left join payments p on o.order_id = p.order_id;
