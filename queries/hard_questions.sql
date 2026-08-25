-- ============================================================
-- HARD LEVEL QUERIES
-- Global E-Commerce SQL Analysis
-- Concepts: CTEs, Window Functions (RANK, LAG, PERCENT_RANK,
--           SUM OVER, AVG OVER), Date Arithmetic, PARTITION BY,
--           Rolling Averages, Consecutive Pattern Detection
--
-- NOTE (fixed during repo hygiene pass):
--   - This file previously had its entire Q1-Q9 content duplicated.
--     The duplicate block has been removed; each query now appears once.
--   - Q3 and Q7 previously had no "-- Qn:" label. Q3's label has been
--     restored to match the README's table of contents. Q7 was
--     documented in the README ("First and last order per customer")
--     but was missing from this file entirely — it has been written
--     here to match the documented spec. It has not yet been executed
--     against the dataset, so no result/finding commentary is attached.
--   - Q10 had a syntax error (misplaced parenthesis around the
--     window function and the ::numeric cast) and a dangling,
--     unmatched block-comment closer at the end of the file. Both
--     have been fixed.
-- ============================================================


-- Q1: Rank customers by total spending using window functions

with customer_total_spendings as (
select c.customer_id,c.customer_name, sum(total_price_usd) as total_spending from customers c 
inner join orders o on c.customer_id=o.customer_id
inner join order_items oi on o.order_id=oi.order_id
group by c.customer_id,c.customer_name ),

customer_rank as (
select *,rank() over(order by total_spending desc) as customer_ranking from customer_total_spendings
)

select * from customer_rank limit 5;

------------------------------------------------------------------------------------------------------------
-- Q2: Month over month revenue growth

with monthly_revenue as (
select o.order_year, o.order_month, round(sum(oi.total_price_usd),2) as revenue from orders o 
inner join order_items oi on o.order_id=oi.order_id
group by o.order_year, o.order_month
order by o.order_year, o.order_month ),

previous_month_revenue as (
select *, lag(revenue,1) over(order by order_year, order_month) as previous_revenue
from monthly_revenue ),

growth_percentage as (
select *, round((((revenue-previous_revenue)/previous_revenue)*100),2) as growth 
from previous_month_revenue
)

select * from growth_percentage
order by order_year asc, order_month asc;

/*"Month-over-month revenue analysis across 24 months
(March 2024 — February 2026) shows remarkably stable revenue averaging approximately $12.5M per month with growth fluctuating between -10% and +15%.
The largest single month drop occurred in February 2026 at -94.53%,
which is attributed to incomplete data for that month rather than an actual business decline.
Excluding partial months, the business demonstrates consistent revenue generation with no significant growth or decline trend — a characteristic of the synthetic dataset used."
*/

-------------------------------------------------------------------------------------------------------------------------------
-- Q3: Customers who placed at least one order in every month of 2024

with active_months as (
select  customer_id, count(distinct order_month) as months_ordered
from orders
where order_year = 2024
group by customer_id),
total_months as (
select count(distinct order_month) as total_months
from orders
where order_year = 2024
)
select am.customer_id, c.customer_name, c.customer_segment, am.months_ordered
from active_months am
inner join customers c on am.customer_id = c.customer_id
cross join  total_months tm
where am.months_ordered = tm.total_months
order by  c.customer_segment;

--------------------------------------------------------------------------------------------------------------------------------
-- Q4: Find Products That Appear in Top 10 Revenue for at Least 3 Different Months

with Product_monthly_revenue as (
select p.product_id, p.product_name, o.order_year, o.order_month, sum(oi.total_price_usd) as monthly_total_revenue from products p 
inner join order_items oi on p.product_id=oi.product_id
inner join orders o on o.order_id=oi.order_id
group by p.product_id, p.product_name, o.order_year , o.order_month ),

Ranking_product_monthly_revenue as (
select *, rank() over(partition by order_year, order_month order by monthly_total_revenue desc) as monthly_ranking
from Product_monthly_revenue
),

Top_10_product as (
select product_id,product_name , count(*) as months_in_top10 from Ranking_product_monthly_revenue
where monthly_ranking <=10
group by product_id,product_name
)

select product_id,product_name, months_in_top10 from Top_10_product where months_in_top10 >=3 order by months_in_top10 desc;

-----------------------------------------------------------------------------------------------------------------------------------
-- Q5: Running total (cumulative) Revenue per month

with Current_revenue as (
select o.order_year, o.order_month, sum(oi.total_price_usd) as monthly_revenue from orders o 
inner join order_items oi on o.order_id=oi.order_id
group by o.order_year, o.order_month
)

select order_year, order_month,monthly_revenue, 
sum(monthly_revenue) over( order by order_year, order_month rows between unbounded preceding and current row) as running_total
from Current_revenue 
order by order_year, order_month;

/*"Cumulative revenue analysis shows consistent growth from March 2024 through February 2026,
crossing the $300M mark by February 2026.
The business generates approximately $50M in cumulative revenue every 4 months,
reflecting a stable and predictable revenue pattern.
Monthly revenue remains consistently between $11M–$13M throughout the entire period with no significant seasonal variation — a characteristic of the synthetic dataset."
*/

---------------------------------------------------------------------------------------------------------------------------------
-- Q6: Inactive users for past 6 months (churn)

with Customer_last_order as (
select c.customer_id,c.customer_name,c.customer_segment, 
max(make_date(o.order_year,o.order_month,o.order_day)) as Last_order_date from customers c 
inner join orders o on c.customer_id=o.customer_id
group by c.customer_id,c.customer_name,c.customer_segment
)
select * from Customer_last_order 
where Last_order_date<
(select max(make_date(order_year,order_month,order_day)) as latest_order from orders) - interval '6 months'
order by Last_order_date desc;

/*"Churn analysis identified 555,936 customers (approximately 70% of the customer base) who have not placed an order since August 2025,
relative to the dataset end date of February 2026.
This high churn rate is characteristic of the dataset's synthetic nature, where customer orders are randomly distributed across the full 2-year period rather than following real purchasing patterns.
In a real business context, a 70% churn rate would signal a critical retention problem requiring immediate intervention through reactivation campaigns, loyalty programs, and personalized outreach —
particularly targeting Premium and VIP segments where revenue recovery potential is highest."
*/

------------------------------------------------------------------------------------------------------------------------------
-- Q7: First and last order date per customer, with customer tenure
-- Concepts: MIN, MAX, DATE_PART, CASE WHEN
-- NOTE: This query was documented in the README's table of contents but
-- was missing from the original file. It is written here to match the
-- documented concepts and intent.
-- BUG FOUND & FIXED (Phase 3 testing): DATE - DATE returns an INTEGER
-- in PostgreSQL, not an INTERVAL, so DATE_PART('day', date - date)
-- errors. Fixed by casting both dates to TIMESTAMP before subtracting.

select
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    min(make_date(o.order_year, o.order_month, o.order_day)) as first_order_date,
    max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date,
    date_part(
        'day',
        max(make_date(o.order_year, o.order_month, o.order_day))::timestamp
        - min(make_date(o.order_year, o.order_month, o.order_day))::timestamp
    ) as customer_tenure_days,
    case
        when min(make_date(o.order_year, o.order_month, o.order_day))
             = max(make_date(o.order_year, o.order_month, o.order_day))
            then 'Single Order Customer'
        else 'Repeat Customer'
    end as customer_type
from customers c
inner join orders o on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name, c.customer_segment
order by customer_tenure_days desc;

------------------------------------------------------------------------------------------------------------------------------
-- Q8: Find Orders Where Fraud Risk Score is in Top 5% Per Country

with fraud_ranking as (
select rm.order_id, o.customer_id, c.customer_name, c.country, rm.order_priority, rm.fraud_risk_score,
percent_rank() over(partition by c.country order by rm.fraud_risk_score desc) as per_rank
from risk_management rm
inner join orders o on rm.order_id=o.order_id
inner join customers c on o.customer_id=c.customer_id
)

select order_id,customer_id,customer_name,country,order_priority, fraud_risk_score, round((per_rank*100)::numeric,2) as percentile
from fraud_ranking
where per_rank <= 0.05
order by country, fraud_risk_score;

------------------------------------------------------------------------------------------------------------------------------------------
-- Q9: Products where profit margin improved for 3 consecutive months

with monthly_margin as (
select oi.product_id,p.product_name, o.order_year, o.order_month, round(avg(oi.profit_margin_percent)::numeric, 2) as avg_margin
from order_items oi
inner join products p on oi.product_id = p.product_id
inner join orders o on oi.order_id = o.order_id
group by oi.product_id, p.product_name, o.order_year, o.order_month),

margin_with_lag as (
select product_id, product_name, order_year, order_month, avg_margin, 
lag(avg_margin, 1) over(partition by product_id order by order_year, order_month) as prev_month_margin,
lag(avg_margin, 2) over(partition by product_id order by order_year, order_month) as two_months_ago_margin
from monthly_margin),

consecutive_growth as (
select product_id, product_name, order_year, order_month, two_months_ago_margin, prev_month_margin, avg_margin
from margin_with_lag
where (avg_margin > prev_month_margin)and(prev_month_margin > two_months_ago_margin) and (prev_month_margin is not null) and (two_months_ago_margin is not null)
)
select product_id, product_name, order_year, order_month as third_month, two_months_ago_margin as month_1_margin, prev_month_margin as month_2_margin, avg_margin as month_3_margin,
round(avg_margin-two_months_ago_margin, 2) as total_improvement
from consecutive_growth
order by total_improvement desc;

/*"Consecutive profit margin growth analysis returned no results due to the synthetic dataset assigning fixed margin values per product — resulting in 0.00% variance across all months.
A diagnostic query confirmed all products maintain identical margins throughout the entire dataset period.
In a production environment, this analysis would surface products benefiting from supplier cost reductions, improved operational efficiency, or optimized pricing strategies.
The SQL logic using LAG(1) and LAG(2) with PARTITION BY product_id is validated and ready for deployment on real data."
*/

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q10: 3-month rolling average revenue per product category
-- FIX: original version had a misplaced closing parenthesis around the
-- window function and the ::numeric cast, causing a syntax error.
-- The window function must be fully closed before casting/rounding.

with monthly_category_revenue as (
select p.category, o.order_year, o.order_month, sum(oi.total_price_usd) as monthly_revenue
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
