-- BI-ready dimension: dim_customer
-- One row per customer. Straightforward pass-through of the customers
-- table (no heavy transformation needed at this grain) exposed as a
-- view so Power BI has a stable, explicitly-named object to connect to
-- rather than querying the base table directly.

create or replace view dim_customer as
select
    customer_id,
    customer_name,
    email,
    gender,
    age,
    country,
    city,
    customer_segment,
    loyalty_score,
    account_creation_date
from customers;
