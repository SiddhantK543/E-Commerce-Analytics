-- BI-ready fact: fact_orders
-- Grain: one row per order (order header level).
-- Joins in the reconstructed order date against dim_date so Power BI
-- gets a genuine Date column instead of three separate integer parts.
-- Depends on: sql/date_dimension/create_dim_date.sql having been run
-- first.

create or replace view fact_orders as
select
    o.order_id,
    o.customer_id,
    dd.date_key       as order_date,
    o.order_year,
    o.order_month,
    o.order_day,
    o.order_status,
    o.return_reason
from orders o
left join dim_date dd
    on dd.date_key = make_date(o.order_year, o.order_month, o.order_day);

-- NOTE: LEFT JOIN (not INNER) so that an order with an invalid/
-- unparseable date still appears in the fact table with a NULL
-- order_date, rather than silently disappearing. Any rows with a NULL
-- order_date here should be investigated via
-- sql/data_quality/05_missing_values_and_invalid_dates.sql.
