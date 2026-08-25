-- Domain: Transactions
-- Source: queries/hard_questions.sql (Q5)
-- Question: Running total (cumulative) revenue per month

with current_revenue as (
    select o.order_year, o.order_month, sum(oi.total_price_usd) as monthly_revenue
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    group by o.order_year, o.order_month
)
select order_year, order_month, monthly_revenue,
       sum(monthly_revenue) over (
           order by order_year, order_month
           rows between unbounded preceding and current row
       ) as running_total
from current_revenue
order by order_year, order_month;
