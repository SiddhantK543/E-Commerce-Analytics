-- ============================================================
-- Domain: Customers
-- File: sql/customers/cohort_retention.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- BUSINESS PURPOSE: classic cohort/retention analysis -- group
-- customers by the month of their FIRST order (their "cohort"), then
-- measure what fraction of each cohort placed at least one order in
-- each subsequent month. Powers a Power BI retention-matrix visual
-- (cohort month x months-since-first-purchase).
--
-- GRAIN: this file produces two outputs at two different grains,
-- clearly separated:
--   (a) cohort_customers: one row per (customer, cohort_month) --
--       used only as an intermediate building block
--   (b) the final retention output: one row per
--       (cohort_month, months_since_first_purchase) -- i.e. one row
--       per cohort per elapsed-month bucket, NOT per customer. This
--       is the grain a retention-matrix visual expects.
--
-- AVOIDING DOUBLE-COUNTING: a customer is counted at most once per
-- (cohort_month, months_since_first_purchase) cell via
-- COUNT(DISTINCT customer_id) -- even if they placed multiple orders
-- in that elapsed-month bucket, they contribute 1 to "active
-- customers," not one per order.
-- ============================================================

with cohort_customers as (
    -- Each customer's cohort = the month of their first-ever order
    select
        customer_id,
        date_trunc('month', min(make_date(order_year, order_month, order_day)))::date as cohort_month
    from orders
    group by customer_id
),
customer_orders_with_cohort as (
    select
        o.customer_id,
        cc.cohort_month,
        date_trunc('month', make_date(o.order_year, o.order_month, o.order_day))::date as order_month
    from orders o
    inner join cohort_customers cc on o.customer_id = cc.customer_id
),
cohort_activity as (
    -- months_since_first_purchase: 0 = the cohort month itself, 1 =
    -- one calendar month later, etc. Computed via age-in-months
    -- between two truncated month-start dates (safe integer math,
    -- no day-of-month rounding issues since both sides are always
    -- the 1st of a month).
    select distinct
        cohort_month,
        customer_id,
        (
            (extract(year from order_month) - extract(year from cohort_month)) * 12
            + (extract(month from order_month) - extract(month from cohort_month))
        )::int as months_since_first_purchase
    from customer_orders_with_cohort
),
cohort_sizes as (
    select cohort_month, count(distinct customer_id) as cohort_size
    from cohort_customers
    group by cohort_month
)
select
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_first_purchase,
    count(distinct ca.customer_id) as active_customers,
    round(100.0 * count(distinct ca.customer_id) / cs.cohort_size, 2) as retention_rate_pct
from cohort_activity ca
inner join cohort_sizes cs on ca.cohort_month = cs.cohort_month
group by ca.cohort_month, cs.cohort_size, ca.months_since_first_purchase
order by ca.cohort_month, ca.months_since_first_purchase;

-- ============================================================
-- CAVEAT: with only 5 test customers across 5 distinct cohort months
-- (Phase 2/3 synthetic seed data), every cohort in this test dataset
-- has exactly 1 customer -- retention_rate_pct will only ever read
-- 0% or 100% per cell. This is a sample-size artifact of the tiny
-- test dataset, not a bug; the logic is grain-safe and ready for the
-- real ~1M-row dataset, where cohorts will contain many customers
-- and retention rates will vary meaningfully between 0% and 100%.
-- ============================================================
