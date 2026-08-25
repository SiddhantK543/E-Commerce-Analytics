-- BI-ready analytical output: customer_churn
-- Formalizes the original hard_questions.sql Q6 churn query into a
-- reusable view, and adds an explicit is_churned flag plus a
-- months_since_last_order figure so Power BI can build both a churn
-- KPI card and a recency distribution without re-deriving the logic
-- in DAX.
--
-- Definition (unchanged from the original project, made explicit here):
-- a customer is "churned" if their most recent order is more than 6
-- months before the latest order date anywhere in the dataset.

create or replace view customer_churn as
with reference_date as (
    select max(make_date(order_year, order_month, order_day)) as latest_order_date
    from orders
),
customer_last_order as (
    select
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.country,
        max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date
    from customers c
    inner join orders o on c.customer_id = o.customer_id
    group by c.customer_id, c.customer_name, c.customer_segment, c.country
)
select
    clo.*,
    rd.latest_order_date,
    round(
        (rd.latest_order_date - clo.last_order_date) / 30.0,
        1
    ) as months_since_last_order,
    case
        when clo.last_order_date < rd.latest_order_date - interval '6 months' then true
        else false
    end as is_churned
from customer_last_order clo
cross join reference_date rd;
