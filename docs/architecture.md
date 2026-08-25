# Architecture

This document describes the end-to-end architecture of the E-commerce
Transaction & Business Analytics project — what exists today, and what
is planned for later phases. It is intentionally a straightforward,
explainable pipeline rather than a complex production system.

## Pipeline overview

```
 ┌───────────────────────┐
 │      1. Raw Data       │   Kaggle "Global E-Commerce Dataset"
 │  (Kaggle CSV/SQL dump) │   ~1M orders, 2024-2026, synthetic
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 2. Cleaning &          │   sql/data_quality/*.sql
 │    Validation          │   Staging tables → dedup → constrained load
 │                        │   Flags issues, does NOT silently delete
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 3. PostgreSQL          │   schema/create_tables.sql
 │    (constrained schema)│   10 tables, PK/FK, indexes
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 4. SQL Analytics       │   sql/<domain>/*.sql
 │  (business-domain SQL) │   transactions, payments, refunds_cancellations,
 │                        │   customers, churn, products_revenue, shipping,
 │                        │   risk_fraud
 │  + sql/date_dimension/ │   dim_date calendar table
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 5. Python / Pandas     │   python/*.py   [NOT YET IMPLEMENTED]
 │    Analytics           │   Cross-validation of SQL findings, RFM in
 │                        │   pandas, anomaly detection, EDA
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 6. BI-Ready Views      │   views/bi_ready/*.sql
 │  (fact/dim + analytics)│   fact_orders, fact_order_items, dim_customer,
 │                        │   dim_product, dim_date, dim_payment,
 │                        │   dim_shipping, dim_marketing, customer_rfm,
 │                        │   customer_churn, fraud_flags, transaction_health
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 7. Power BI            │   powerbi/   [NOT YET BUILT]
 │  (5-page dashboard)    │   Executive Overview | Transaction & Payment
 │                        │   Health | Customer Analytics | Product &
 │                        │   Revenue | Risk/Fraud & Anomalies
 └───────────┬────────────┘
             │
             ▼
 ┌───────────────────────┐
 │ 8. Business Insights & │   insights/key_findings.md
 │    Recommendations     │   README.md
 └────────────────────────┘
```

## Layer-by-layer detail

### 1. Raw Data
Not stored in the repository (356MB Kaggle dump). See `data/README.md`
for acquisition and local-layout instructions. Documented as synthetic
with several known flat/uniform distributions (see
`docs/data_dictionary.md`).

### 2. Cleaning & Validation
`sql/data_quality/` contains eight validation scripts covering
duplicates, orphan records, invalid categorical values, invalid
numeric values, missing values/invalid dates, and text-based
boolean fields. The philosophy throughout: **flag, don't silently
delete** — every questionable record is surfaced for human review, and
cleaning decisions are documented in `sql/data_quality/README.md`.

### 3. PostgreSQL (constrained schema)
`schema/create_tables.sql` — unchanged from the original project. 10
tables: `customers`, `products`, `orders`, `order_items`, `payments`,
`shipping`, `reviews`, `marketing`, `user_behavior`, `risk_management`.
See `docs/data_dictionary.md` for full column-level documentation.

### 4. SQL Analytics
`sql/` is organized by **business domain** rather than only by
difficulty level, so the project reads as a business analytics
deliverable rather than a SQL-practice exercise:

- `sql/transactions/` — revenue, order volume, time trends
- `sql/payments/` — payment methods, failures, lost revenue
- `sql/refunds_cancellations/` — returns, cancellations, return reasons
- `sql/customers/` — segmentation, AOV, spending rank, tenure
- `sql/churn/` — inactivity, churn rate by segment
- `sql/products_revenue/` — category/product performance, margin trends
- `sql/shipping/` — delivery performance
- `sql/risk_fraud/` — fraud scoring, combined risk flags
- `sql/date_dimension/` — the `dim_date` calendar table

The original `queries/easy_questions.sql`, `medium_questions.sql`, and
`hard_questions.sql` are preserved as-is (after the Phase 2 hygiene
fixes) as the original difficulty-tiered narrative; `sql/` is the
primary, business-organized working set going forward. See
`queries/README.md` for how the two relate.

### 5. Python / Pandas Analytics — **not yet implemented**
Reserved in `python/` with documented, stubbed files. Planned to
cross-validate SQL findings (not replace them), perform RFM scoring
independently in pandas, add statistical/lightweight-ML anomaly
detection, and export BI-ready flat files.

### 6. BI-Ready Views
`views/bi_ready/` contains lightweight SQL views (not materialized
copies of the whole dataset) shaped for Power BI: two fact
views at order and line-item grain, five dimension views/table
(`dim_customer`, `dim_product`, `dim_date`, `dim_payment`,
`dim_shipping`, `dim_marketing`), and four analytical outputs
(`customer_rfm`, `customer_churn`, `fraud_flags`,
`transaction_health`). `00_run_all_views.sql` runs them all in
dependency order.

### 7. Power BI — **not yet built**
Deliberately deferred. `powerbi/README.md` documents the planned
5-page scope and the prerequisites that must be true before dashboard
work begins.

### 8. Business Insights & Recommendations
`insights/key_findings.md` and the root `README.md` — narrative
write-ups pairing each analysis with a business recommendation, and
transparent documentation of data-quality limitations throughout.

## Design principles

- **Explainable over clever.** Every transformation should be
  something a candidate could talk through clearly in an interview.
- **Flag, don't hide.** Data-quality issues and synthetic-data
  artifacts are documented, not papered over.
- **No fabricated results.** Any new query added during this phase
  that has not been executed against real data is explicitly labeled
  as such, with no invented numbers.
- **Views over duplication.** BI-ready objects are SQL views (not
  materialized/duplicated large tables) to keep the model efficient;
  materialization can be revisited later purely as a performance
  optimization if needed.
