-- Domain: Data Quality
-- Checks: duplicate payments, duplicate shipping records
-- Added in Phase 3 to close a gap: 01_duplicate_records.sql covered
-- customers/products/orders/order_items but not the 1:1 satellite
-- tables (payments, shipping). Same philosophy applies: FLAG, don't
-- delete. Run against staging tables before load -- payments.order_id
-- and shipping.order_id are PRIMARY KEY in the final constrained
-- schema, so duplicates cannot exist there post-load; this check is
-- only meaningful pre-load or against a raw dump.

-- 7a. Duplicate order_id in a raw/staging payments table
select order_id, count(*) as occurrence_count
from payments_staging
group by order_id
having count(*) > 1
order by occurrence_count desc;

-- 7b. Duplicate order_id in a raw/staging shipping table
select order_id, count(*) as occurrence_count
from shipping_staging
group by order_id
having count(*) > 1
order by occurrence_count desc;

-- 7c. Duplicate (order_id, product_id) in a raw/staging reviews table
-- (reviews shares order_items' composite grain)
select order_id, product_id, count(*) as occurrence_count
from reviews_staging
group by order_id, product_id
having count(*) > 1
order by occurrence_count desc;

-- NOTE: see sql/data_quality/README.md for the *_staging naming
-- convention this file assumes.
