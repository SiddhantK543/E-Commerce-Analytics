# Power BI Model — Implementation Notes & Validation Results

Companion to `docs/powerbi_data_model.md` (which explains *why* the
model looks like this). This file is the *how* — the Power Query
steps to actually build it, and the validation queries run to confirm
it's safe to build.

## 1. Power Query load steps

### FactOrders
- Source: `views/bi_ready/vw_transaction_health` (live) or
  `data/exports/bi_transaction_health.csv` (import)
- No transformation needed — already at the correct grain with
  `transaction_status` pre-computed
- Set data types: `order_date` → Date, `order_value`/`successful_value`/
  `affected_order_value`/`potential_lost_value` → Decimal Number

### FactOrderItems
- Source: `views/bi_ready/fact_order_items` (live connection only — no
  direct CSV export exists yet; see "Limitations" below)
- No transformation needed

### FactRisk
- Source: `views/bi_ready/transaction_risk_flags` (live) or
  `data/exports/bi_risk_analysis.csv` (import)
- No transformation needed

### DimCustomer (requires 2 merges)
1. Start from `views/bi_ready/dim_customer` or the `customers` columns
   of `data/exports/bi_customer_churn.csv`
2. **Merge 1:** Merge with `customer_rfm` / `bi_customer_rfm.csv` on
   `customer_id` (Left Outer Join). Expand only: `recency_days`,
   `frequency`, `monetary`, `recency_score`, `frequency_score`,
   `monetary_score`, `rfm_total_score`, `rfm_segment`. Do **not**
   expand `customer_name`/`customer_segment` again (already present).
3. **Merge 2:** Merge the result with `customer_churn` /
   `bi_customer_churn.csv` on `customer_id` (Left Outer Join). Expand
   only: `is_churned`, `months_since_last_order`.
4. Result: one wide `DimCustomer` table, one row per customer.

### DimProduct
- Source: `views/bi_ready/dim_product`
- **Do not** merge in `bi_product_performance.csv`'s aggregate columns
  (`units_sold`, `product_revenue`, `product_profit`) — see
  `docs/powerbi_data_model.md` §2.3 for why. Those figures are DAX
  measures against `FactOrderItems` instead.

### DimDate
- Source: `views/bi_ready/dim_date` (the physical table)
- After loading: Modeling tab → **Mark as date table** → `date_key`
- Set **Sort by Column**: `month_name` by `month_number`,
  `day_of_week_name` by `day_of_week_number`, `quarter_label` by
  `quarter`

### DimPaymentMethod
- Built entirely in Power Query, not from a SQL view:
  1. Reference the `FactOrders` query (before removing other columns)
  2. Keep only the `payment_method` column
  3. Remove Duplicates
  4. Rename the query to `DimPaymentMethod`

## 2. Relationships to create (Modeling view)

| Relationship | Cardinality | Cross-filter |
|---|---|---|
| DimCustomer → FactOrders | 1:* | Single |
| DimCustomer → FactOrderItems | 1:* | Single |
| DimDate → FactOrders (on `order_date`) | 1:* | Single |
| DimDate → FactOrderItems (on `order_date`) | 1:* | Single |
| DimProduct → FactOrderItems | 1:* | Single |
| DimPaymentMethod → FactOrders | 1:* | Single |
| FactOrders → FactRisk | 1:1 | Both |

**Do not** create a relationship between FactOrders and
FactOrderItems — see `docs/powerbi_data_model.md` §3 for the full
reasoning and the double-counting proof reproduced in §3 below.

## 3. Validation Results (run against the Phase 2–5 synthetic test fixture)

All queries below were run against the same PostgreSQL test database
(`ecommerce_test`) used throughout Phases 2–5 (5 customers, 11 orders,
11 order_items, 5 products). Results, not assumptions:

### 3.1 No duplicate dimension keys

```
 table     | dup_count
-----------+-----------
 customers |         0
 products  |         0
 dim_date  |         0
 orders    |         0
```
✅ Zero duplicates on every candidate primary key checked.

### 3.2 Customer counts do not inflate through FactOrderItems

```
 distinct_customers_via_orders      : 5
 distinct_customers_via_order_items : 5
```
✅ Identical — confirms `FactOrderItems[customer_id]` (carried through
from `orders` in the SQL view) does not introduce duplicate or
inconsistent customer identities relative to `FactOrders`.

### 3.3 Order counts do not inflate through FactOrderItems

```
 distinct_orders_in_items : 11
 total_orders              : 11
```
✅ Every order has at least one line item and no order_id appears
inconsistently — `DISTINCTCOUNT(FactOrderItems[order_id])` would equal
`DISTINCTCOUNT(FactOrders[order_id])`, confirming
`[Total Orders]` is safe to compute from either table (though the
measure library uses `FactOrders`, per `docs/powerbi_measures.md`).

### 3.4 Revenue measures do not double count (direct comparison)

```
 sum_from_order_items (FactOrderItems) : 1480.40
 sum_from_kpi_view (FactOrders total)  : 1480.40
```
✅ Both totals agree exactly on the real fixture — as expected, since
every order in this particular fixture happens to have exactly one
line item.

### 3.5 The double-counting risk this model avoids (illustrative, not fixture data)

Because every order in the current fixture has exactly one line item,
§3.4 alone doesn't *demonstrate* the risk a multi-line order would
create if FactOrders and FactOrderItems were directly related. The
following is a scratch, in-query illustration only (not persisted, not
a claim about the real dataset) proving the concern is real:

```sql
-- Hypothetical: a single $100 order with 2 line items
 order_id | correct_order_value | matching_line_items | value_if_fact_to_fact_related
----------+----------------------+----------------------+-------------------------------
 DEMO001  |               100.00 |                    2 |                        200.00
```

If `FactOrders[order_value]` were summed in a visual filtered by a
`FactOrderItems`-sourced field via a direct fact-to-fact relationship,
a 2-line order's $100 value would be counted twice (once per matching
line item) — exactly the scenario this model's relationship design
(§2 above, and `docs/powerbi_data_model.md` §3) is built to prevent.
This is why `[Total Revenue]` is defined as
`SUM(FactOrderItems[total_price_usd])` — a true line-item-grain sum
that cannot double-count regardless of what dimension filters are
applied — rather than as a sum of `FactOrders[order_value]` filtered
through a relationship to line items.

### 3.6 Payment method cardinality (confirms DimPaymentMethod is worth extracting)

```
 payment_method
----------------
 Apple Pay
 Bank Transfer
 Credit Card
 Debit Card
 PayPal
```
✅ 5 distinct values on the test fixture — low cardinality, confirming
the `DimPaymentMethod` design decision in
`docs/powerbi_data_model.md` §2.2.

## 4. Limitations

- ~~`FactOrderItems` has no CSV export yet~~ **Resolved (Phase 8):**
  `python/export_bi_data.py` now also exports `bi_order_items.csv`
  (line-item grain, matching `fact_order_items.sql` exactly) — the
  flat-file import path can now build every table, including
  `FactOrderItems`. See `data/exports/bi_order_items.csv` and the
  `.pbip` project in `powerbi/pbip/`.
- **Validated only against the synthetic test fixture** (5 customers,
  11 orders) — the real ~1M-row dataset was not available in this
  environment. Re-run the queries in §3 against the real data once
  loaded, before trusting this model at production scale.
- **`FactOrders` ↔ `FactRisk` bidirectional relationship** is safe
  under the current model (no alternate path exists) but must be
  revisited if any future table is related directly to `FactRisk` —
  see `docs/powerbi_data_model.md` §3.
