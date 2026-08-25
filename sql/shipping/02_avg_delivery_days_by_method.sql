-- Domain: Shipping
-- Source: queries/medium_questions.sql (Q3)
-- Question: Calculate average delivery days by shipping method

select round(avg(delivery_days), 2) as avg_delivery_days, shipping_method
from shipping
group by shipping_method
order by avg_delivery_days asc;

/*
Data-quality note (from original audit): all shipping methods averaged
~7.5 days in the synthetic dataset with only ~0.02 day variance between
methods, including "Next Day" averaging 7.52 days. This flattens any
genuine SLA-performance comparison and is a known synthetic-data artifact
rather than a real finding. See docs/data_dictionary.md and
sql/data_quality/ for further discussion.
*/
