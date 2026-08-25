-- ============================================================
-- Domain: Products & Revenue
-- File: sql/products_revenue/pareto_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- BUSINESS PURPOSE: determine whether revenue concentration in this
-- business actually follows an "80/20" pattern (a small % of products
-- generating a large % of revenue), or something else entirely. The
-- classification below is DERIVED from the cumulative-percentage
-- window calculation, not assumed -- "80/20" is never claimed unless
-- the data genuinely shows it.
--
-- GRAIN: product grain, aggregated from order_items.
-- ============================================================

with product_revenue as (
    select
        p.product_id,
        p.product_name,
        p.category,
        sum(oi.total_price_usd) as product_revenue
    from order_items oi
    inner join products p on oi.product_id = p.product_id
    group by p.product_id, p.product_name, p.category
),
ranked as (
    select
        *,
        rank() over (order by product_revenue desc) as revenue_rank,
        row_number() over (order by product_revenue desc) as product_sequence,
        count(*) over () as total_product_count
    from product_revenue
),
with_pct as (
    select
        *,
        round(100.0 * product_revenue / sum(product_revenue) over (), 2) as revenue_pct,
        round(
            100.0 * sum(product_revenue) over (order by product_revenue desc
                rows between unbounded preceding and current row)
            / sum(product_revenue) over (),
            2
        ) as cumulative_revenue_pct,
        round(100.0 * product_sequence / total_product_count, 2) as cumulative_product_pct
    from ranked
)
select
    product_id,
    product_name,
    category,
    round(product_revenue, 2) as product_revenue,
    revenue_rank,
    revenue_pct,
    cumulative_revenue_pct,
    cumulative_product_pct,
    -- Classification derived directly from the cumulative percentages
    -- above, not assumed. A product is a "Top revenue contributor" if
    -- it falls within the cumulative 80% of revenue AND within the
    -- first 20% of the product count -- the literal Pareto test. If
    -- no products satisfy both conditions simultaneously, this
    -- classification will legitimately show zero "Top" contributors,
    -- which is itself a valid (if less dramatic) finding.
    case
        when cumulative_revenue_pct <= 80 and cumulative_product_pct <= 20 then 'Top Revenue Contributor (Pareto Zone)'
        when cumulative_revenue_pct <= 95 then 'Mid-Tier Contributor'
        else 'Long-Tail Product'
    end as pareto_classification
from with_pct
order by revenue_rank;

-- ============================================================
-- CAVEAT: with only 5 products in the Phase 2/3 synthetic test
-- dataset, a true 80/20 pattern (a small fraction of SKUs driving
-- most revenue) cannot meaningfully emerge -- 20% of 5 products is 1
-- product, and whether that one product's revenue share happens to
-- cross 80% is closer to chance than a structural finding at this
-- scale. The window-function logic above is correct and grain-safe;
-- run it against the real ~1M-row/full-catalog dataset to get a
-- genuine Pareto read, and do not treat the test-data output as a
-- confirmed "80/20" (or "not 80/20") business finding.
-- ============================================================
