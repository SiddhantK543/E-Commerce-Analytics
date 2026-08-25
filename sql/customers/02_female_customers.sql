-- Domain: Customers
-- Source: queries/easy_questions.sql (Q2)
-- Question: Find all female customers

select customer_id, customer_name, gender from customers where gender = 'Female';
