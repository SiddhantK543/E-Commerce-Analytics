-- Domain: Churn
-- Source: queries/hard_questions.sql (Q6)
-- Question: Inactive users for the past 6 months

with customer_last_order as (
    select c.customer_id, c.customer_name, c.customer_segment,
           max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date
    from customers c
    inner join orders o on c.customer_id = o.customer_id
    group by c.customer_id, c.customer_name, c.customer_segment
)
select * from customer_last_order
where last_order_date <
    (select max(make_date(order_year, order_month, order_day)) from orders) - interval '6 months'
order by last_order_date desc;

/*
Result (from original audit): 555,936 customers (~70%) flagged as churned
relative to the dataset's max order date (Feb 2026), using a 6-month
inactivity threshold. Flagged as a likely synthetic-data artifact (orders
randomly distributed across the 2-year window rather than following real
purchasing cadence) rather than a genuine business signal — see
docs/data_dictionary.md.
*/
