-- Domain: Products & Revenue
-- Source: queries/medium_questions.sql (Q7)
-- Question: List products with average review rating below 3 and more
-- than 1 review
-- Note: threshold adjusted from ">50" to "=1" in the original project
-- due to synthetic dataset review density; revisit this threshold once
-- real/full data volume is loaded.

select p.product_id, p.product_name, r.rating, count(r.customer_feedback)
from products p
inner join reviews r on p.product_id = r.product_id
where r.rating < 3
group by r.rating, p.product_id, p.product_name
having count(r.customer_feedback) = 1;
