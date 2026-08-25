-- ============================================================
-- Domain: Customers
-- File: sql/customers/advanced_customer_analysis.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- BUSINESS PURPOSE: core customer-base metrics (totals, activity,
-- new vs. returning, frequency, value) and customer ranking, for the
-- Customer Analytics dashboard page.
--
-- GRAIN: customer grain throughout (one row per customer), built from
-- order_items aggregated to order_id first, then to customer_id --
-- this two-step aggregation avoids inflating customer revenue by the
-- number of line items per order.
--
-- "New" vs "returning" definition: a customer is "new" in a given
-- month if that month contains their first-ever order (see
-- sql/customers/cohort_retention.sql for the full cohort treatment of
-- this same concept). "Active" here means placed at least one order
-- in the period in question; this project has no login/session table
-- to define "active" independently of ordering.
--
-- "Customer lifetime value proxy": this project has no explicit CLV
-- model (no retention-probability or margin-forecast columns exist).
-- What is shown below is total historical revenue per customer, which
-- is a genuine LTV **input**, not a forward-looking LTV prediction --
-- labeled accordingly rather than claiming more than the data supports.
-- ============================================================


-- 1. Total customers, and customers who have placed at least one order
select
    (select count(*) from customers) as total_customers,
    (select count(distinct customer_id) from orders) as customers_with_at_least_one_order
;

-- ------------------------------------------------------------------

-- 2. New customers per month (first-order month = that customer's
-- cohort month; see cohort_retention.sql for the full cohort matrix)
with first_order as (
    select
        customer_id,
        min(make_date(order_year, order_month, order_day)) as first_order_date
    from orders
    group by customer_id
)
select
    date_trunc('month', first_order_date)::date as cohort_month,
    count(distinct customer_id) as new_customers
from first_order
group by date_trunc('month', first_order_date)
order by cohort_month;

-- ------------------------------------------------------------------

-- 3. Returning customers: customers with more than one distinct order
select
    count(*) as returning_customers
from (
    select customer_id
    from orders
    group by customer_id
    having count(distinct order_id) > 1
) repeat_customers;

-- ------------------------------------------------------------------

-- 4. Orders per customer, average order value per customer, total
-- customer revenue, and purchase frequency -- all in one customer-
-- grain table (order_items aggregated to order first, THEN to
-- customer, to avoid double counting)
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
),
customer_orders as (
    select
        o.customer_id,
        count(distinct o.order_id) as total_orders,
        sum(ov.order_value) as total_customer_revenue,
        round(avg(ov.order_value), 2) as avg_order_value,
        min(make_date(o.order_year, o.order_month, o.order_day)) as first_order_date,
        max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date
    from orders o
    left join order_value ov on o.order_id = ov.order_id
    group by o.customer_id
)
select
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    co.total_orders,
    round(co.total_customer_revenue, 2) as total_customer_revenue,
    co.avg_order_value,
    -- purchase frequency: orders per month of tenure (a simple rate,
    -- not a statistical frequency distribution). Guards against
    -- divide-by-zero for single-order customers (tenure = 0 months)
    -- by treating tenure of less than 1 month as 1 month.
    round(
        co.total_orders / greatest(
            (co.last_order_date - co.first_order_date) / 30.0, 1
        ),
        2
    ) as purchase_frequency_per_month,
    -- LTV proxy: total historical revenue -- an INPUT to LTV, not a
    -- forward-looking prediction (see file header note)
    round(co.total_customer_revenue, 2) as lifetime_value_proxy
from customers c
inner join customer_orders co on c.customer_id = co.customer_id
order by total_customer_revenue desc;

-- ------------------------------------------------------------------

-- 5. Customer ranking with RANK() and DENSE_RANK() by total revenue
-- (RANK leaves gaps after ties; DENSE_RANK does not -- shown side by
-- side to make the difference visible/explainable)
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
),
customer_revenue as (
    select
        o.customer_id,
        sum(ov.order_value) as total_customer_revenue
    from orders o
    left join order_value ov on o.order_id = ov.order_id
    group by o.customer_id
)
select
    c.customer_id,
    c.customer_name,
    round(cr.total_customer_revenue, 2) as total_customer_revenue,
    rank() over (order by cr.total_customer_revenue desc) as revenue_rank,
    dense_rank() over (order by cr.total_customer_revenue desc) as revenue_dense_rank
from customers c
inner join customer_revenue cr on c.customer_id = cr.customer_id
order by cr.total_customer_revenue desc;

-- ------------------------------------------------------------------

-- 6. Data-driven customer segments based on total revenue quartiles
-- (NTILE(4) -- distinct from the RFM segmentation in
-- sql/customers/rfm_analysis.sql, which uses three independent
-- dimensions rather than revenue alone; this is a simpler,
-- single-metric segmentation offered as an alternative/simpler view)
with order_value as (
    select order_id, sum(total_price_usd) as order_value
    from order_items
    group by order_id
),
customer_revenue as (
    select
        o.customer_id,
        sum(ov.order_value) as total_customer_revenue
    from orders o
    left join order_value ov on o.order_id = ov.order_id
    group by o.customer_id
)
select
    c.customer_id,
    c.customer_name,
    round(cr.total_customer_revenue, 2) as total_customer_revenue,
    ntile(4) over (order by cr.total_customer_revenue desc) as revenue_quartile,
    case ntile(4) over (order by cr.total_customer_revenue desc)
        when 1 then 'Top 25% by Revenue'
        when 2 then 'Upper-Mid 25%'
        when 3 then 'Lower-Mid 25%'
        when 4 then 'Bottom 25% by Revenue'
    end as revenue_segment
from customers c
inner join customer_revenue cr on c.customer_id = cr.customer_id
order by cr.total_customer_revenue desc;
