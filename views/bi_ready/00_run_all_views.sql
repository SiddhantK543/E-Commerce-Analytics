-- Runs every BI-ready view/table in dependency order.
-- Usage: psql -U postgres -d ecommerce_db -f views/bi_ready/00_run_all_views.sql
-- Prerequisite: schema/create_tables.sql has already been run and data loaded.

\i sql/date_dimension/create_dim_date.sql

\i views/bi_ready/dim_customer.sql
\i views/bi_ready/dim_product.sql
\i views/bi_ready/dim_payment.sql
\i views/bi_ready/dim_shipping.sql
\i views/bi_ready/dim_marketing.sql

\i views/bi_ready/fact_orders.sql
\i views/bi_ready/fact_order_items.sql

\i views/bi_ready/customer_rfm.sql
\i views/bi_ready/customer_churn.sql
\i views/bi_ready/fraud_flags.sql
\i views/bi_ready/transaction_health.sql

-- Phase 3 additions (transaction_risk_flags must be created before
-- vw_transaction_health, which references it; kpi_transaction_health
-- must come after vw_transaction_health, which it selects from)
\i views/bi_ready/transaction_risk_flags.sql
\i views/bi_ready/vw_transaction_health.sql
\i views/bi_ready/kpi_transaction_health.sql
