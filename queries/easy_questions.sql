--EASY LEVEL--

-- Q1: List all customers and their country
select customer_name,country from customers;

-- Q2: Find all female customers
select customer_id,customer_name,gender from customers where gender='Female';

-- Q3: Show all orders that were returned
select * from orders where order_status = 'Returned';

-- Q4: List products sorted by average rating (highest first)
select * from products order by product_rating_avg desc;

-- Q5: How many customers are in the database?
select count(customer_id) as Total_Customers from customers;

-- Q6: Find all orders placed in 2024
select * from orders where order_year=2024;

-- Q7: Show the top 10 most expensive products by unit price
select * from order_items order by unit_price_usd desc limit 10;

-- Q8: List distinct countries where customers are from
select distinct(country) from customers;

-- Q9: Count number of customers per country
select count(customer_id),country from customers group by country order by count desc;

-- Q10: Find all products in the Electronics category
select product_id,product_name,category from products where category = 'Electronics';

-- BONUS: Show all orders with a shipping cost greater than $50
select order_id,shipping_cost_usd from shipping where shipping_cost_usd >= 50;
