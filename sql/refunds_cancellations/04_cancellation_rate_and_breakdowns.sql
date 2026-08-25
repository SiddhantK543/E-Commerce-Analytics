-- ============================================================
-- Domain: Refunds & Cancellations
-- File: sql/refunds_cancellations/04_cancellation_rate_and_breakdowns.sql
-- Added in Phase 3.
--
-- TERMINOLOGY: this project has NO refund-amount column anywhere in
-- the schema (see docs/business_definitions.md). Every dollar figure
-- below is labeled "order value associated with cancellations", NOT
-- "refund amount" -- we do not know how much was actually refunded,
-- only the value of the order that was cancelled.
--
-- GRAIN WARNING: order_items aggregated to order_value in a CTE
-- BEFORE joining to orders (1:many) to avoid double-counting.
--
-- FIX (found during Phase 3 testing): a single WITH clause only
-- scopes to the ONE statement immediately following it -- it does NOT
-- carry across multiple semicolon-separated queries in the same file.
-- Each query below therefore repeats its own `with order_value as (...)`
-- CTE rather than sharing one at the top of the file.
-- ============================================================


-- 1. Overall cancellation count and rate
select
    count(*) as total_orders,
    sum(case when order_status = 'Cancelled' then 1 else 0 end) as cancelled_orders,
    round(
        100.0 * sum(case when order_status = 'Cancelled' then 1 else 0 end) / count(*),
        2
    ) as cancellation_rate_pct
from orders;

-- ------------------------------------------------------------------

-- 2. Cancellations by month (requires dim_date)
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    dd.year,
    dd.month_number,
    dd.month_short_name,
    count(*) as cancelled_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_cancellations
from orders o
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Cancelled'
group by dd.year, dd.month_number, dd.month_short_name
order by dd.year, dd.month_number;

-- ------------------------------------------------------------------

-- 3. Cancellations by customer segment
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    c.customer_segment,
    count(*) as cancelled_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_cancellations
from orders o
inner join customers c on o.customer_id = c.customer_id
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Cancelled'
group by c.customer_segment
order by cancelled_order_count desc;

-- ------------------------------------------------------------------

-- 4. Cancellations by country
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    c.country,
    count(*) as cancelled_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_cancellations
from orders o
inner join customers c on o.customer_id = c.customer_id
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Cancelled'
group by c.country
order by cancelled_order_count desc;

-- ------------------------------------------------------------------

-- 5. Cancellations by product / category
-- NOTE: this joins at the order_items grain deliberately -- a
-- cancelled order can contain multiple products, and we want to know
-- which products/categories are OVER-REPRESENTED in cancelled orders,
-- not order-level counts. Do not reuse this result as an order count.
select
    p.category,
    p.product_id,
    p.product_name,
    count(*) as line_items_in_cancelled_orders,
    round(sum(oi.total_price_usd), 2) as order_value_associated_with_cancellations
from orders o
inner join order_items oi on o.order_id = oi.order_id
inner join products p on oi.product_id = p.product_id
where o.order_status = 'Cancelled'
group by p.category, p.product_id, p.product_name
order by line_items_in_cancelled_orders desc;

-- ------------------------------------------------------------------

-- 6. Cancellations by payment method
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    pay.payment_method,
    count(*) as cancelled_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_cancellations
from orders o
inner join payments pay on o.order_id = pay.order_id
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Cancelled'
group by pay.payment_method
order by cancelled_order_count desc;
