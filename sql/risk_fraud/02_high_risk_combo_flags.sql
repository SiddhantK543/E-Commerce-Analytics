-- Domain: Risk / Fraud
-- NEW query added in Phase 2. The original project only had a single
-- fraud-score percentile query. This adds a simple multi-signal anomaly
-- flag by combining fraud score with payment status and support ticket
-- volume -- a common pattern in real fraud-triage workflows.
-- Question: Which orders combine a high fraud risk score with a failed
-- payment and/or an elevated support ticket count?
-- Not yet executed against the dataset; no fabricated result numbers below.
-- CAVEAT: the specific thresholds below (score > 80, tickets >= 2) are
-- illustrative starting points, not derived from actual data analysis.
-- They should be recalibrated after reviewing the real distribution of
-- fraud_risk_score and support_tickets.

select
    o.order_id,
    o.customer_id,
    rm.fraud_risk_score,
    rm.order_priority,
    rm.support_tickets,
    p.payment_status,
    case
        when rm.fraud_risk_score > 80 and p.payment_status = 'Failed' then 'High Risk: Score + Failed Payment'
        when rm.fraud_risk_score > 80 and rm.support_tickets >= 2 then 'High Risk: Score + Support Tickets'
        when rm.fraud_risk_score > 80 then 'High Risk: Score Only'
        else 'Standard'
    end as risk_flag
from orders o
inner join risk_management rm on o.order_id = rm.order_id
inner join payments p on o.order_id = p.order_id
where rm.fraud_risk_score > 80
   or rm.support_tickets >= 2
order by rm.fraud_risk_score desc;
