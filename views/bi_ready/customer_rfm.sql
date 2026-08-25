-- ============================================================
-- BI-ready analytical output: customer_rfm
-- Recency / Frequency / Monetary segmentation, computed independently
-- of the existing categorical `customer_segment` field (which is a
-- source-provided label, not a derived RFM score).
--
-- Recency  = days since each customer's most recent order, relative to
--            the latest order date in the whole dataset (a fixed
--            reference point, consistent with the existing churn query)
-- Frequency = distinct number of orders placed
-- Monetary  = total revenue (total_price_usd) generated
--
-- Scores are quintile-based (1-5, 5 = best) via NTILE(5), the standard
-- percentile-based approach for RFM. Segment labels use a simple,
-- explainable rule set rather than a black-box model -- intentionally
-- kept interview-explainable per project constraints.
--
-- PHASE 4 UPDATE: segment names aligned to the standard RFM taxonomy
-- (Champions / Loyal Customers / Potential Loyalists / At Risk / Lost
-- Customers). The exact rule for each segment is documented below --
-- these names are only applied where the R/F/M scores actually
-- support them, not applied by assumption.
-- Rule set (evaluated top to bottom, first match wins):
--   Champions            : recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
--   Loyal Customers       : recency_score >= 3 AND frequency_score >= 3
--   Potential Loyalists   : recency_score >= 4 AND frequency_score <= 2
--   At Risk               : recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 3)
--   Lost Customers        : recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2
--   Needs Attention       : catch-all for any combination not matched above
--
-- PHASE 5 FIX (found via Python/SQL reconciliation, see
-- docs/python_analytics.md section "SQL/Python Consistency"):
-- NTILE(5) partitions by ROW POSITION, not by value -- with ties in
-- frequency/monetary (common; these are often small integers/repeated
-- totals), rows with the IDENTICAL value can land in different
-- buckets purely based on scan order, which is undefined without an
-- explicit secondary ORDER BY key. Added `customer_id` as a
-- deterministic tiebreaker to every NTILE() call below so this view's
-- output is reproducible run-to-run, and so the Python implementation
-- in python/rfm_analysis.py (which replicates NTILE's row-position
-- bucketing algorithm exactly, using the same tiebreaker) can be
-- verified against it. This does NOT change the RFM methodology itself
-- (still row-position-based quantiles, matching the standard NTILE
-- approach), only removes the non-determinism.
-- ============================================================

create or replace view customer_rfm as
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
        -- Recency: fewer days = better = higher score, so invert the
        -- NTILE order (most recent gets ntile 5). `customer_id` added
        -- as a secondary ORDER BY key purely for deterministic tie-
        -- breaking (see PHASE 5 FIX note above) -- it does not affect
        -- the primary ordering by recency_days/frequency/monetary.
        (6 - ntile(5) over (order by recency_days, customer_id)) as recency_score,
        ntile(5) over (order by frequency, customer_id)          as frequency_score,
        ntile(5) over (order by monetary, customer_id)           as monetary_score
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
from rfm_scored;
