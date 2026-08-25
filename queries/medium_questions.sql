-- ============================================================
-- MEDIUM LEVEL QUERIES
-- Global E-Commerce SQL Analysis
-- Concepts: JOIN, GROUP BY, HAVING, Aggregations,
--           Multi-table joins, WHERE vs HAVING
-- ============================================================


-- Q1: Find total revenue per product category
-- Concepts: JOIN, GROUP BY, SUM

select floor(sum(o.total_price_usd)) as Total_revenue_usd, p.category 
from order_items o 
left join products p on o.product_id=p.product_id 
group by p.category 
order by Total_revenue_usd desc;

/*
Result:
| Category    | Total Revenue  |
|-------------|----------------|
| Electronics | $104,138,855   |
| Home        | $65,329,673    |
| Sports      | $54,355,229    |
| Health      | $42,765,644    |
| Clothing    | $33,754,419    |

Insight: Electronics is the highest-grossing category, generating over $104M
in revenue and outperforming the next closest category (Home) by ~59%.
The top 3 categories account for the majority of total revenue.
*/


-- Q2: Count the number of orders per customer segment
-- Concepts: JOIN, GROUP BY, COUNT

select count(o.order_id) as total_orders,c.customer_segment 
from customers c 
left join orders o on c.customer_id=o.customer_id 
group by c.customer_segment 
order by total_orders desc;

/*
Result:
| Segment  | Total Orders |
|----------|--------------|
| Regular  | 446,152      |
| Premium  | 223,643      |
| VIP      | 74,648       |

Insight: Regular customers account for ~59% of total orders, nearly double
Premium (30%). VIP is the smallest segment at ~10% by order count — though
likely the highest by average order value.
*/


-- Q3: Calculate average delivery days by shipping method
-- Concepts: GROUP BY, AVG, ROUND

select round(avg(delivery_days),2) as avg_delivery_days, shipping_method 
from shipping 
group by shipping_method 
order by avg_delivery_days asc;

/*
Result:
| Shipping Method | Avg Delivery Days |
|-----------------|-------------------|
| Economy         | 7.50              |
| Standard        | 7.50              |
| Express         | 7.51              |
| Next Day        | 7.52              |

Insight: All shipping methods deliver in ~7.5 days with only 0.02 day variance.
"Next Day" averaging 7.52 days indicates a data quality concern — this is
characteristic of synthetic data generation.
*/


-- Q4: Find the top 5 best-selling products by quantity sold
-- Concepts: INNER JOIN, GROUP BY, SUM, ORDER BY, LIMIT

select p.product_id, p.product_name, sum(oi.quantity) as quantity_sold 
from products p
inner join  order_items oi on p.product_id = oi.product_id
group by p.product_id, p.product_name
order by quantity_sold desc
limit 5;

-- Note: INNER JOIN used here (not LEFT JOIN) because we only
-- want products that have actually sold. LEFT JOIN would keep
-- unsold products with NULL quantities.


-- Q5: Show total profit and revenue per order year
-- Concepts: INNER JOIN, GROUP BY, SUM, multiple aggregates

select o.order_year,sum(i.total_price_usd) as Total_revenue,sum(i.profit_usd) as Total_profits,
round(sum(i.profit_usd)/sum(i.total_price_usd)*100, 2) as profit_margin_pct
from orders o 
inner join order_items i on o.order_id=i.order_id 
group by o.order_year;

/*
Result:
| Year | Total Revenue   | Total Profit   | Margin |
|------|-----------------|----------------|--------|
| 2024 | $136,822,045    | $54,614,287    | 39.92% |
| 2025 | $149,990,667    | $59,857,425    | 39.91% |
| 2026 | $13,531,108     | $5,402,758     | 39.93% |

*2026 is partial data (Jan-Feb only)

Insight: Revenue grew ~10% from 2024 to 2025 while margins remained stable
at ~40%, suggesting efficient scaling without cost inflation.
*/


-- Q6: Find the most common payment method among VIP customers
-- Concepts: 3-table JOIN, GROUP BY, COUNT, ORDER BY

select p.payment_method,count(p.order_id) as Total_orders 
from customers c 
inner join orders o on c.customer_id=o.customer_id 
inner join payments p on o.order_id=p.order_id 
where c.customer_segment='VIP' 
group by p.payment_method 
order by Total_orders desc;

/*
Insight: All payment methods show near-equal distribution among VIP customers
(~14K-15K each), confirming synthetic data characteristics. In real data,
one or two methods would dominate. Business implication: support all payment
methods equally to avoid alienating any portion of the VIP base.
*/


-- Q7: List products with average review rating below 3 and more than 1 review
-- Concepts: INNER JOIN, GROUP BY, HAVING, multiple conditions
-- Note: Threshold adjusted from >50 to =1 due to synthetic dataset density

select p.product_id,p.product_name,r.rating,count(r.customer_feedback) 
from products p 
inner join reviews r on p.product_id=r.product_id
where r.rating <3 
group by r.rating,p.product_id,p.product_name 
having count(r.customer_feedback)=1 ;


-- Key concept: WHERE filters rows BEFORE grouping
--              HAVING filters groups AFTER grouping
-- Cannot use WHERE COUNT(...) > 1 — must use HAVING


-- Q8: Find orders where coupon was used AND payment failed
-- Concepts: INNER JOIN, WHERE, multiple conditions
select m.order_id, m.coupon_code, p.payment_status
from marketing m
inner join payments p on m.order_id = p.order_id
where m.coupon_used = 'Yes' 
and p.payment_status = 'Failed';

-- Note: LEFT JOIN would be incorrect here because filtering on
-- p.payment_status = 'Failed' cancels the LEFT JOIN effect.
-- INNER JOIN is the correct and honest choice.


-- Q9: Calculate total lost revenue from failed coupon payments
-- Concepts: 3-table JOIN, SUM, COUNT

select count(m.order_id) as Total_order_failed, sum(total_price_usd) as revenue_lost 
from marketing m 
inner join payments p on m.order_id=p.order_id
inner join order_items oi on p.order_id=oi.order_id
where (m.coupon_used='Yes') and (p.payment_status='Failed');

/*
Result:
| Total Orders Failed | Revenue Lost    |
|---------------------|-----------------|
| 18,513              | $7,445,393.63   |

Insight: 18,513 orders where customers actively applied a coupon still resulted
in failed payments, representing $7.4M in lost revenue. These customers
demonstrated the highest purchase intent — they found a coupon, applied it,
but never completed the transaction. A direct and quantifiable recovery
opportunity for the business.
*/


-- Q10: Calculate each customer's average order value
-- Concepts: Multi-table JOIN, subquery, GROUP BY, AVG
select c.customer_id, c.customer_name, c.customer_segment, round(avg(order_total), 2) as avg_order_value
from customers c
inner join orders o on c.customer_id = o.customer_id
inner join (
    select order_id, sum(total_price_usd) as order_total
    from order_items
    group by order_id
) oi on o.order_id = oi.order_id
group by c.customer_id, c.customer_name, c.customer_segment
order by avg_order_value desc;
