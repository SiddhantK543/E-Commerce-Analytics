-- Domain: Products & Revenue
-- Source: queries/hard_questions.sql (Q4)
-- Question: Find products that appear in top-10 revenue for at least
-- 3 different months

with product_monthly_revenue as (
    select p.product_id, p.product_name, o.order_year, o.order_month,
           sum(oi.total_price_usd) as monthly_total_revenue
    from products p
    inner join order_items oi on p.product_id = oi.product_id
    inner join orders o on o.order_id = oi.order_id
    group by p.product_id, p.product_name, o.order_year, o.order_month
),
ranking_product_monthly_revenue as (
    select *, rank() over (
        partition by order_year, order_month
        order by monthly_total_revenue desc
    ) as monthly_ranking
    from product_monthly_revenue
),
top_10_products as (
    select product_id, product_name, count(*) as months_in_top10
    from ranking_product_monthly_revenue
    where monthly_ranking <= 10
    group by product_id, product_name
)
select product_id, product_name, months_in_top10
from top_10_products
where months_in_top10 >= 3
order by months_in_top10 desc;
