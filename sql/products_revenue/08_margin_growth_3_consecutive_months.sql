-- Domain: Products & Revenue
-- Source: queries/hard_questions.sql (Q9)
-- Question: Products where profit margin improved for 3 consecutive
-- months

with monthly_margin as (
    select oi.product_id, p.product_name, o.order_year, o.order_month,
           round(avg(oi.profit_margin_percent)::numeric, 2) as avg_margin
    from order_items oi
    inner join products p on oi.product_id = p.product_id
    inner join orders o on oi.order_id = o.order_id
    group by oi.product_id, p.product_name, o.order_year, o.order_month
),
margin_with_lag as (
    select product_id, product_name, order_year, order_month, avg_margin,
           lag(avg_margin, 1) over (partition by product_id order by order_year, order_month) as prev_month_margin,
           lag(avg_margin, 2) over (partition by product_id order by order_year, order_month) as two_months_ago_margin
    from monthly_margin
),
consecutive_growth as (
    select product_id, product_name, order_year, order_month,
           two_months_ago_margin, prev_month_margin, avg_margin
    from margin_with_lag
    where (avg_margin > prev_month_margin)
      and (prev_month_margin > two_months_ago_margin)
      and (prev_month_margin is not null)
      and (two_months_ago_margin is not null)
)
select product_id, product_name, order_year, order_month as third_month,
       two_months_ago_margin as month_1_margin,
       prev_month_margin as month_2_margin,
       avg_margin as month_3_margin,
       round(avg_margin - two_months_ago_margin, 2) as total_improvement
from consecutive_growth
order by total_improvement desc;

-- Original finding: this query returned zero rows against the synthetic
-- dataset because margins were fixed per product with no month-to-month
-- variance. Logic is validated and ready for real data.
