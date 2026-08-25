-- Domain: Data Quality
-- Checks: payments without orders, shipping records without orders,
-- reviews without matching orders/products
-- Added in Phase 3 to close a gap in 02_orphan_and_missing_key_records.sql
-- (which covered orders->customers and order_items->orders/products,
-- but not the remaining satellite tables). Run against staging tables
-- pre-load; FK constraints make these impossible post-load in the
-- final schema.

-- 8a. Payments referencing an order_id that doesn't exist in orders
select p.*
from payments_staging p
left join orders_staging o on p.order_id = o.order_id
where o.order_id is null;

-- 8b. Shipping records referencing an order_id that doesn't exist in orders
select s.*
from shipping_staging s
left join orders_staging o on s.order_id = o.order_id
where o.order_id is null;

-- 8c. Reviews referencing an order_id that doesn't exist in orders
select r.*
from reviews_staging r
left join orders_staging o on r.order_id = o.order_id
where o.order_id is null;

-- 8d. Reviews referencing a product_id that doesn't exist in products
select r.*
from reviews_staging r
left join products_staging p on r.product_id = p.product_id
where p.product_id is null;

-- 8e. Marketing records referencing an order_id that doesn't exist
select m.*
from marketing_staging m
left join orders_staging o on m.order_id = o.order_id
where o.order_id is null;

-- 8f. Orders that have NO matching order_items at all (an order header
-- with no line items -- not a broken FK, but a business-logic
-- anomaly worth flagging: what does a $0 order represent?)
select o.order_id
from orders o
left join order_items oi on o.order_id = oi.order_id
where oi.order_id is null;

-- 8g. Orders that have NO matching payment record (every order should
-- have exactly one payment attempt recorded)
select o.order_id
from orders o
left join payments p on o.order_id = p.order_id
where p.order_id is null;
