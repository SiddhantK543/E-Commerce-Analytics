-- Domain: Data Quality
-- Checks: Yes/No fields stored as free text rather than boolean
-- Purpose: flag columns where a boolean concept is stored as VARCHAR,
-- and surface any values that are NOT a clean 'Yes'/'No' pair -- these
-- would break a later boolean cast/transformation.

-- 6a. marketing.coupon_used
select coupon_used, count(*) as row_count
from marketing
group by coupon_used
order by row_count desc;

-- 6b. user_behavior.abandoned_cart_before
select abandoned_cart_before, count(*) as row_count
from user_behavior
group by abandoned_cart_before
order by row_count desc;

-- 6c. payments.installment (stored as VARCHAR(10); unclear if it holds
-- 'Yes'/'No', an integer count, or something else -- this query exists
-- to determine that before any cleaning/casting decision is made)
select installment, count(*) as row_count
from payments
group by installment
order by row_count desc;

-- Cleaning decision (documented, not yet executed): once the actual
-- value sets above are confirmed, add a Python/SQL transformation step
-- (see python/data_cleaning.py) that casts clean Yes/No columns to
-- boolean and documents any unexpected values found rather than
-- silently coercing them.
