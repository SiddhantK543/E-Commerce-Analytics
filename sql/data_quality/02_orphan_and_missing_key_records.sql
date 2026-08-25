-- Domain: Data Quality
-- Checks: orphan records, missing customer IDs, missing product IDs
-- Run against the FINAL (constrained) schema. Because orders, order_items,
-- payments, shipping, etc. all declare REFERENCES constraints, true
-- orphans cannot exist post-load with FK enforcement ON -- these queries
-- are most useful when run against staging tables BEFORE constraints are
-- applied, to see what would be rejected/needs resolving.

-- 2a. Orders referencing a customer_id that doesn't exist in customers
select o.*
from orders_staging o
left join customers c on o.customer_id = c.customer_id
where c.customer_id is null;

-- 2b. Order items referencing an order_id that doesn't exist in orders
select oi.*
from order_items_staging oi
left join orders_staging o on oi.order_id = o.order_id
where o.order_id is null;

-- 2c. Order items referencing a product_id that doesn't exist in products
select oi.*
from order_items_staging oi
left join products_staging p on oi.product_id = p.product_id
where p.product_id is null;

-- 2d. Orders with a NULL customer_id
select * from orders_staging where customer_id is null;

-- 2e. Order items with a NULL product_id
select * from order_items_staging where product_id is null;
