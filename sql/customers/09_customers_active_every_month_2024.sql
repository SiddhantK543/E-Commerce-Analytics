-- Domain: Customers (engagement / full-year retention)
-- Source: queries/hard_questions.sql (Q3)
-- Question: Customers who placed at least one order in every month of 2024
-- Related: sql/churn/ holds the inverse view (inactive customers)

with active_months as (
    select customer_id, count(distinct order_month) as months_ordered
    from orders
    where order_year = 2024
    group by customer_id
),
total_months as (
    select count(distinct order_month) as total_months
    from orders
    where order_year = 2024
)
select am.customer_id, c.customer_name, c.customer_segment, am.months_ordered
from active_months am
inner join customers c on am.customer_id = c.customer_id
cross join total_months tm
where am.months_ordered = tm.total_months
order by c.customer_segment;
