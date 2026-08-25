-- Domain: Payments
-- NEW query added in Phase 2 to round out payment-health coverage
-- (the original project only analyzed the coupon+failed intersection,
-- not overall payment success/failure health).
-- Question: What is the overall success/failure rate by payment method?
-- Not yet executed against the dataset; no fabricated result numbers below.

select
    payment_method,
    payment_status,
    count(*) as order_count,
    round(
        100.0 * count(*) / sum(count(*)) over (partition by payment_method),
        2
    ) as pct_of_method
from payments
group by payment_method, payment_status
order by payment_method, payment_status;
