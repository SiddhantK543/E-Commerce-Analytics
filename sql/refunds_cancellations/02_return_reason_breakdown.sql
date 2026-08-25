-- Domain: Refunds & Cancellations
-- NEW query added in Phase 2. The original project only had a single
-- "show returned orders" query and never explored the return_reason
-- column that already exists in the orders table. This closes that gap.
-- Question: What are the most common return reasons, and how many
-- orders fall into each?
-- Not yet executed against the dataset; no fabricated result numbers below.

select
    return_reason,
    count(*) as order_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_of_returns
from orders
where order_status = 'Returned'
  and return_reason is not null
group by return_reason
order by order_count desc;
