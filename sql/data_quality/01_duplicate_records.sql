-- Domain: Data Quality
-- Checks: duplicate orders, duplicate order/product combinations
-- Philosophy: FLAG, do not silently delete. Deduplication decisions
-- should be reviewed by a human before any row is removed.

-- 1a. Duplicate order_id rows in the raw orders staging table
--     (run against the staging table before load, per README's
--     staging-table deduplication approach)
select order_id, count(*) as occurrence_count
from orders_staging
group by order_id
having count(*) > 1
order by occurrence_count desc;

-- 1b. Duplicate order_id in customers (should be impossible post-PK,
--     but useful to run against a staging/raw table pre-load)
select customer_id, count(*) as occurrence_count
from customers_staging
group by customer_id
having count(*) > 1
order by occurrence_count desc;

-- 1c. Duplicate product_id in a raw/staging products table
select product_id, count(*) as occurrence_count
from products_staging
group by product_id
having count(*) > 1
order by occurrence_count desc;

-- 1d. Duplicate (order_id, product_id) combinations in order_items
--     staging (this is the composite PK in the final schema, so any
--     duplicates here must be resolved before load)
select order_id, product_id, count(*) as occurrence_count
from order_items_staging
group by order_id, product_id
having count(*) > 1
order by occurrence_count desc;

-- NOTE: *_staging tables are the raw, unconstrained load targets
-- described in README's "Staging Table Approach for Deduplication".
-- They are not part of the final constrained schema in
-- schema/create_tables.sql. Create them per that README section before
-- running these checks.
