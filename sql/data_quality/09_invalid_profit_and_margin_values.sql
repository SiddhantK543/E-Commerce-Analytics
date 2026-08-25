-- Domain: Data Quality
-- Checks: invalid profit values, invalid margins
-- Added in Phase 3 to make profit/margin validation explicit and
-- separate from the general numeric checks in
-- 04_invalid_numeric_values.sql (which only checked for negative
-- cost/discount/tax, not profit/margin specifically).

-- 9a. Profit that doesn't reconcile with total_price_usd - cost_usd
-- (the assumed formula, documented as an assumption in
-- docs/data_dictionary.md -- flag mismatches rather than assuming the
-- assumption is correct)
select
    order_id, product_id, total_price_usd, cost_usd, profit_usd,
    round(total_price_usd - cost_usd, 2) as expected_profit,
    round(profit_usd - (total_price_usd - cost_usd), 2) as variance
from order_items
where abs(profit_usd - (total_price_usd - cost_usd)) > 1.00;

-- 9b. Profit greater than the total price it was derived from (would
-- imply cost_usd is negative, or a calculation error)
select * from order_items where profit_usd > total_price_usd;

-- 9c. profit_margin_percent that doesn't reconcile with
-- profit_usd / total_price_usd * 100 (the assumed formula)
select
    order_id, product_id, profit_usd, total_price_usd, profit_margin_percent,
    round(profit_usd / nullif(total_price_usd, 0) * 100, 2) as expected_margin_pct,
    round(profit_margin_percent - (profit_usd / nullif(total_price_usd, 0) * 100), 2) as variance
from order_items
where total_price_usd <> 0
  and abs(profit_margin_percent - (profit_usd / nullif(total_price_usd, 0) * 100)) > 1.00;

-- 9d. Margin percent outside a plausible -100% to 100% range (a margin
-- below -100% or above 100% is not meaningful for a standard
-- profit-margin definition and likely indicates a data error)
select * from order_items where profit_margin_percent < -100 or profit_margin_percent > 100;

-- 9e. Orders with a NULL profit_usd or profit_margin_percent where
-- total_price_usd is populated (incomplete calculation upstream)
select * from order_items
where total_price_usd is not null
  and (profit_usd is null or profit_margin_percent is null);
