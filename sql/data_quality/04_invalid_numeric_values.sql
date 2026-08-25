-- Domain: Data Quality
-- Checks: invalid quantities, invalid prices, impossible transaction
-- values

-- 4a. Non-positive or NULL quantities
select * from order_items where quantity is null or quantity <= 0;

-- 4b. Non-positive or NULL unit prices
select * from order_items where unit_price_usd is null or unit_price_usd <= 0;

-- 4c. Negative discount, tax, or cost values (should never be negative)
select *
from order_items
where discount_amount_usd < 0
   or tax_usd < 0
   or cost_usd < 0;

-- 4d. Discount percent outside a plausible 0-100 range
select * from order_items where discount_percent < 0 or discount_percent > 100;

-- 4e. Internal consistency check: does total_price_usd reconcile with
-- (unit_price_usd * quantity) - discount_amount_usd + tax_usd within a
-- small rounding tolerance? Large mismatches indicate a calculation or
-- import error.
select
    order_id, product_id, unit_price_usd, quantity, discount_amount_usd,
    tax_usd, total_price_usd,
    round(unit_price_usd * quantity - discount_amount_usd + tax_usd, 2) as expected_total,
    round(total_price_usd - (unit_price_usd * quantity - discount_amount_usd + tax_usd), 2) as variance
from order_items
where abs(total_price_usd - (unit_price_usd * quantity - discount_amount_usd + tax_usd)) > 1.00;

-- 4f. Negative or implausible fraud risk scores (schema defines
-- NUMERIC(5,2) with no bounds; expected conceptual range is 0-100)
select * from risk_management where fraud_risk_score < 0 or fraud_risk_score > 100;

-- 4g. Negative shipping cost or delivery days
select * from shipping where shipping_cost_usd < 0 or delivery_days < 0;

-- 4h. Negative or implausible customer age
select * from customers where age is not null and (age < 13 or age > 100);
