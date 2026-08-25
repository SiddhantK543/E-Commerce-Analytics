-- ============================================================
-- Domain: Customers
-- File: sql/customers/rfm_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- This file documents and exposes the SAME RFM logic as
-- views/bi_ready/customer_rfm.sql (kept in sync deliberately -- this
-- file is the business-domain-organized, heavily-commented version;
-- the view is the lightweight BI-consumption wrapper). If you change
-- the segmentation rules, update both files.
--
-- GRAIN: customer grain (one row per customer).
--
-- METHODOLOGY:
--   Recency  = days between each customer's most recent order and the
--              latest order date anywhere in the dataset (a fixed
--              reference point -- NOT today's real-world date, since
--              this dataset's most recent order is 2026-02, not the
--              actual current date)
--   Frequency = COUNT(DISTINCT order_id) per customer
--   Monetary  = SUM(order_items.total_price_usd) per customer
--
-- SCORING: each of Recency/Frequency/Monetary is split into 5
-- percentile-based buckets via NTILE(5) -- a genuinely percentile-
-- based method, as opposed to fixed arbitrary cutoffs. Recency is
-- inverted (most recent = score 5) so that "5" always means "best"
-- across all three dimensions, keeping rfm_total_score directly
-- interpretable (higher is always better).
--
-- SEGMENT RULES (first match wins; documented here as the single
-- source of truth alongside docs/sql_analytics.md):
--   Champions            : R>=4 AND F>=4 AND M>=4
--   Loyal Customers       : R>=3 AND F>=3
--   Potential Loyalists   : R>=4 AND F<=2
--   At Risk               : R<=2 AND (F>=3 OR M>=3)
--   Lost Customers        : R<=2 AND F<=2 AND M<=2
--   Needs Attention       : anything else (a genuine catch-all --
--                           e.g. a mid-recency, low-frequency,
--                           low-monetary customer who doesn't cleanly
--                           fit any of the above archetypes)
--
-- CAVEAT: with only 5 test customers (Phase 2/3 synthetic seed data),
-- NTILE(5) quintiles are not meaningful -- each customer effectively
-- lands in their own bucket. This logic is correct and ready for the
-- real ~1M-row dataset, where quintiles will be meaningful; the
-- output below on test data should be read as a correctness check,
-- not a business finding.
-- ============================================================

with reference_date as (
    select max(make_date(order_year, order_month, order_day)) as latest_order_date
    from orders
),
customer_orders as (
    select
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date,
        count(distinct o.order_id) as frequency,
        sum(oi.total_price_usd) as monetary
    from customers c
    inner join orders o on c.customer_id = o.customer_id
    inner join order_items oi on o.order_id = oi.order_id
    group by c.customer_id, c.customer_name, c.customer_segment
),
rfm_base as (
    select
        co.*,
        rd.latest_order_date,
        (rd.latest_order_date - co.last_order_date) as recency_days
    from customer_orders co
    cross join reference_date rd
),
rfm_scored as (
    select
        *,
        (6 - ntile(5) over (order by recency_days)) as recency_score,
        ntile(5) over (order by frequency)          as frequency_score,
        ntile(5) over (order by monetary)            as monetary_score
    from rfm_base
)
select
    customer_id,
    customer_name,
    customer_segment,
    last_order_date,
    recency_days,
    frequency,
    round(monetary, 2) as monetary,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) as rfm_total_score,
    case
        when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4 then 'Champions'
        when recency_score >= 3 and frequency_score >= 3 then 'Loyal Customers'
        when recency_score >= 4 and frequency_score <= 2 then 'Potential Loyalists'
        when recency_score <= 2 and (frequency_score >= 3 or monetary_score >= 3) then 'At Risk'
        when recency_score <= 2 and frequency_score <= 2 and monetary_score <= 2 then 'Lost Customers'
        else 'Needs Attention'
    end as rfm_segment
from rfm_scored
order by rfm_total_score desc;
