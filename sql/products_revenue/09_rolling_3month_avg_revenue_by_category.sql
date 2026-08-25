-- Domain: Products & Revenue
-- Source: queries/hard_questions.sql (Q10)
-- Question: 3-month rolling average revenue per product category
-- FIX: original had a misplaced parenthesis causing a syntax error
-- (the window function must be fully closed before the ::numeric cast).

with monthly_category_revenue as (
    select p.category, o.order_year, o.order_month,
           sum(oi.total_price_usd) as monthly_revenue
    from order_items oi
    inner join products p on oi.product_id = p.product_id
    inner join orders o on oi.order_id = o.order_id
    group by p.category, o.order_year, o.order_month
)
select category, order_year, order_month, monthly_revenue,
    round(
        avg(monthly_revenue) over (
            partition by category
            order by order_year, order_month
            rows between 2 preceding and current row
        )::numeric, 2
    ) as rolling_avg_3month
from monthly_category_revenue
order by category, order_year, order_month;
