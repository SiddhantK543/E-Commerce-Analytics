-- Domain: Payments
-- Source: queries/medium_questions.sql (Q9)
-- Question: Calculate total lost revenue from failed coupon payments

select count(m.order_id) as total_orders_failed, sum(total_price_usd) as revenue_lost
from marketing m
inner join payments p on m.order_id = p.order_id
inner join order_items oi on p.order_id = oi.order_id
where (m.coupon_used = 'Yes') and (p.payment_status = 'Failed');

/*
Result (from original audit):
| Total Orders Failed | Revenue Lost    |
|----------------------|-----------------|
| 18,513               | $7,445,393.63   |
*/
