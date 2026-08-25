-- Domain: Shipping
-- Source: queries/easy_questions.sql (BONUS)
-- Question: Show all orders with a shipping cost greater than $50

select order_id, shipping_cost_usd from shipping where shipping_cost_usd >= 50;
