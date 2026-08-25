# Data Quality Layer

This folder contains validation queries used to inspect the raw/staging
data **before** it is trusted for analytics. The guiding principle across
every script here:

> **Flag, don't silently delete.** Every check below surfaces
> questionable records so a human can review and decide how to handle
> them. None of these scripts perform a `DELETE`.

## Files

| File | Checks |
|---|---|
| `01_duplicate_records.sql` | Duplicate `order_id`, `customer_id`, `product_id`, and duplicate `(order_id, product_id)` pairs in staging tables |
| `02_orphan_and_missing_key_records.sql` | Orders/order_items referencing a customer or product that doesn't exist; NULL foreign keys |
| `03_invalid_categorical_values.sql` | Actual distinct values of `order_status`, `payment_status`, `shipping_status`, and out-of-range ratings |
| `04_invalid_numeric_values.sql` | Non-positive quantities/prices, negative costs/discounts/tax, a `total_price_usd` reconciliation check, out-of-range fraud scores, implausible ages |
| `05_missing_values_and_invalid_dates.sql` | NULLs in fields expected to be populated, and date-part values that can't form a valid date |
| `06_text_boolean_fields_audit.sql` | Confirms the actual value sets behind `coupon_used`, `abandoned_cart_before`, and `installment` before any boolean casting is attempted |

## Why staging tables

The original README documented a staging-table approach to handle the
raw dataset's known duplicate-primary-key issue:

```sql
CREATE TABLE orders_staging AS TABLE orders WITH NO DATA;
-- load raw data into *_staging
INSERT INTO orders
SELECT DISTINCT ON (order_id) *
FROM orders_staging
ORDER BY order_id;
DROP TABLE orders_staging;
```

The checks in `01_duplicate_records.sql` and `02_orphan_and_missing_key_records.sql`
assume the same `*_staging` naming convention (`orders_staging`,
`customers_staging`, `products_staging`, `order_items_staging`) — an
unconstrained mirror of each core table, loaded from the raw dump before
constraints are applied. This lets you see exactly what would be
rejected (or silently deduplicated) by the final schema's PK/FK
constraints, instead of discovering it via an import failure.

## Known findings carried over from the Phase 1 audit

These are *documented expectations*, not yet re-verified against a live
database in this environment — re-run the checks above once data is
loaded to confirm current figures:

- Raw dump previously showed duplicate `order_id`, `product_id`, and
  `customer_id` — roughly 25% of rows were removed during
  deduplication in the original project.
- `order_status`, `payment_status`, and `shipping_status` have no
  CHECK constraint in `schema/create_tables.sql`. Query 03 should be run
  once per fresh data load to confirm the exact value sets before
  building any CASE WHEN logic elsewhere that depends on specific
  status strings (e.g. `'Returned'`, `'Cancelled'`, `'Failed'`).
- `coupon_used`, `abandoned_cart_before`, and `installment` are stored
  as `VARCHAR` rather than boolean. Query 06 should be run before any
  cleaning script attempts to cast these to boolean, in case they
  contain values other than a clean Yes/No pair.

## Cleaning decisions

| Decision | Rationale |
|---|---|
| Deduplicate via `DISTINCT ON (pk) ... ORDER BY pk` at staging→core load time | Preserves one deterministic row per key rather than an arbitrary one; documented, reproducible |
| Do not auto-delete orphan records | Orphans might indicate a load-order issue (e.g. loading order_items before orders) rather than genuinely bad data — needs human review first |
| Do not auto-cast Yes/No text columns to boolean without first running the audit query | Avoids silently coercing unexpected values (e.g. blank strings, 'Y'/'N' variants) into `false` |
| Flag but do not remove numeric outliers (age, fraud score, delivery days) | Outliers may be legitimate edge cases (e.g. a corporate bulk order) rather than errors; downstream analysis should be outlier-aware, not blind to them |
