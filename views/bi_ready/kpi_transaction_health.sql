-- ============================================================
-- BI-ready analytical output: kpi_transaction_health
-- A single-row KPI summary intended for Power BI card visuals on the
-- "Executive Overview" and "Transaction & Payment Health" pages.
--
-- Built on top of vw_transaction_health (already grain-safe -- one row
-- per order with order_value/profit pre-aggregated), so no further
-- grain handling is needed here beyond simple SUM/COUNT/AVG over that
-- view's rows.
--
-- Definitions: see docs/business_definitions.md for the authoritative
-- wording of every metric below.
-- ============================================================

create or replace view kpi_transaction_health as
select
    count(*) as total_orders,
    round(sum(order_value), 2) as total_order_value,

    sum(case when transaction_status = 'Successful' then 1 else 0 end) as successful_orders,
    sum(case when transaction_status = 'Failed' then 1 else 0 end) as failed_orders,
    sum(case when transaction_status = 'Cancelled' then 1 else 0 end) as cancelled_orders,
    sum(case when transaction_status = 'Returned' then 1 else 0 end) as returned_orders,

    round(
        100.0 * sum(case when transaction_status = 'Successful' then 1 else 0 end)
        / nullif(count(*), 0), 2
    ) as payment_success_rate_pct,

    round(
        100.0 * sum(case when transaction_status = 'Failed' then 1 else 0 end)
        / nullif(count(*), 0), 2
    ) as payment_failure_rate_pct,

    round(
        100.0 * sum(case when transaction_status = 'Cancelled' then 1 else 0 end)
        / nullif(count(*), 0), 2
    ) as cancellation_rate_pct,

    round(
        100.0 * sum(case when transaction_status = 'Returned' then 1 else 0 end)
        / nullif(count(*), 0), 2
    ) as return_rate_pct,

    round(sum(potential_lost_value), 2) as potential_lost_revenue,
    round(sum(successful_value), 2) as total_successful_revenue,
    round(sum(affected_order_value), 2) as total_affected_order_value,

    round(avg(order_value), 2) as average_order_value

from vw_transaction_health;
