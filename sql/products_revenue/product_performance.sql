-- ============================================================
-- Domain: Products & Revenue
-- File: sql/products_revenue/product_performance.sql
-- Phase 4: Advanced SQL Business Analytics
--
-- BUSINESS PURPOSE: product- and category-level performance ranking
-- for the Product & Revenue dashboard page -- top/bottom performers,
-- revenue/profit contribution, and return/cancellation behavior.
--
-- GRAIN: product grain (aggregated from order_items, the correct
-- transaction-value source) unless otherwise noted. Distinct from
-- sql/products_revenue/04_revenue_per_category.sql (category grain,
-- no ranking) and 05_top5_bestselling_by_quantity.sql (quantity only,
-- no revenue/profit/ranking) -- this file consolidates ranking,
-- revenue AND profit contribution, and return behavior in one place
-- rather than duplicating those simpler queries.
-- ============================================================


-- 1. Top products by revenue, with RANK() and DENSE_RANK()
select
    p.product_id,
    p.product_name,
    p.category,
    round(sum(oi.total_price_usd), 2) as total_revenue,
    rank() over (order by sum(oi.total_price_usd) desc) as revenue_rank,
    dense_rank() over (order by sum(oi.total_price_usd) desc) as revenue_dense_rank
from order_items oi
inner join products p on oi.product_id = p.product_id
group by p.product_id, p.product_name, p.category
order by total_revenue desc;

-- ------------------------------------------------------------------

-- 2. Top products by quantity sold
select
    p.product_id,
    p.product_name,
    p.category,
    sum(oi.quantity) as total_quantity_sold,
    rank() over (order by sum(oi.quantity) desc) as quantity_rank
from order_items oi
inner join products p on oi.product_id = p.product_id
group by p.product_id, p.product_name, p.category
order by total_quantity_sold desc;

-- ------------------------------------------------------------------

-- 3. Top categories by revenue, with rank
select
    p.category,
    round(sum(oi.total_price_usd), 2) as total_revenue,
    rank() over (order by sum(oi.total_price_usd) desc) as category_revenue_rank
from order_items oi
inner join products p on oi.product_id = p.product_id
group by p.category
order by total_revenue desc;

-- ------------------------------------------------------------------

-- 4. Bottom-performing products by revenue (ascending rank -- the
-- tail of the same ranking as query 1, isolated for a "bottom N"
-- dashboard visual)
select
    p.product_id,
    p.product_name,
    p.category,
    round(sum(oi.total_price_usd), 2) as total_revenue,
    rank() over (order by sum(oi.total_price_usd) asc) as bottom_revenue_rank
from order_items oi
inner join products p on oi.product_id = p.product_id
group by p.product_id, p.product_name, p.category
order by total_revenue asc;

-- ------------------------------------------------------------------

-- 5. Average selling price per product (distinct from unit_price_usd,
-- which is the LISTED price per line item -- this is the actual
-- average REALIZED price per unit after discounts, i.e.
-- total_price_usd / quantity, averaged across all sales of that
-- product)
select
    p.product_id,
    p.product_name,
    round(avg(oi.total_price_usd / nullif(oi.quantity, 0)), 2) as avg_realized_selling_price,
    round(avg(oi.unit_price_usd), 2) as avg_listed_unit_price
from order_items oi
inner join products p on oi.product_id = p.product_id
group by p.product_id, p.product_name
order by avg_realized_selling_price desc;

-- ------------------------------------------------------------------

-- 6. Revenue contribution % per product (of total business revenue)
with product_revenue as (
    select p.product_id, p.product_name, sum(oi.total_price_usd) as product_revenue
    from order_items oi
    inner join products p on oi.product_id = p.product_id
    group by p.product_id, p.product_name
)
select
    product_id,
    product_name,
    round(product_revenue, 2) as product_revenue,
    round(100.0 * product_revenue / sum(product_revenue) over (), 2) as pct_of_total_revenue
from product_revenue
order by product_revenue desc;

-- ------------------------------------------------------------------

-- 7. Profit contribution % per product
with product_profit as (
    select p.product_id, p.product_name, sum(oi.profit_usd) as product_profit
    from order_items oi
    inner join products p on oi.product_id = p.product_id
    group by p.product_id, p.product_name
)
select
    product_id,
    product_name,
    round(product_profit, 2) as product_profit,
    round(100.0 * product_profit / nullif(sum(product_profit) over (), 0), 2) as pct_of_total_profit
from product_profit
order by product_profit desc;

-- ------------------------------------------------------------------

-- 8. Product return/cancellation behavior: what share of each
-- product's line items appear in a Returned or Cancelled order.
-- GRAIN NOTE: deliberately at the order_items grain here (not
-- order-level), since a return/cancellation is meaningful per
-- product within a multi-item order, not just per order.
select
    p.product_id,
    p.product_name,
    count(*) as total_line_items,
    sum(case when o.order_status in ('Returned', 'Cancelled') then 1 else 0 end) as returned_or_cancelled_line_items,
    round(
        100.0 * sum(case when o.order_status in ('Returned', 'Cancelled') then 1 else 0 end) / count(*),
        2
    ) as return_cancellation_rate_pct
from order_items oi
inner join products p on oi.product_id = p.product_id
inner join orders o on oi.order_id = o.order_id
group by p.product_id, p.product_name
order by return_cancellation_rate_pct desc;
