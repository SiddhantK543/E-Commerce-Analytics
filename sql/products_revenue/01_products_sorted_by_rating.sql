-- Domain: Products & Revenue
-- Source: queries/easy_questions.sql (Q4)
-- Question: List products sorted by average rating (highest first)

select * from products order by product_rating_avg desc;
