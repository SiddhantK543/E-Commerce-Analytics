-- Domain: Churn
-- NEW query added in Phase 2 to break the single existing churn query
-- down by customer segment, since retention strategy differs by segment
-- (Regular vs Premium vs VIP).
-- Question: What is the churn rate (6+ months inactive) within each
-- customer segment?
-- Not yet executed against the dataset; no fabricated result numbers below.

with customer_last_order as (
    select c.customer_id, c.customer_segment,
           max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date
    from customers c
    inner join orders o on c.customer_id = o.customer_id
    group by c.customer_id, c.customer_segment
),
reference_date as (
    select max(make_date(order_year, order_month, order_day)) as latest_order
    from orders
)
select
    clo.customer_segment,
    count(*) as total_customers,
    sum(case when clo.last_order_date < rd.latest_order - interval '6 months' then 1 else 0 end) as churned_customers,
    round(
        100.0 * sum(case when clo.last_order_date < rd.latest_order - interval '6 months' then 1 else 0 end)
        / count(*),
        2
    ) as churn_rate_pct
from customer_last_order clo
cross join reference_date rd
group by clo.customer_segment
order by churn_rate_pct desc;
