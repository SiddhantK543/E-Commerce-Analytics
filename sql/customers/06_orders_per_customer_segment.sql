-- Domain: Customers
-- Source: queries/medium_questions.sql (Q2)
-- Question: Count the number of orders per customer segment

select count(o.order_id) as total_orders, c.customer_segment
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.customer_segment
order by total_orders desc;

/*
Result (from original audit):
| Segment  | Total Orders |
|----------|--------------|
| Regular  | 446,152      |
| Premium  | 223,643      |
| VIP      | 74,648       |

Insight: Regular customers account for ~59% of total orders, nearly double
Premium (30%). VIP is the smallest segment at ~10% by order count.
*/
