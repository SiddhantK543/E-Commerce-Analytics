-- ============================================================
-- Domain: Churn
-- File: sql/churn/advanced_churn_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- CHURN DEFINITION (unchanged from Phase 2/3 -- preserved per Phase 4
-- instructions not to arbitrarily redefine it): a customer is
-- "churned" if their most recent order is more than 6 months before
-- the latest order date anywhere in the dataset. This is a
-- project-defined threshold, not a business-confirmed one -- see
-- docs/business_definitions.md.
--
-- This file REUSES views/bi_ready/customer_churn.sql (which already
-- implements the definition above) rather than recomputing the
-- recency logic from scratch, per the Phase 4 instruction to reuse
-- existing BI-ready views where appropriate.
--
-- GRAIN: customer grain throughout.
-- ============================================================


-- 1. Overall churn rate (reusing the customer_churn view)
select
    count(*) as total_customers,
    sum(case when is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from customer_churn;

-- ------------------------------------------------------------------

-- 2. Churn by customer segment (extends
-- sql/churn/02_churn_rate_by_segment.sql; kept here too since this
-- file is meant to be the single comprehensive Phase 4 churn module)
select
    customer_segment,
    count(*) as total_customers,
    sum(case when is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from customer_churn
group by customer_segment
order by churn_rate_pct desc;

-- ------------------------------------------------------------------

-- 3. Churn by country
select
    country,
    count(*) as total_customers,
    sum(case when is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from customer_churn
group by country
order by churn_rate_pct desc;

-- ------------------------------------------------------------------

-- 4. Churn by acquisition/marketing source
-- NOTE: marketing.campaign_source/traffic_source are recorded PER
-- ORDER, not per customer -- there is no single "acquisition source"
-- column on the customers table. As a defensible proxy, this uses
-- the campaign/traffic source of each customer's FIRST order (a
-- reasonable interpretation of "acquisition source"), and documents
-- that interpretation rather than treating it as a confirmed
-- acquisition-channel field.
with first_order as (
    select distinct on (customer_id)
        customer_id, order_id
    from orders
    order by customer_id, order_year, order_month, order_day
)
select
    m.campaign_source,
    m.traffic_source,
    count(*) as total_customers,
    sum(case when cc.is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when cc.is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from first_order fo
inner join marketing m on fo.order_id = m.order_id
inner join customer_churn cc on fo.customer_id = cc.customer_id
group by m.campaign_source, m.traffic_source
order by churn_rate_pct desc;

-- ------------------------------------------------------------------

-- 5. Churn by customer value (monetary tier, reusing customer_rfm's
-- monetary_score rather than recomputing revenue tiers separately)
select
    r.monetary_score,
    count(*) as total_customers,
    sum(case when cc.is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when cc.is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from customer_rfm r
inner join customer_churn cc on r.customer_id = cc.customer_id
group by r.monetary_score
order by r.monetary_score desc;

-- ------------------------------------------------------------------

-- 6. Churn by order frequency (reusing customer_rfm's frequency_score)
select
    r.frequency_score,
    count(*) as total_customers,
    sum(case when cc.is_churned then 1 else 0 end) as churned_customers,
    round(100.0 * sum(case when cc.is_churned then 1 else 0 end) / count(*), 2) as churn_rate_pct
from customer_rfm r
inner join customer_churn cc on r.customer_id = cc.customer_id
group by r.frequency_score
order by r.frequency_score desc;

-- ------------------------------------------------------------------

-- 7. Churn over time: for each historical month, what share of
-- customers who had ever ordered by that point had gone quiet for 6+
-- months as of THAT month (a retrospective/point-in-time churn
-- trend, not just a single snapshot at the dataset's final month).
-- This deliberately re-derives from orders directly (not the
-- customer_churn view, which is fixed to the dataset's single latest
-- date) since the whole point here is evaluating churn AS OF each
-- historical month.
with monthly_points as (
    select distinct date_trunc('month', make_date(order_year, order_month, order_day))::date as as_of_month
    from orders
),
customer_last_order_by_point as (
    select
        mp.as_of_month,
        o.customer_id,
        max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_as_of_point
    from monthly_points mp
    inner join orders o
        -- BUG FIX (found during Phase 4 testing): as_of_month is the
        -- FIRST day of the month (from date_trunc). Comparing
        -- order_date <= as_of_month would wrongly exclude orders
        -- placed later in that same month (e.g. an order on the 15th
        -- would fail "<= the 1st"). Correct comparison: the order
        -- must fall before the START of the NEXT month.
        on make_date(o.order_year, o.order_month, o.order_day) < (mp.as_of_month + interval '1 month')
    group by mp.as_of_month, o.customer_id
)
select
    as_of_month,
    count(*) as customers_active_by_this_point,
    sum(case when last_order_as_of_point < (as_of_month - interval '6 months') then 1 else 0 end) as churned_as_of_point,
    round(
        100.0 * sum(case when last_order_as_of_point < (as_of_month - interval '6 months') then 1 else 0 end)
        / count(*),
        2
    ) as churn_rate_pct_as_of_point
from customer_last_order_by_point
group by as_of_month
order by as_of_month;
