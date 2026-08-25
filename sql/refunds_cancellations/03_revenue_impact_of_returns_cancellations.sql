-- Domain: Refunds & Cancellations
-- NEW query added in Phase 2 to quantify the revenue impact of returns
-- and cancellations, extending the single existing "returned orders"
-- query into an actual business-impact analysis.
-- Question: What share of gross revenue is tied up in returned or
-- cancelled orders, broken out by order status?
-- Not yet executed against the dataset; no fabricated result numbers below.
-- CAVEAT: order_status has no CHECK/enum constraint in the schema, so the
-- exact set of valid status strings (e.g. whether cancellations are
-- labeled 'Cancelled', 'Canceled', or something else) is not confirmed.
-- Verify actual distinct values with:
--   select distinct order_status from orders;
-- before relying on this query's output. See sql/data_quality/ for the
-- corresponding validation check.

select
    o.order_status,
    count(distinct o.order_id) as order_count,
    round(sum(oi.total_price_usd), 2) as gross_revenue_affected,
    round(
        100.0 * sum(oi.total_price_usd) / sum(sum(oi.total_price_usd)) over (),
        2
    ) as pct_of_total_gross_revenue
from orders o
inner join order_items oi on o.order_id = oi.order_id
where o.order_status in ('Returned', 'Cancelled')
group by o.order_status
order by gross_revenue_affected desc;
