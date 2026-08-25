# Sample Fixture (synthetic, for development/testing only)

The CSVs in this folder are a tiny, hand-built synthetic fixture (5
customers, 11 orders) used to develop and test `python/` and `sql/`
against a known, small dataset before the real ~1M-row Kaggle dataset
is loaded. **These are not real business results.** Any number derived
from this fixture (e.g. "63.64% payment success rate") is a property of
the test data only, useful for verifying code correctness, and is never
presented in `insights/key_findings.md` or the README as a real finding.

## Contents

`customers.csv`, `products.csv`, `orders.csv`, `order_items.csv`,
`payments.csv`, `shipping.csv`, `reviews.csv`, `marketing.csv`,
`user_behavior.csv`, `risk_management.csv` — one file per schema table,
matching `schema/create_tables.sql` column-for-column.

## Deliberate edge cases built into this fixture

So both the SQL and Python data-quality/anomaly logic have something to
actually catch:

- `O004` and `O007` are `Cancelled`/`Returned` (for refund/cancellation
  and transaction-health logic)
- `O003` and `O007` have `payment_status = 'Failed'` (for payment
  failure logic)
- `O011` is a near-duplicate of `O001` (same customer, same product,
  same amount, same date, same payment method) — for duplicate-
  transaction-candidate detection
- `O003` and `O007` have `fraud_risk_score > 80` — for high-fraud-score
  flagging
- Customers have deliberately spread-out last-order dates (some recent,
  some 13+ months old) so churn logic has both churned and
  non-churned customers to classify

## Regenerating this fixture

This fixture was exported from a local PostgreSQL test database seeded
for development. See `sql/data_quality/README.md` and
`docs/python_analytics.md` for how it relates to the SQL layer's own
test setup.

## When the real dataset is available

Point `python/config.py`'s `DATA_DIR` (via the `ECOMMERCE_DATA_DIR`
environment variable) at the real, cleaned CSV export instead of this
folder. No code changes should be required — the loader validates
columns, not row counts or specific values.
