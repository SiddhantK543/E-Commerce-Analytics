-- Domain: Products & Revenue
-- Source: queries/easy_questions.sql (Q7)
-- Question: Show the top 10 most expensive products by unit price

select * from order_items order by unit_price_usd desc limit 10;

-- CAVEAT (flagged during Phase 1 audit, preserved not rewritten):
-- This queries order_items.unit_price_usd, which returns the most
-- expensive LINE ITEMS, not the most expensive distinct PRODUCTS. The
-- same product can appear multiple times at different prices, and this
-- does not deduplicate by product_id. If a true "most expensive
-- distinct products" list is needed, join to products and use
-- DISTINCT ON (product_id) or MAX(unit_price_usd) grouped by product.
-- Left as-is here to preserve the original query rather than silently
-- rewriting working (if imprecisely named) SQL.
