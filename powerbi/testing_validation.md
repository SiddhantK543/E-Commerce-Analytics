# Phase 7 — Dashboard Testing & Validation

All checks below were run against the live PostgreSQL test database
(`ecommerce_test`, the same 5-customer/11-order synthetic fixture used
throughout Phases 2–6), simulating what each Power BI slicer/
relationship/measure would compute. This is a re-verification specific
to Phase 7 (the dashboard build), on top of the Phase 6 data-model
validation already recorded in `powerbi/model_design.md`.

## 1. KPI values

Every KPI card value quoted in `powerbi/dashboard_pages.md` was
queried directly, not estimated:

| KPI | Query result |
|---|---|
| Total Revenue | $1,480.40 |
| Total Orders | 11 |
| Average Order Value | $134.58 |
| Total Customers | 5 |
| Payment Success Rate | 63.64% |
| Potential Lost Revenue | $210.49 |
| Churn Rate | 60% (3 of 5) |
| High Risk Transactions | 4 |

✅ All match the source views (`kpi_transaction_health`,
`customer_rfm`, `customer_churn`, `transaction_risk_flags`) exactly —
no discrepancy between the dashboard spec and the underlying data.

## 2. Filters (single slicer)

Simulated `DimCustomer[country] = "USA"`:
```
orders | revenue
-------+---------
     8 | 1284.92
```
USA has 3 of 5 customers and 8 of 11 orders — filtering correctly
reduces both the order count and revenue total, and the reduced
revenue ($1,284.92) is less than the unfiltered total ($1,480.40), as
expected.

## 3. Cross-filtering (multiple slicers combined)

Simulated `country = "USA"` AND `payment_method = "Credit Card"`:
```
orders | revenue
-------+---------
     4 |  959.94
```
✅ Combining two slicers further narrows the result (4 orders, down
from 8 for country alone) — confirms slicers combine with AND logic
(standard Power BI behavior for two different fields), not OR.

## 4. Cross-fact-table filtering (DimCustomer → FactOrders via RFM segment)

Simulated slicing `FactOrders` by `DimCustomer[rfm_segment]`:
```
   rfm_segment   | orders | revenue
-----------------+--------+---------
 Champions       |      6 | 1104.94
 Loyal Customers |      2 |  120.48
 At Risk         |      2 |  179.98
 Lost Customers  |      1 |   75.00
```
✅ The `Champions` revenue total ($1,104.94) matches
`customer_rfm.monetary` summed for the 2 Champions customers exactly
— confirms the `DimCustomer → FactOrders` relationship (data model §3)
correctly cross-filters revenue by an RFM segment, with no
double-counting or omission. Row total (6+2+2+1 = 11 orders) matches
`Total Orders` exactly.

## 5. Date filters

Simulated a `DimDate` slicer restricted to year = 2025:
```
orders | revenue
-------+---------
     4 |  624.97
```
✅ Matches the 4 order-months recorded for 2025 in the monthly trend
data (Jan $75.00, Feb $399.98, Mar $120.00, Jul $29.99 = $624.97) —
confirms date filtering via `DimDate[date_key] → FactOrders[order_date]`
works at year grain as expected from a day-grain relationship.

## 6. Revenue — no order-item duplication (critical check)

```
sum_from_order_items (FactOrderItems) : 1480.40
sum_from_orders_view (FactOrders)      : 1480.40
```
✅ Identical. Re-confirms the Phase 6 finding: `[Total Revenue]`
computed from `FactOrderItems` and the independently-derived
order-level total in `FactOrders`/`vw_transaction_health` agree
exactly. Combined with the Phase 6 illustrative double-counting proof
(`powerbi/model_design.md` §3.5), this confirms the model's decision
NOT to relate `FactOrders` and `FactOrderItems` directly is both safe
and necessary — computing `[Total Revenue]` from `FactOrderItems`
alone is correct and cannot inflate regardless of what other filters
(category, customer, date) are applied.

## 7. Orders — no inflation via FactOrderItems

```
distinct order_ids in order_items : 11
total rows in orders               : 11
```
✅ 1:1 — every order appears exactly once whether counted from
`FactOrders` or `DISTINCTCOUNT(FactOrderItems[order_id])`. `[Total
Orders]` is still defined against `FactOrders` per
`docs/powerbi_measures.md` (not `FactOrderItems`), which remains the
correct, grain-safe choice in general (a future multi-line order would
break the `COUNTROWS(FactOrderItems)` approach even though it happens
to agree here).

## 8. Customers — distinct, no inflation

Re-confirmed from Phase 6 (`powerbi/model_design.md` §3.2): distinct
customers via `FactOrders` = 5, via `FactOrderItems` = 5. Unchanged in
Phase 7; no new customer-grain visual introduced a new risk here.

## 9. Rankings

`Product Rank` (RANKX equivalent) simulated via SQL `RANK() OVER`:
```
product_name         | revenue | product_rank
Wireless Headphones   |  779.96 |  1
Blender               |  270.47 |  2
Running Shoes         |  240.00 |  3
Desk Lamp             |  100.00 |  4
Yoga Mat              |   89.97 |  5
```
✅ Matches the Top Products / Pareto Analysis ordering used in
`powerbi/dashboard_pages.md` exactly — no ties in this fixture, so
`DENSE` rank type behaves identically to a plain rank here (ties would
only matter with equal revenue values, not present in this data).

## 10. Risk

Re-confirmed from the data gathered while writing
`powerbi/dashboard_pages.md`: High Risk = 4 orders / $590.47, Review =
3 orders / $579.96, Normal = 4 orders / $309.97 — sums to 11 orders
and $1,480.40, matching `Total Orders`/`Total Revenue` exactly (no
risk-flag category is double-counted or omitted).

## 11. Interaction correctness summary

| Interaction | Verified? |
|---|---|
| Single slicer narrows results correctly | ✅ (§2) |
| Multiple slicers combine with AND logic | ✅ (§3) |
| Slicer on a dimension correctly cross-filters an unrelated-looking fact via the modeled relationship | ✅ (§4) |
| Date slicer filters at the expected grain | ✅ (§5) |
| No revenue double-counting from the FactOrders/FactOrderItems design decision | ✅ (§6) |
| No order-count inflation via FactOrderItems | ✅ (§7) |
| No customer-count inflation | ✅ (§8) |
| Rankings match expected order, no unexplained ties | ✅ (§9) |
| Risk-flag categories partition the full order set with no gaps/overlaps | ✅ (§10) |

## 12. Known gaps (not fixed in this phase, per scope)

- These checks were run in SQL as a proxy for Power BI's relationship/
  filter engine, since no live `.pbix` exists to test directly (see
  `powerbi/README.md`). The underlying relationships and DAX patterns
  are the same ones documented in `docs/powerbi_data_model.md` and
  `docs/powerbi_measures.md`, so this is a faithful simulation, but the
  actual Power BI file should be spot-checked against this document
  once built.
- All checks are against the 5-customer/11-order synthetic fixture —
  re-run equivalent checks against the real dataset once loaded.
