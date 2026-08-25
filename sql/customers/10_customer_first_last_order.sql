-- Domain: Customers
-- Source: queries/hard_questions.sql (Q7)
-- Question: First and last order date per customer, with tenure
-- NOTE: This query was documented in the original README but missing from
-- the source file; it was reconstructed to match the documented concepts
-- (MIN, MAX, DATE_PART, CASE WHEN).
--
-- BUG FOUND & FIXED (Phase 3 testing): DATE - DATE in PostgreSQL
-- returns a plain INTEGER (a day count), not an INTERVAL, so
-- DATE_PART('day', date - date) fails with "function date_part
-- (unknown, integer) does not exist". Fixed by casting both dates to
-- TIMESTAMP before subtracting -- TIMESTAMP - TIMESTAMP correctly
-- returns an INTERVAL, which DATE_PART can operate on. This preserves
-- the DATE_PART concept the query was written to demonstrate, while
-- actually running. (The same underlying bug was independently found
-- and fixed in views/bi_ready/customer_churn.sql, which instead simply
-- divides the integer day-count directly -- either fix is valid; this
-- file keeps DATE_PART since that was the documented intent for Q7.)

select
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    min(make_date(o.order_year, o.order_month, o.order_day)) as first_order_date,
    max(make_date(o.order_year, o.order_month, o.order_day)) as last_order_date,
    date_part(
        'day',
        max(make_date(o.order_year, o.order_month, o.order_day))::timestamp
        - min(make_date(o.order_year, o.order_month, o.order_day))::timestamp
    ) as customer_tenure_days,
    case
        when min(make_date(o.order_year, o.order_month, o.order_day))
             = max(make_date(o.order_year, o.order_month, o.order_day))
            then 'Single Order Customer'
        else 'Repeat Customer'
    end as customer_type
from customers c
inner join orders o on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name, c.customer_segment
order by customer_tenure_days desc;
