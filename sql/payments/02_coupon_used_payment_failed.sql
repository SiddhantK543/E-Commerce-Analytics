-- Domain: Payments
-- Source: queries/medium_questions.sql (Q8)
-- Question: Find orders where a coupon was used AND payment failed

select m.order_id, m.coupon_code, p.payment_status
from marketing m
inner join payments p on m.order_id = p.order_id
where m.coupon_used = 'Yes'
  and p.payment_status = 'Failed';

-- Note: INNER JOIN used deliberately. A LEFT JOIN would be undermined by
-- filtering on p.payment_status = 'Failed' immediately after.
