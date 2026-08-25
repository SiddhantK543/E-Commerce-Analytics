-- Domain: Customers
-- Source: queries/easy_questions.sql (Q5)
-- Question: How many customers are in the database?

select count(customer_id) as total_customers from customers;
