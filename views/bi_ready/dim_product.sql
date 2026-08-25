-- BI-ready dimension: dim_product
-- One row per product. Pass-through view for a stable BI connection
-- point.

create or replace view dim_product as
select
    product_id,
    product_name,
    category,
    brand,
    product_rating_avg,
    stock_quantity
from products;
