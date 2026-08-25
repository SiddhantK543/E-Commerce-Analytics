-- Domain: Data Quality
-- Checks: missing (NULL) values in fields that should generally be
-- populated, and invalid/impossible dates

-- 5a. Orders missing a status
select * from orders where order_status is null;

-- 5b. Customers missing an email or name
select * from customers where email is null or customer_name is null;

-- 5c. Orders with an impossible date (year/month/day combination that
-- MAKE_DATE cannot construct, e.g. month=13 or day=31 in a 30-day month)
-- This will raise an error rather than return rows if bad values exist --
-- run defensively / in a script that catches exceptions per row, or use
-- a bounds check first:
select *
from orders
where order_month < 1 or order_month > 12
   or order_day < 1 or order_day > 31
   or order_year < 2000 or order_year > extract(year from current_date)::int + 1;

-- 5d. Orders dated outside the documented dataset window (2024-2026).
-- Flags potential typos/import errors, not necessarily wrong per se.
select * from orders where order_year not in (2024, 2025, 2026);
