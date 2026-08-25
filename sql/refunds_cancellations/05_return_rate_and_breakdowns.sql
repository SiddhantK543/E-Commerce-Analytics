-- ============================================================
-- Domain: Refunds & Cancellations
-- File: sql/refunds_cancellations/05_return_rate_and_breakdowns.sql
-- Added in Phase 3.
--
-- TERMINOLOGY: as with cancellations, there is no refund-amount
-- column. Figures below are "order value associated with returns",
-- not "refund amount". See docs/business_definitions.md.
--
-- FIX (found during Phase 3 testing): a single WITH clause only
-- scopes to the ONE statement immediately following it -- it does NOT
-- carry across multiple semicolon-separated queries in the same file.
-- Each query below repeats its own `with order_value as (...)` CTE.
-- ============================================================


-- 1. Overall return count and rate
select
    count(*) as total_orders,
    sum(case when order_status = 'Returned' then 1 else 0 end) as returned_orders,
    round(
        100.0 * sum(case when order_status = 'Returned' then 1 else 0 end) / count(*),
        2
    ) as return_rate_pct
from orders;

-- ------------------------------------------------------------------

-- 2. Return reasons (extends sql/refunds_cancellations/02_return_reason_breakdown.sql
-- with order value attached)
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    return_reason,
    count(*) as order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_returns,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_of_returns
from orders o
left join order_value ov on o.order_id = ov.order_id
where order_status = 'Returned'
  and return_reason is not null
group by return_reason
order by order_count desc;

-- ------------------------------------------------------------------

-- 3. Returns by month
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    dd.year,
    dd.month_number,
    dd.month_short_name,
    count(*) as returned_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_returns
from orders o
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Returned'
group by dd.year, dd.month_number, dd.month_short_name
order by dd.year, dd.month_number;

-- ------------------------------------------------------------------

-- 4. Returns by customer segment
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    c.customer_segment,
    count(*) as returned_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_returns
from orders o
inner join customers c on o.customer_id = c.customer_id
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Returned'
group by c.customer_segment
order by returned_order_count desc;

-- ------------------------------------------------------------------

-- 5. Returns by country
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
)
select
    c.country,
    count(*) as returned_order_count,
    round(sum(ov.order_value), 2) as order_value_associated_with_returns
from orders o
inner join customers c on o.customer_id = c.customer_id
left join order_value ov on o.order_id = ov.order_id
where o.order_status = 'Returned'
group by c.country
order by returned_order_count desc;
