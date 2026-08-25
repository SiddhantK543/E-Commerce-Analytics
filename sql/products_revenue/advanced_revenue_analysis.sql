-- ============================================================
-- Domain: Products & Revenue
-- File: sql/products_revenue/advanced_revenue_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- BUSINESS PURPOSE: revenue trend analysis at multiple time
-- granularities (daily/monthly/quarterly/yearly), with growth and
-- rolling-average window functions, for the Executive Overview and
-- Product & Revenue dashboard pages.
--
-- GRAIN: order_items aggregated to the requested time grain
-- (day / month / quarter / year). order_items is the correct source
-- table for revenue (it is the true transaction-value grain); orders
-- alone has no dollar amount. dim_date supplies calendar attributes
-- so no date arithmetic needs to be re-derived per query.
--
-- ASSUMPTIONS: see docs/business_definitions.md — revenue here means
-- total_price_usd (post-discount, pre/with-tax as stored), not a
-- distinct "net revenue" figure (not computable, no fee data).
-- ============================================================


-- 1. Daily revenue
select
    dd.date_key as order_date,
    round(sum(oi.total_price_usd), 2) as daily_revenue,
    count(distinct oi.order_id) as order_count
from order_items oi
inner join orders o on oi.order_id = o.order_id
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
group by dd.date_key
order by dd.date_key;

-- ------------------------------------------------------------------

-- 2. Monthly revenue
select
    dd.year,
    dd.month_number,
    dd.month_short_name,
    round(sum(oi.total_price_usd), 2) as monthly_revenue,
    count(distinct oi.order_id) as order_count
from order_items oi
inner join orders o on oi.order_id = o.order_id
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
group by dd.year, dd.month_number, dd.month_short_name
order by dd.year, dd.month_number;

-- ------------------------------------------------------------------

-- 3. Quarterly revenue
select
    dd.year,
    dd.quarter_label,
    round(sum(oi.total_price_usd), 2) as quarterly_revenue,
    count(distinct oi.order_id) as order_count
from order_items oi
inner join orders o on oi.order_id = o.order_id
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
group by dd.year, dd.quarter_label
order by dd.year, dd.quarter_label;

-- ------------------------------------------------------------------

-- 4. Yearly revenue
-- NOTE: 2024 begins in March and 2026 ends in February in this
-- dataset (per docs/data_dictionary.md) -- these are partial years,
-- not full 12-month periods. Do not compare them as if they were.
select
    dd.year,
    round(sum(oi.total_price_usd), 2) as yearly_revenue,
    count(distinct oi.order_id) as order_count
from order_items oi
inner join orders o on oi.order_id = o.order_id
inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
group by dd.year
order by dd.year;

-- ------------------------------------------------------------------

-- 5. Month-over-month revenue growth (LAG)
with monthly_revenue as (
    select
        dd.year,
        dd.month_number,
        round(sum(oi.total_price_usd), 2) as monthly_revenue
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
    group by dd.year, dd.month_number
)
select
    year,
    month_number,
    monthly_revenue,
    lag(monthly_revenue) over (order by year, month_number) as previous_month_revenue,
    round(
        100.0 * (monthly_revenue - lag(monthly_revenue) over (order by year, month_number))
        / nullif(lag(monthly_revenue) over (order by year, month_number), 0),
        2
    ) as mom_growth_pct
from monthly_revenue
order by year, month_number;

-- ------------------------------------------------------------------

-- 6. Revenue moving average (3-month rolling average, overall --
-- distinct from sql/products_revenue/09_rolling_3month_avg_revenue_by_category.sql,
-- which is per-category; this is the whole-business trend line)
with monthly_revenue as (
    select
        dd.year,
        dd.month_number,
        round(sum(oi.total_price_usd), 2) as monthly_revenue
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join dim_date dd on dd.date_key = make_date(o.order_year, o.order_month, o.order_day)
    group by dd.year, dd.month_number
)
select
    year,
    month_number,
    monthly_revenue,
    round(
        avg(monthly_revenue) over (
            order by year, month_number
            rows between 2 preceding and current row
        ),
        2
    ) as rolling_3month_avg_revenue
from monthly_revenue
order by year, month_number;
