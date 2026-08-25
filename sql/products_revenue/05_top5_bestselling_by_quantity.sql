-- Domain: Products & Revenue
-- Source: queries/medium_questions.sql (Q4)
-- Question: Find the top 5 best-selling products by quantity sold

select p.product_id, p.product_name, sum(oi.quantity) as quantity_sold
from products p
inner join order_items oi on p.product_id = oi.product_id
group by p.product_id, p.product_name
order by quantity_sold desc
limit 5;

-- Note: INNER JOIN used deliberately so only products that have actually
-- sold are returned (a LEFT JOIN would include unsold products with
-- NULL quantities).
