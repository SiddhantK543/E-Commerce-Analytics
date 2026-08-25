-- Domain: Customers
-- Source: queries/medium_questions.sql (Q10)
-- Question: Calculate each customer's average order value

select c.customer_id, c.customer_name, c.customer_segment, round(avg(order_total), 2) as avg_order_value
from customers c
inner join orders o on c.customer_id = o.customer_id
inner join (
    select order_id, sum(total_price_usd) as order_total
    from order_items
    group by order_id
) oi on o.order_id = oi.order_id
group by c.customer_id, c.customer_name, c.customer_segment
order by avg_order_value desc;
