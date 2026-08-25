-- Domain: Products & Revenue
-- Source: queries/easy_questions.sql (Q10)
-- Question: Find all products in the Electronics category

select product_id, product_name, category from products where category = 'Electronics';
