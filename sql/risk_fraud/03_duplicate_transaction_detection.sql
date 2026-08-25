-- ============================================================
-- Domain: Risk / Fraud
-- File: sql/risk_fraud/03_duplicate_transaction_detection.sql
-- Added in Phase 3.
--
-- PURPOSE: flag CANDIDATE duplicate transactions -- line items that
-- share the same customer, product, amount, order date, and payment
-- method. This is a HEURISTIC, not a confirmed-fraud determination.
--
-- IMPORTANT DISTINCTION (see docs/business_definitions.md):
--   Duplicate candidate  = matches on the criteria below; could be a
--                          genuine repeat purchase (e.g. buying the
--                          same product twice on the same day) OR a
--                          double-submitted/duplicated transaction.
--   Confirmed fraud      = NOT determined by this query. A human (or
--                          a dedicated investigation workflow) must
--                          review flagged rows before any action is
--                          taken.
--
-- GRAIN: this operates at the order_items (line-item) grain
-- deliberately, since "same product, same amount" is a line-item-
-- level concept, not an order-header-level one.
-- ============================================================

with candidate_lines as (
    select
        oi.order_id,
        oi.product_id,
        oi.total_price_usd,
        o.customer_id,
        o.order_year,
        o.order_month,
        o.order_day,
        p.payment_method
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join payments p on o.order_id = p.order_id
),
flagged as (
    select
        *,
        count(*) over (
            partition by customer_id, product_id, total_price_usd,
                         order_year, order_month, order_day, payment_method
        ) as matching_transaction_count
    from candidate_lines
)
select
    order_id,
    customer_id,
    product_id,
    total_price_usd,
    make_date(order_year, order_month, order_day) as order_date,
    payment_method,
    matching_transaction_count,
    (matching_transaction_count > 1) as possible_duplicate_flag,
    case
        when matching_transaction_count > 1 then
            'Matches ' || (matching_transaction_count - 1) ||
            ' other transaction(s) with the same customer, product, amount, ' ||
            'order date, and payment method. Review before treating as fraud.'
        else 'No matching transactions found.'
    end as duplicate_flag_reason
from flagged
where matching_transaction_count > 1
order by customer_id, product_id, order_date;

-- NOTE: matching on the exact (customer, product, amount, date,
-- payment method) tuple is intentionally strict to minimize false
-- positives. A looser match (e.g. same customer + amount within a
-- +/-1 day window) would catch more candidates but also more
-- legitimate repeat purchases; the stricter version here is the
-- explainable starting point. Loosening the match is a tuning
-- decision to revisit once real data volume/patterns are known.
