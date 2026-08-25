-- Domain: Data Quality
-- Checks: invalid order statuses, invalid payment statuses, invalid
-- ratings
-- Purpose: no CHECK/enum constraints exist in the schema for these
-- columns, so unexpected values can silently enter the database.
-- These queries surface the ACTUAL distinct values present so a
-- CHECK constraint / valid-value list can be defined confidently
-- (rather than guessing/assuming values, per audit finding E-9).

-- 3a. Distinct order_status values actually present
select order_status, count(*) as order_count
from orders
group by order_status
order by order_count desc;

-- 3b. Distinct payment_status values actually present
select payment_status, count(*) as order_count
from payments
group by payment_status
order by order_count desc;

-- 3c. Distinct shipping_status values actually present
select shipping_status, count(*) as order_count
from shipping
group by shipping_status
order by order_count desc;

-- 3d. Ratings outside the expected 1-5 range (reviews.rating)
select * from reviews where rating < 1 or rating > 5;

-- 3e. Ratings outside the expected 1-5 range (products.product_rating_avg)
select * from products where product_rating_avg < 1 or product_rating_avg > 5;
