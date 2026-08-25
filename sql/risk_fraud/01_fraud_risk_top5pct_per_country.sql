-- Domain: Risk / Fraud
-- Source: queries/hard_questions.sql (Q8)
-- Question: Find orders where fraud risk score is in the top 5% per
-- country

with fraud_ranking as (
    select rm.order_id, o.customer_id, c.customer_name, c.country,
           rm.order_priority, rm.fraud_risk_score,
           percent_rank() over (partition by c.country order by rm.fraud_risk_score desc) as per_rank
    from risk_management rm
    inner join orders o on rm.order_id = o.order_id
    inner join customers c on o.customer_id = c.customer_id
)
select order_id, customer_id, customer_name, country, order_priority,
       fraud_risk_score, round((per_rank * 100)::numeric, 2) as percentile
from fraud_ranking
where per_rank <= 0.05
order by country, fraud_risk_score;

/*
Result (from original audit): 37,581 orders (~4.7% of total) flagged,
consistent with the 5%-per-country target threshold.
*/
