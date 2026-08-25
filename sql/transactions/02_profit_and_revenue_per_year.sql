-- Domain: Transactions
-- Source: queries/medium_questions.sql (Q5)
-- Question: Show total profit and revenue per order year

select o.order_year,
       sum(i.total_price_usd) as total_revenue,
       sum(i.profit_usd) as total_profit,
       round(sum(i.profit_usd) / sum(i.total_price_usd) * 100, 2) as profit_margin_pct
from orders o
inner join order_items i on o.order_id = i.order_id
group by o.order_year;

/*
Result (from original audit):
| Year | Total Revenue   | Total Profit   | Margin |
|------|-----------------|----------------|--------|
| 2024 | $136,822,045    | $54,614,287    | 39.92% |
| 2025 | $149,990,667    | $59,857,425    | 39.91% |
| 2026 | $13,531,108     | $5,402,758     | 39.93% |  (partial: Jan-Feb only)
*/
