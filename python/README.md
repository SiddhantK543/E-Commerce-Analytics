# Python / Pandas Layer

**Status: implemented (Phase 5).** This layer complements the SQL
analytics layer (`sql/`, `views/bi_ready/`) — it does not replace or
duplicate it. Every module below either (a) reproduces a specific SQL
calculation in pandas so the two can be cross-validated against each
other, or (b) does something SQL is a poor fit for (charts, statistical
distribution checks, a reusable CSV-based pipeline).

See [`docs/python_analytics.md`](../docs/python_analytics.md) for full
architecture, methodology, and the SQL/Python reconciliation results.

## Modules

| File | Purpose |
|---|---|
| `config.py` | Paths, environment overrides, and business constants/thresholds (kept in sync with the SQL layer) |
| `data_loader.py` | CSV loading with column validation and clear errors for missing/malformed files |
| `data_quality.py` | Analytical validation layer (missing values, duplicates, orphans, invalid categories/numerics) — flags, never deletes |
| `data_cleaning.py` | Date parsing, boolean normalization, grain-safe order-item aggregation, customer/product feature engineering |
| `rfm_analysis.py` | Recency/Frequency/Monetary scoring — reproduces `views/bi_ready/customer_rfm.sql`'s NTILE algorithm exactly |
| `customer_segmentation.py` | Segment size/revenue/AOV/frequency summaries, for both the source `customer_segment` and the derived `rfm_segment` |
| `churn_analysis.py` | Uses the same 6-month-inactivity definition as `views/bi_ready/customer_churn.sql`; breakdowns by RFM segment, value, geography, time |
| `anomaly_detection.py` | Rule-based risk/anomaly flags — reproduces `views/bi_ready/transaction_risk_flags.sql` signal-for-signal |
| `transaction_analysis.py` | Transaction-health KPIs — reproduces `views/bi_ready/kpi_transaction_health.sql` |
| `exploratory_analysis.py` | Sales/customer/transaction/risk EDA, organized by business area |
| `visualization.py` | A small set of consistent, professional charts (matplotlib) |
| `export_bi_data.py` | Exports 6 BI-ready CSVs, with built-in verification checks |
| `run_pipeline.py` | Runs every stage end-to-end for local testing |

## Quick start

```bash
cd python/
pip install -r ../requirements.txt
python3 run_pipeline.py
```

By default this reads from `data/sample/` — a small, clearly-labeled
synthetic fixture (see `data/sample/README.md`), **not real data**.
Point `ECOMMERCE_DATA_DIR` at a real dataset export to use this
pipeline for actual analysis:

```bash
ECOMMERCE_DATA_DIR=/path/to/real/csvs python3 run_pipeline.py
```

## Terminology

This module uses "anomaly", "review candidate", and "high-risk
transaction" — never "fraud" or "confirmed duplicate" — since this
project's data has no confirmed-fraud label. See
`docs/business_definitions.md`.
