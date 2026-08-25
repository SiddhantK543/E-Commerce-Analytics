-- BI-ready analytical output: fraud_flags
-- Consolidates fraud signals into a single flat view for the Risk /
-- Fraud & Anomalies dashboard page: the top-5%-per-country percentile
-- score from the original project, plus the combined risk-flag logic
-- added in sql/risk_fraud/02_high_risk_combo_flags.sql.
--
-- CAVEAT: the fraud_risk_score > 80 and support_tickets >= 2
-- thresholds are illustrative starting points (see
-- sql/risk_fraud/02_high_risk_combo_flags.sql) and should be
-- recalibrated once the real score distribution is reviewed.

create or replace view fraud_flags as
with fraud_ranking as (
    select
        rm.order_id,
        o.customer_id,
        c.customer_name,
        c.country,
        rm.order_priority,
        rm.fraud_risk_score,
        rm.support_tickets,
        p.payment_status,
        percent_rank() over (partition by c.country order by rm.fraud_risk_score desc) as country_percentile_rank
    from risk_management rm
    inner join orders o on rm.order_id = o.order_id
    inner join customers c on o.customer_id = c.customer_id
    inner join payments p on o.order_id = p.order_id
)
select
    order_id,
    customer_id,
    customer_name,
    country,
    order_priority,
    fraud_risk_score,
    support_tickets,
    payment_status,
    round((country_percentile_rank * 100)::numeric, 2) as country_percentile,
    (country_percentile_rank <= 0.05) as is_top5pct_risk_in_country,
    case
        when fraud_risk_score > 80 and payment_status = 'Failed' then 'High Risk: Score + Failed Payment'
        when fraud_risk_score > 80 and support_tickets >= 2 then 'High Risk: Score + Support Tickets'
        when fraud_risk_score > 80 then 'High Risk: Score Only'
        when country_percentile_rank <= 0.05 then 'High Risk: Top 5% in Country'
        else 'Standard'
    end as risk_flag
from fraud_ranking;
