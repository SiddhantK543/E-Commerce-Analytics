-- Domain: Transactions
-- Source: queries/hard_questions.sql (Q2)
-- Question: Month-over-month revenue growth

with monthly_revenue as (
    select o.order_year, o.order_month, round(sum(oi.total_price_usd), 2) as revenue
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    group by o.order_year, o.order_month
    order by o.order_year, o.order_month
),
previous_month_revenue as (
    select *, lag(revenue, 1) over (order by order_year, order_month) as previous_revenue
    from monthly_revenue
),
growth_percentage as (
    select *, round((((revenue - previous_revenue) / previous_revenue) * 100), 2) as growth
    from previous_month_revenue
)
select * from growth_percentage
order by order_year asc, order_month asc;
