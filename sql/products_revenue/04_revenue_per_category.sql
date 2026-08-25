-- Domain: Products & Revenue
-- Source: queries/medium_questions.sql (Q1)
-- Question: Find total revenue per product category

select floor(sum(o.total_price_usd)) as total_revenue_usd, p.category
from order_items o
left join products p on o.product_id = p.product_id
group by p.category
order by total_revenue_usd desc;

/*
Result (from original audit):
| Category    | Total Revenue  |
|-------------|----------------|
| Electronics | $104,138,855   |
| Home        | $65,329,673    |
| Sports      | $54,355,229    |
| Health      | $42,765,644    |
| Clothing    | $33,754,419    |
*/
