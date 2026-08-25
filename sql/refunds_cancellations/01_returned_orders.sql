-- Domain: Refunds & Cancellations
-- Source: queries/easy_questions.sql (Q3)
-- Question: Show all orders that were returned

select * from orders where order_status = 'Returned';
