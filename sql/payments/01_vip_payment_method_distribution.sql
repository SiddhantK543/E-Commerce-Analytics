-- Domain: Payments
-- Source: queries/medium_questions.sql (Q6)
-- Question: Find the most common payment method among VIP customers

select p.payment_method, count(p.order_id) as total_orders
from customers c
inner join orders o on c.customer_id = o.customer_id
inner join payments p on o.order_id = p.order_id
where c.customer_segment = 'VIP'
group by p.payment_method
order by total_orders desc;
