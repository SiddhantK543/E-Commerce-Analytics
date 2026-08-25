-- Domain: Customers
-- Source: queries/easy_questions.sql (Q9)
-- Question: Count number of customers per country

select count(customer_id), country from customers group by country order by count desc;
