-- BI-ready analytical output: cohort_retention
-- View wrapper around sql/customers/cohort_retention.sql -- see that
-- file for full grain/methodology documentation. Grain: one row per
-- (cohort_month, months_since_first_purchase), suitable for a Power BI
-- retention-matrix visual (cohort_month as rows, months_since_first_
-- purchase as columns, retention_rate_pct as the matrix value).

create or replace view cohort_retention as
with cohort_customers as (
    select
        customer_id,
        date_trunc('month', min(make_date(order_year, order_month, order_day)))::date as cohort_month
    from orders
    group by customer_id
),
customer_orders_with_cohort as (
    select
        o.customer_id,
        cc.cohort_month,
        date_trunc('month', make_date(o.order_year, o.order_month, o.order_day))::date as order_month
    from orders o
    inner join cohort_customers cc on o.customer_id = cc.customer_id
),
cohort_activity as (
    select distinct
        cohort_month,
        customer_id,
        (
            (extract(year from order_month) - extract(year from cohort_month)) * 12
            + (extract(month from order_month) - extract(month from cohort_month))
        )::int as months_since_first_purchase
    from customer_orders_with_cohort
),
cohort_sizes as (
    select cohort_month, count(distinct customer_id) as cohort_size
    from cohort_customers
    group by cohort_month
)
select
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_first_purchase,
    count(distinct ca.customer_id) as active_customers,
    round(100.0 * count(distinct ca.customer_id) / cs.cohort_size, 2) as retention_rate_pct
from cohort_activity ca
inner join cohort_sizes cs on ca.cohort_month = cs.cohort_month
group by ca.cohort_month, cs.cohort_size, ca.months_since_first_purchase;
