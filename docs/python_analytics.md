# Python / Pandas Analytics Layer

This document covers the Python analytics layer built in Phase 5, on
top of the SQL foundation from Phases 2–4. It complements
`docs/architecture.md` (overall pipeline) and
`docs/business_definitions.md` (authoritative term definitions).

## 1. Python Architecture

The layer is organized as small, single-purpose modules rather than
one large script, so each piece is independently testable and
readable:

```
python/
├── config.py               # paths, env overrides, business constants
├── data_loader.py           # CSV loading + column validation
├── data_quality.py          # analytical validation layer (flags, doesn't delete)
├── data_cleaning.py         # date parsing, boolean normalization, feature engineering
├── rfm_analysis.py          # RFM scoring (matches SQL's NTILE algorithm exactly)
├── customer_segmentation.py # segment size/revenue/AOV summaries
├── churn_analysis.py        # same 6-month churn definition as SQL
├── anomaly_detection.py     # rule-based risk flags (matches SQL signal-for-signal)
├── transaction_analysis.py  # transaction-health KPIs (matches SQL exactly)
├── exploratory_analysis.py  # EDA organized by business area
├── visualization.py         # a small set of consistent charts
├── export_bi_data.py        # 6 BI-ready CSV exports + verification
└── run_pipeline.py          # runs every stage end-to-end
```

### What stays in SQL vs. what belongs in Python

Per the Phase 5 instruction not to duplicate SQL unnecessarily, the
split is:

| Stays authoritative in SQL | Added/complemented in Python |
|---|---|
| All business-domain queries in `sql/<domain>/` | Cross-validation of the same metrics (Step 14) |
| `views/bi_ready/*.sql` as the live database-connected BI layer | A CSV-based equivalent, for portability / no-live-DB scenarios |
| RFM, churn, and risk-flag *definitions* | An independent re-implementation of those same definitions, used to catch inconsistencies the SQL-only view alone couldn't self-detect |
| — | Charts (matplotlib) — awkward/verbose to produce in SQL |
| — | Distribution statistics (`.describe()`), z-score/IQR outlier detection — natural fits for pandas/numpy, verbose in SQL |
| — | A single reusable, error-handled CSV loading layer for local development without a database |

No Python module recomputes something SQL already does well without a
stated reason (cross-validation, portability, or a genuinely
pandas-native capability like charting).

## 2. Data Loading (`data_loader.py`)

Reads one CSV per entity (`customers.csv`, `orders.csv`, etc.) from
`config.DATA_DIR` (default `data/sample/`, override via
`ECOMMERCE_DATA_DIR`). Every loader function:

- Validates that all schema-expected columns are present (fails with a
  clear message naming the missing columns, not a cryptic KeyError
  downstream)
- Raises `FileNotFoundError` with the exact expected path and a
  pointer to `data/README.md` if the file isn't there yet
- Does not assume any file exists — this was explicitly tested (see
  Testing section below)

## 3. Data Quality (`data_quality.py`)

An **analytical validation layer**, explicitly secondary to
`sql/data_quality/*.sql` (the authoritative database validation layer,
run against staging tables before data is trusted). This module lets
the same categories of checks run directly against a CSV export,
without a database:

- Missing required values
- Duplicate records (by primary/composite key)
- Orphan relationships (foreign key references that don't resolve)
- Invalid dates (year/month/day combinations that can't form a real date)
- Invalid numeric values (non-positive quantity/price, negative
  discount/tax/cost, margin percent outside ±100%)
- Invalid ratings (outside 1–5)
- Unexpected categorical values (checked against the CONFIRMED value
  sets documented in `docs/business_definitions.md` and mirrored in
  `config.py` — not an assumed fixed enum, since the schema has no
  CHECK constraint)
- Implausible ages

**Every check flags, never deletes.** Each function adds a `dq_*`
boolean column to a copy of the input DataFrame; `run_full_data_quality_suite()`
returns both the flagged DataFrames and a structured `DataQualityReport`.

## 4. Data Cleaning / Feature Engineering (`data_cleaning.py`)

Reusable transformations:

- `build_order_date()` — constructs a real `order_date` from
  `order_year`/`order_month`/`order_day`, the pandas equivalent of SQL's
  `make_date()`. Invalid combinations become `NaT`, not an exception.
- `normalize_yes_no()` — casts a `'Yes'`/`'No'` text column to boolean.
  Any other value becomes `NaN` (missing), never silently coerced to
  `False`.
- `aggregate_order_items_to_order_level()` — **the critical grain-
  safety helper.** `order_items` is one-to-many with `orders`; this
  function aggregates to one row per `order_id` (`order_value`,
  `order_profit`, `line_item_count`) *before* any join to order-level
  tables, mirroring the `order_financials` CTE pattern in
  `views/bi_ready/vw_transaction_health.sql`. Every other module that
  needs order-level revenue calls this first.
- `aggregate_customer_features()` — one row per customer:
  `customer_order_count`, `customer_revenue`, `average_order_value`,
  `days_since_last_order` (relative to the dataset's max order date,
  not "today" — consistent with the SQL churn/RFM reference-date
  convention), `purchase_frequency` (orders per month of tenure,
  tenure floored at 1 month to avoid divide-by-zero).
- `aggregate_product_features()` — one row per product: units sold,
  revenue, profit, line items sold.

No derived field was invented beyond what the schema logically
supports.

## 5. RFM Methodology (`rfm_analysis.py`)

Recency = days since a customer's last order, relative to the max
order date in the dataset. Frequency = distinct order count. Monetary
= total order-level revenue.

**This module is designed to produce IDENTICAL output to
`views/bi_ready/customer_rfm.sql`**, not just a similar one — see
Section 10 for the reconciliation process and the fix that made this
possible.

Segment rules (`config.RFM_SEGMENT_RULES`, transcribed directly from
the SQL view, evaluated top to bottom, first match wins):

| Segment | Rule |
|---|---|
| Champions | R≥4 AND F≥4 AND M≥4 |
| Loyal Customers | R≥3 AND F≥3 |
| Potential Loyalists | R≥4 AND F≤2 |
| At Risk | R≤2 AND (F≥3 OR M≥3) |
| Lost Customers | R≤2 AND F≤2 AND M≤2 |
| Needs Attention | (catch-all) |

## 6. Customer Segmentation (`customer_segmentation.py`)

For both the source-provided `customer_segment` (Regular/Premium/VIP)
and the derived `rfm_segment`, reports: segment size (count and % of
customers), total revenue (and % of revenue), average implied order
value, average purchase frequency, and average recency. Also provides
a cross-tab of source segment vs. RFM segment, to surface mismatches
(e.g. a source-labeled VIP who is actually RFM "At Risk").

No clustering/ML is used — per the Phase 5 instruction to prioritize
explainability, and because RFM + the source segment field already
provide clear, defensible groupings.

## 7. Churn Methodology (`churn_analysis.py`)

Uses the **exact same** definition as
`views/bi_ready/customer_churn.sql`: a customer is churned if their
most recent order is more than `CHURN_INACTIVITY_MONTHS` (6, from
`config.py`) months before the dataset's max order date.
`months_since_last_order` uses the same `/30.0` day-based
approximation as the SQL view (not calendar-accurate months) —
deliberately kept identical rather than "improved," since introducing
a different formula would break comparability.

Breakdowns provided: overall rate, by RFM segment, by customer value
(monetary quintile), by geography, over time (last-order-month
distribution), and a filtered view of churn status among only the
highest-value (top monetary quintile) customers.

## 8. Anomaly Detection Methodology (`anomaly_detection.py`)

**Explicitly not a fraud-detection model.** Terminology used
throughout: "anomaly," "review candidate," "high-risk transaction" —
never "fraud" or "confirmed duplicate," since this dataset has no
confirmed-fraud label (see `docs/business_definitions.md`).

Reproduces `views/bi_ready/transaction_risk_flags.sql`'s five signals
and combining rule exactly:

1. **Unusually high value** — `order_value > mean + 2×population stddev`
   (z-score method; an IQR-based alternative is also provided in
   `flag_unusually_high_value_iqr()` for EDA comparison, not used in
   the combined flag, to stay consistent with the SQL view's method)
2. **Repeated failed payment** — customer has ≥2 failed payments
3. **Possible duplicate flag** — same customer + product + amount +
   date + payment method as another order (a *candidate* for review,
   not a confirmed duplicate)
4. **High fraud score** — `fraud_risk_score > 80`
5. **Returned or cancelled**
6. **Same-day multi-order** — customer placed >1 order on the same day

Combining rule: `fraud_risk_score > 80` alone ⇒ High Risk; ≥2 of
signals 1/2/3/5/6 ⇒ High Risk; exactly 1 ⇒ Review; otherwise ⇒ Normal.

## 9. BI-Ready Exports (`export_bi_data.py`)

| File | Grain | Mirrors |
|---|---|---|
| `bi_transaction_health.csv` | 1 row / order | `vw_transaction_health.sql` |
| `bi_customer_rfm.csv` | 1 row / customer | `customer_rfm.sql` |
| `bi_customer_churn.csv` | 1 row / customer | `customer_churn.sql` |
| `bi_product_performance.csv` | 1 row / product | (Python-only; no direct SQL equivalent) |
| `bi_revenue_trends.csv` | 1 row / calendar month | `sql/transactions/` |
| `bi_risk_analysis.csv` | 1 row / order | `transaction_risk_flags.sql` |

Every export is followed by `verify_exports()`, which checks: no
row-count inflation, no duplicate primary keys, valid score/flag
ranges, and that the revenue total reconciles across exports. Written
to `data/exports/` (git-ignored, same convention as `data/raw/`).

## 10. SQL / Python Consistency (Step 14)

This is the most important section of this document: the Python and
SQL layers were compared directly against the shared synthetic test
fixture (`data/sample/`, 5 customers / 11 orders), not assumed to
agree.

### ✅ Exact matches (no changes needed)

- **Transaction-health KPIs** (`transaction_analysis.kpi_summary()` vs
  `kpi_transaction_health.sql`): total orders, total order value,
  successful/failed/cancelled/returned counts, all four rate
  percentages, potential lost revenue, successful revenue, affected
  order value, and average order value — **matched exactly on the
  first attempt**, no fix required.
- **Anomaly/risk flags** (`anomaly_detection.build_transaction_risk_flags()`
  vs `transaction_risk_flags.sql`): every signal and the combined
  `transaction_risk_flag` matched exactly, for all 11 orders in the
  fixture, on the first attempt.
- **Churn** (`churn_analysis.compute_customer_churn()` vs
  `customer_churn.sql`): overall rate (60%), `is_churned`, and
  `months_since_last_order` matched exactly for all 5 customers, on
  the first attempt.
- **`days_since_last_order`** in `data_cleaning.aggregate_customer_features()`
  matched `customer_rfm.sql`'s `recency_days` exactly.

### ⚠️ Difference found, investigated, and fixed: RFM quantile scoring

**Symptom:** on the initial implementation, `rfm_analysis.py` (using
`pandas.qcut`) disagreed with `customer_rfm.sql` (using `NTILE(5)`) on
`frequency_score` and `monetary_score` for two customers (C002 and
C003, both with `frequency = 2`), which cascaded into a different
`rfm_segment` for one of them (SQL: "Needs Attention"; Python: "Loyal
Customers").

**Root cause (methodology, not just tie-breaking):** Postgres's
`NTILE(n)` partitions rows by **row position** after `ORDER BY` — with
only 5 rows and 5 buckets, every row gets its own bucket regardless of
tied values, and which tied row lands in which bucket depends on the
scan order (undefined without an explicit secondary sort key).
`pandas.qcut`, by contrast, partitions by **value** — tied values
always land in the same bucket (or collapse buckets entirely via
`duplicates="drop"`). These are two different algorithms, not a minor
tie-breaking detail, and the difference is most visible on a small
fixture but is a real consideration at any scale wherever a metric has
repeated values near a quantile boundary (common for integer-valued
metrics like order count).

**Fix applied (both sides, so they now agree by construction):**
1. Added `customer_id` as an explicit secondary `ORDER BY` key to
   every `NTILE()` call in `views/bi_ready/customer_rfm.sql`, making
   its output deterministic (previously implementation-defined).
2. Rewrote `rfm_analysis.py`'s `_quantile_score()` to replicate
   Postgres's exact `NTILE` row-position-bucketing algorithm (not
   `qcut`), using the same `customer_id`-ascending tiebreaker.

**Result after the fix:** all three R/F/M scores, the total RFM score,
and the `rfm_segment` label now match exactly for all 5 customers.

This was a genuinely useful finding: it surfaced a latent
non-determinism in the SQL view (its `NTILE` calls had no tiebreaker
before this fix) that would otherwise only have been noticed if the
view happened to be re-run with a different query plan.

### Summary

| Metric | Match on first attempt? | Fixed? |
|---|---|---|
| Transaction-health KPIs | ✅ Yes | — |
| Anomaly/risk flags | ✅ Yes | — |
| Churn rate & flags | ✅ Yes | — |
| RFM recency_days | ✅ Yes | — |
| RFM scores & segment | ❌ No (algorithm mismatch) | ✅ Yes — both SQL and Python updated |

## 11. Testing

Tested against the synthetic fixture in `data/sample/` (5 customers,
11 orders, exported from the same PostgreSQL test database used for
the Phase 2–4 SQL validation) via `python/run_pipeline.py`, which runs
every stage in sequence:

- ✅ All 12 modules import cleanly with no broken imports
- ✅ No hardcoded machine-specific paths (`config.py` resolves
  everything relative to the repo root; verified via `grep` for
  `/home/`, `/Users/`, `C:\`)
- ✅ `data_loader.py` fails clearly (not silently) on a missing data
  directory and on a file missing expected columns — both explicitly
  tested
- ✅ No unexpected crashes across the full pipeline
- ✅ All BI export outputs have the expected columns and no duplicate
  primary keys (`export_bi_data.verify_exports()`, 9/9 checks passing)
- ✅ RFM scores are within the valid 1–5 range
- ✅ Churn calculation follows the documented 6-month definition
  exactly (verified against the SQL view)
- ✅ Anomaly/risk detection results are explainable (every flag traces
  to one of the six named signals, no black-box scoring)

**The real ~1M-row Kaggle dataset was not available in this
environment; all testing above was performed using the synthetic
`data/sample/` fixture documented in `data/sample/README.md`.** No
numbers derived from this fixture are presented as real business
findings anywhere in this project.

## 12. Limitations

- **Synthetic test data only.** Every reconciliation number in Section
  10 (e.g. "60% churn rate") is a property of the 5-customer test
  fixture, not a real finding — re-run `run_pipeline.py` against the
  real dataset (once obtained per `data/README.md`) before citing any
  figure in `insights/key_findings.md`.
- **RFM/NTILE at real scale.** The fix in Section 10 makes SQL and
  Python deterministic and mutually consistent, but with ~1M rows and
  continuous monetary values, exact tie collisions will be rare — the
  fix matters most for `frequency` (a low-cardinality integer) and for
  reproducibility in general, not because ties will be common at
  scale.
- **`purchase_frequency`'s month-based tenure** is a coarse
  approximation (calendar-month difference, floored at 1), not a
  precise days/30.44 calculation — kept simple and explainable per the
  project's constraints.
- **No ML-based anomaly detection.** Only rule-based + statistical
  (z-score/IQR) methods are used, per the explainability-first
  constraint — `scikit-learn` is listed as a reserved, uninstalled
  dependency in `requirements.txt` should this change deliberately in
  the future.
- **`profit_usd`/`profit_margin_percent` formulas remain an assumption**
  (per `docs/data_dictionary.md`) — `data_quality.check_profit_reconciliation()`
  flags mismatches against the assumed formula but cannot confirm the
  assumption itself without the real data.
