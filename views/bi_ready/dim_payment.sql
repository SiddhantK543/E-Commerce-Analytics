-- BI-ready dimension: dim_payment
-- One row per order's payment details. Kept separate from
-- fact_orders so Power BI can slice by payment_method/status without
-- widening the core fact table.

create or replace view dim_payment as
select
    order_id,
    payment_method,
    payment_status,
    installment,
    currency
from payments;
