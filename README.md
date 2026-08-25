# 🛒 E-commerce Transaction & Business Analytics

A portfolio-grade analytics project analyzing a large-scale
(synthetic) global e-commerce dataset — from raw-data cleaning
through advanced SQL analytics to (upcoming) Python cross-validation
and a Power BI dashboard.

> **Project status:** SQL foundation, data-quality layer, BI-ready data
> model, and the Python/Pandas analytics layer are complete and
> cross-validated against each other. **The Power BI dashboard is
> planned but not yet built** — see [Project Status](#-project-status)
> below.

---

## 📋 Table of Contents
- [Project Overview](#-project-overview)
- [Business Problem](#-business-problem)
- [Objectives](#-objectives)
- [Project Status](#-project-status)
- [Dataset](#-dataset)
- [Data Model](#-data-model)
- [Technology Stack](#-technology-stack)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [SQL Analysis](#-sql-analysis)
- [Python Analysis](#-python-analysis-upcoming)
- [Power BI Dashboard](#-power-bi-dashboard-upcoming)
- [Business Insights](#-business-insights)
- [Data-Quality Limitations](#-data-quality-limitations)
- [How to Run](#-how-to-run)
- [Skills Demonstrated](#-skills-demonstrated)
- [Connect](#-connect)

---

## 📌 Project Overview

This project simulates the work of a data/analytics team at a global
e-commerce company, covering the full path from raw transactional
data to business-ready insight:

**Raw Data → Cleaning & Validation → PostgreSQL → SQL Analytics →
Python/Pandas → BI-Ready Views → Power BI → Business Insights**

It analyzes transactions, payments, refunds/cancellations, customers,
churn, products/revenue, shipping, and fraud/risk across ~1M
synthetic orders (2024–2026).

## 🎯 Business Problem

An e-commerce company needs a single, trustworthy analytics layer that
can answer: *Where is revenue coming from and is it healthy? Which
customers are valuable, at risk, or already lost? Which transactions
should be reviewed for fraud? Where is the business losing money to
failed payments, refunds, and cancellations?* This project builds that
layer end-to-end, on top of a schema and dataset that stand in for a
real order-management system.

## 🎯 Objectives

- Demonstrate advanced SQL (CTEs, window functions, multi-table joins)
  applied to real business questions, not just syntax practice
- Build a documented, non-destructive data-cleaning and validation
  layer
- Cover the full analytical surface area required for e-commerce
  analytics: transactions, payments, refunds/cancellations, customer
  behavior, RFM segmentation, churn, product/revenue, shipping, and
  risk/fraud
- Produce a BI-ready data model (facts, dimensions, and derived
  analytical views) suitable for Power BI
- Pair every analysis with an honest business recommendation and
  transparent documentation of data limitations

---

## 📊 Project Status

| Layer | Status |
|---|---|
| Schema (PostgreSQL) | ✅ Complete (from original project) |
| Data-quality / validation SQL | ✅ Complete |
| SQL analytics (business-domain organized) | ✅ Complete |
| Date dimension | ✅ Complete |
| BI-ready views (facts, dimensions, RFM, churn, fraud flags) | ✅ Complete |
| Python / Pandas analytics | ✅ Complete, cross-validated against SQL |
| Power BI data model & DAX measures (star schema design) | ✅ Complete, not yet built as a report |
| Power BI dashboard specification (all 5 pages, validated) | ✅ Complete (Phase 7) |
| Power BI dashboard (actual `.pbix` report) | 🚧 Fully specified, **not yet built as a `.pbix`** |
| Documentation (architecture, business definitions, data dictionary, Python analytics) | ✅ Complete |

This README describes the full intended project. The Power BI section
is marked **upcoming** and does not represent completed work.

---

## 📦 Dataset

| Property | Details |
|---|---|
| Source | [Kaggle — Global E-Commerce Dataset +1M Records](https://www.kaggle.com/datasets/akrambelha/global-e-commerce-dataset-1m-records-20242026) |
| Records | ~1 million orders (2024–2026) |
| Type | Synthetically generated |
| Format | PostgreSQL dump (.sql) |
| Size | ~356MB |
| Tables | 10 relational tables |

> **Note:** The dataset is synthetically generated. Several columns
> show unrealistically flat/uniform distributions (documented
> throughout this project rather than hidden — see
> [Data-Quality Limitations](#-data-quality-limitations)). All SQL
> logic is written to be correct and production-ready regardless; the
> methodology, not the specific figures, is the portfolio deliverable.

The raw dataset is **not** stored in this repository (356MB). See
[`data/README.md`](data/README.md) for how to obtain and load it.

---

## 🗄️ Data Model

```
customers ──────────── orders ──────────── order_items
                          │                     │
                          │                     │
                       payments              products
                          │
                     ┌────┴─────┐
                  shipping   marketing
                          │
                  ┌───────┴────────┐
             risk_management   user_behavior
                          │
                        reviews
```

| Table | Description | Key Columns |
|---|---|---|
| `customers` | Customer demographics and segments | customer_id, customer_segment, country, loyalty_score |
| `orders` | Order records with date info | order_id, customer_id, order_year/month/day, order_status, return_reason |
| `order_items` | Line items per order (true transaction grain) | order_id, product_id, quantity, total_price_usd, profit_usd |
| `products` | Product catalog | product_id, product_name, category, product_rating_avg |
| `payments` | Payment details | order_id, payment_method, payment_status |
| `shipping` | Shipping and delivery info | order_id, shipping_method, delivery_days, shipping_cost_usd |
| `reviews` | Product reviews | order_id, product_id, rating, customer_feedback |
| `marketing` | Campaign and coupon data | order_id, coupon_used, coupon_code, campaign_source |
| `user_behavior` | Session and device data | order_id, device_type, session_duration_minutes |
| `risk_management` | Fraud risk scores | order_id, fraud_risk_score, order_priority |

Full column-level documentation, including open questions about
unconfirmed value sets, lives in [`docs/data_dictionary.md`](docs/data_dictionary.md).

**BI-ready layer** (built on top of the above, see `views/bi_ready/`):
`fact_orders`, `fact_order_items`, `dim_customer`, `dim_product`,
`dim_date`, `dim_payment`, `dim_shipping`, `dim_marketing`, plus
analytical outputs `customer_rfm`, `customer_churn`, `fraud_flags`, and
`transaction_health`.

---

## 🔧 Technology Stack

| Tool | Purpose | Status |
|---|---|---|
| PostgreSQL 14+ | Database engine | ✅ In use |
| pgAdmin 4 / psql | Query execution | ✅ In use |
| Python (pandas, numpy, matplotlib) | Cross-validation, RFM, churn, anomaly detection, BI export | ✅ Complete |
| Power BI | Dashboard / visualization | 🚧 Planned |
| Git / GitHub | Version control, portfolio hosting | ✅ In use |

---

## 🏗️ Architecture

Full pipeline diagram and layer-by-layer explanation in
[`docs/architecture.md`](docs/architecture.md). Summary:

```
Raw Data → Cleaning & Validation → PostgreSQL → SQL Analytics
  → Python/Pandas → BI-Ready Views → Power BI (upcoming)
  → Business Insights
```

---

## 📁 Project Structure

```
ecommerce-sql-analysis/
│
├── README.md                       ← This file
├── requirements.txt                 ← Python deps (for the upcoming Python layer)
├── .gitignore
│
├── data/
│   ├── README.md                    ← How to obtain/load the dataset
│   └── sample/                      ← Reserved for a small dev sample (not yet populated)
│
├── schema/
│   └── create_tables.sql            ← Table definitions and constraints (unchanged from original)
│
├── queries/                         ← ORIGINAL difficulty-tiered SQL (preserved, hygiene-fixed)
│   ├── README.md
│   ├── easy_questions.sql
│   ├── medium_questions.sql
│   └── hard_questions.sql
│
├── sql/                              ← PRIMARY business-domain-organized SQL
│   ├── data_quality/                 ← Validation checks (flag, don't delete)
│   ├── date_dimension/               ← dim_date calendar table
│   ├── transactions/
│   ├── payments/
│   ├── refunds_cancellations/
│   ├── customers/
│   ├── churn/
│   ├── products_revenue/
│   ├── shipping/
│   └── risk_fraud/
│
├── views/
│   └── bi_ready/                     ← Facts, dimensions, RFM, churn, fraud flags
│
├── python/                           ← Python/Pandas analytics layer (Phase 5)
│   ├── README.md
│   ├── config.py
│   ├── data_loader.py
│   ├── data_quality.py
│   ├── data_cleaning.py
│   ├── rfm_analysis.py
│   ├── customer_segmentation.py
│   ├── churn_analysis.py
│   ├── anomaly_detection.py
│   ├── transaction_analysis.py
│   ├── exploratory_analysis.py
│   ├── visualization.py
│   ├── export_bi_data.py
│   └── run_pipeline.py
│
├── notebooks/                        ← 🚧 Reserved, empty
│
├── powerbi/
│   └── README.md                     ← 🚧 Planned scope, not yet built
│
├── insights/
│   └── key_findings.md               ← Business insights & recommendations
│
└── docs/
    ├── architecture.md               ← Full pipeline explanation + diagram
    ├── business_definitions.md       ← Authoritative term/KPI definitions (Phase 3/4)
    ├── data_dictionary.md            ← Column-level documentation
    ├── python_analytics.md           ← Python architecture, methodology, SQL/Python reconciliation
    ├── powerbi_data_model.md         ← Star schema design, relationships, grain (Phase 6)
    └── powerbi_measures.md           ← Full DAX measure library with business definitions (Phase 6)
```

---

## 📝 SQL Analysis

SQL work is organized two ways:

1. **`sql/<domain>/`** — the primary organization, by business domain
   (transactions, payments, refunds_cancellations, customers, churn,
   products_revenue, shipping, risk_fraud, plus data_quality and
   date_dimension). This is where new analysis was added in this
   phase.
2. **`queries/`** — the original easy/medium/hard difficulty
   progression, preserved for its own portfolio value (see
   [`queries/README.md`](queries/README.md)).

Every query in `sql/` traces back to its original source file/question
number in a header comment, and any newly-added query (e.g. return-
reason breakdown, churn-by-segment, combined fraud-risk flags) is
explicitly labeled as new, with no fabricated result numbers attached.

### Concepts covered
- **Joins:** INNER, LEFT, multi-table (3+ tables)
- **Aggregations:** SUM, COUNT, AVG, MIN, MAX, ROUND
- **Filtering & Grouping:** WHERE, HAVING, GROUP BY, DISTINCT
- **Subqueries:** correlated and scalar
- **CTEs:** single, chained, multiple
- **Window Functions:** RANK, DENSE_RANK, ROW_NUMBER, LAG, LEAD,
  PERCENT_RANK, NTILE, SUM()/AVG() OVER, custom window frames
- **Date Functions:** MAKE_DATE, DATE_PART, EXTRACT, INTERVAL
- **Conditional Logic:** CASE WHEN, COALESCE

---

## 🐍 Python Analysis

Implemented in Phase 5. `python/` contains 12 modules covering data
loading, an analytical data-quality layer, cleaning/feature
engineering, RFM analysis, customer segmentation, churn analysis,
rule-based anomaly detection, transaction-health KPIs, exploratory
analysis, visualization, and BI-ready CSV export. See
[`python/README.md`](python/README.md) for the module list and
[`docs/python_analytics.md`](docs/python_analytics.md) for full
methodology and the SQL/Python consistency verification (including one
real discrepancy found and fixed — an `NTILE` vs. `qcut` quantile-
scoring difference — documented in full there).

Tested end-to-end against a small, clearly-labeled synthetic fixture
(`data/sample/`) — not the real dataset, which was not available in
this environment. See `docs/python_analytics.md`, "Testing" and
"Limitations," before citing any figure from this layer as a real
finding.

```bash
cd python/
pip install -r ../requirements.txt
python3 run_pipeline.py
```

---

## 📊 Power BI Dashboard (Specified, Not Yet Built)

**Data model, star schema, DAX measures, and the full 5-page dashboard
specification are complete and validated (Phases 6–7)** — see
[`docs/powerbi_data_model.md`](docs/powerbi_data_model.md),
[`docs/powerbi_measures.md`](docs/powerbi_measures.md), and
[`powerbi/dashboard_pages.md`](powerbi/dashboard_pages.md) (every KPI
card, visual, slicer, and tooltip, populated with real numbers from
the synthetic test fixture). **No `.pbix` file exists yet** — Power BI
Desktop project files are proprietary binaries that can't be reliably
hand-authored outside Power BI Desktop, so none is fabricated. A
static, navigable HTML mockup (
[`powerbi/mockup/dashboard_mockup.html`](powerbi/mockup/dashboard_mockup.html))
lets you preview the layout and visual design in a browser in the
meantime. The Risk & Anomalies page is explicitly labeled **"Rule-Based
Risk Monitoring"** throughout — never "fraud detection" — since this
dataset has no confirmed-fraud label.

See [`powerbi/README.md`](powerbi/README.md) for the full file index,
data-source/refresh instructions, and remaining steps before an actual
`.pbix` can be published.

---

## 💡 Business Insights

Full write-up with business recommendations in
[`insights/key_findings.md`](insights/key_findings.md). Headline
findings from the original analysis (figures pending re-verification
against a freshly loaded dataset in this restructured project):

- Electronics is the highest-grossing category (~$104M), outperforming
  the next category (Home) by ~59%
- Revenue grew ~10% from 2024 to 2025 while profit margin held stable
  at ~40%
- 18,513 orders applied a coupon but still failed payment —
  representing ~$7.4M in quantifiable, recoverable lost revenue
- ~70% of customers met the project's 6-month-inactivity churn
  definition (see caveat below — likely inflated by synthetic order
  distribution, not a literal real-world churn rate)
- 37,581 orders (~4.7%) were flagged in the top 5% fraud-risk
  percentile within their country

---

## ⚠️ Data-Quality Limitations

Documented transparently rather than hidden — see
[`docs/data_dictionary.md`](docs/data_dictionary.md) and
[`sql/data_quality/README.md`](sql/data_quality/README.md) for full
detail:

| Issue | Finding | Impact |
|---|---|---|
| Duplicate primary keys | Raw dump had duplicate order_id, product_id, customer_id | ~25% rows removed during deduplication in the original load |
| Synthetic distribution | All shipping methods averaged ~7.5 days delivery | No meaningful shipping performance comparison possible as-is |
| Uniform product margins | Profit margin fixed per product across all months | Margin-trend analysis (Q9) found no qualifying products |
| Partial year data | 2024 starts March, 2026 ends February | YoY comparisons must exclude partial periods |
| Uniform payment distribution | Near-equal usage across payment methods | No dominant payment preference detectable |
| Unconfirmed categorical value sets | `order_status`, `payment_status`, `shipping_status` have no CHECK constraint | Must run `sql/data_quality/03_invalid_categorical_values.sql` before relying on any specific status string beyond those already confirmed in use |
| SQL/Python RFM scoring mismatch (found & fixed in Phase 5) | Postgres `NTILE` partitions by row position; pandas `qcut` partitions by value — these disagreed on tied values | Both `views/bi_ready/customer_rfm.sql` and `python/rfm_analysis.py` were fixed to use the identical algorithm with a deterministic tiebreaker; see `docs/python_analytics.md` §10 for the full investigation |

---

## 🛠️ How to Run

### Prerequisites
- PostgreSQL 14+
- pgAdmin 4 or `psql`

### Step 1 — Create the database and schema
```bash
createdb ecommerce_db
psql -U postgres -d ecommerce_db -f schema/create_tables.sql
```

### Step 2 — Obtain and load the dataset
See [`data/README.md`](data/README.md) for the full staging →
deduplicate → load process (the raw dump has duplicate primary keys
and must not be loaded directly into the constrained schema).

### Step 3 — Run data-quality checks
```bash
psql -U postgres -d ecommerce_db -f sql/data_quality/01_duplicate_records.sql
# ...and the remaining files in sql/data_quality/
```

### Step 4 — Build the date dimension and BI-ready views
```bash
psql -U postgres -d ecommerce_db -f views/bi_ready/00_run_all_views.sql
```

### Step 5 — Run domain analytics
```bash
psql -U postgres -d ecommerce_db -f sql/transactions/01_orders_placed_2024.sql
# ...or any file under sql/<domain>/
```

### Step 6 (upcoming) — Python / Power BI
Not yet available — see [Project Status](#-project-status).

---

## 💡 Skills Demonstrated

### SQL
Joins, aggregations, subqueries, CTEs, window functions, date
arithmetic, conditional logic, data-quality/validation SQL, view
design for BI consumption.

### Data & Business Analysis
Revenue/profitability analysis, customer segmentation & RFM, churn
analysis, fraud-risk identification, payment-failure analysis,
refund/cancellation analysis, shipping analysis, data-quality
identification and transparent documentation, business-insight
generation from raw data.

### Project & Data Architecture
Designing a layered pipeline (raw → clean → SQL → Python → BI →
insights), organizing SQL by business domain, building a documented
data dictionary, and reserving clear scaffolding for not-yet-built
components rather than overclaiming project status.

---

## 🔗 Connect

- 💼 LinkedIn: [Shrikant Mangalam](www.linkedin.com/in/shrikant-mangalam-75148126a)
- 📧 Email: shrikantmangalam2002@email.com
- 🐙 GitHub: [@Shrikantmangalam1](https://github.com/Shrikantmangalam1)

*This project was built as a portfolio piece demonstrating the full
path from raw e-commerce data to business-ready analytics: SQL, data
quality, (upcoming) Python, and (upcoming) Power BI.*
