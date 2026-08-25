-- Domain: Customers
-- Source: queries/hard_questions.sql (Q1)
-- Question: Rank customers by total spending using window functions

with customer_total_spendings as (
    select c.customer_id, c.customer_name, sum(total_price_usd) as total_spending
    from customers c
    inner join orders o on c.customer_id = o.customer_id
    inner join order_items oi on o.order_id = oi.order_id
    group by c.customer_id, c.customer_name
),
customer_rank as (
    select *, rank() over (order by total_spending desc) as customer_ranking
    from customer_total_spendings
)
select * from customer_rank limit 5;
