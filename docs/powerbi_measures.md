# Power BI Measures (DAX Library)

Every measure below is written against the star schema in
`docs/powerbi_data_model.md`. Business definitions are taken directly
from `docs/business_definitions.md` — **no new or conflicting KPI
definitions are introduced here.** Where a definition has an important
caveat (e.g. "not a confirmed refund amount"), that caveat is repeated
so the measure can't be misread in isolation.

Table/column names below assume the model in
`docs/powerbi_data_model.md`: `FactOrders`, `FactOrderItems`,
`FactRisk`, `DimCustomer`, `DimProduct`, `DimDate`, `DimPaymentMethod`.

---

## Sales / Revenue

| Measure | Business definition | DAX | Source table | Grain | Caveats |
|---|---|---|---|---|---|
| **Total Revenue** | Same as "Gross transaction value" in `docs/business_definitions.md`: the order value of ALL orders, regardless of payment outcome or status. | `Total Revenue = SUM(FactOrderItems[total_price_usd])` | FactOrderItems | line item, summed | Computed from FactOrderItems (line-item grain), **not** `FactOrders[order_value]` — both are mathematically equal in total, but FactOrderItems is the correct source because it responds to `DimProduct`/category filters, which `FactOrders` cannot (see data model §2.3). |
| **Gross Transaction Value** | Identical to Total Revenue above — kept as a separate, explicitly-named measure because `docs/business_definitions.md` uses this exact term and some visuals should say "Gross Transaction Value" verbatim for the Transaction & Payment Health page. | `Gross Transaction Value = [Total Revenue]` | FactOrderItems (via Total Revenue) | | Intentionally a duplicate of Total Revenue, not a different formula — do not let these drift apart. |
| **Successful Revenue** | Order value counted only for orders where payment succeeded and the order was not cancelled/returned. | `Successful Revenue = CALCULATE([Total Revenue], FactOrders[transaction_status] = "Successful")` | FactOrderItems, filtered via FactOrders | | Requires the FactOrders→(shared dims)→FactOrderItems filter path; since these two facts are NOT directly related (see data model §3), this measure relies on `DimDate`/`DimCustomer` being the shared filter path — see "Known limitation" below. |
| **Potential Lost Revenue** | Order value for orders where the payment failed. A *potential*, not guaranteed-recoverable, figure. | `Potential Lost Revenue = CALCULATE([Total Revenue], FactOrders[transaction_status] = "Failed")` | FactOrderItems, filtered via FactOrders | | Same known limitation as Successful Revenue — see below. Never add this to Successful Revenue to make a "total" — it is already a subset of Total Revenue. |
| **Average Order Value** | Mean order value across all orders. | `Average Order Value = DIVIDE([Total Revenue], [Total Orders])` | FactOrderItems / FactOrders | | Uses DIVIDE to avoid a division-by-zero error in an empty filter context. |
| **Total Orders** | Count of distinct orders. | `Total Orders = DISTINCTCOUNT(FactOrders[order_id])` | FactOrders | one row/order | Uses FactOrders (already at order grain), not `COUNTROWS(FactOrderItems)`, which would inflate for multi-line orders. |
| **Total Customers** | Count of distinct customers with at least one order. | `Total Customers = DISTINCTCOUNT(FactOrders[customer_id])` | FactOrders | | Distinct count, not `COUNTROWS(DimCustomer)`, which would include customers with zero orders in some filter contexts. |
| **Total Units** | Total quantity of items sold. | `Total Units = SUM(FactOrderItems[quantity])` | FactOrderItems | | |

### ⚠️ Known limitation: `CALCULATE` filtering FactOrderItems by a FactOrders column

Because FactOrders and FactOrderItems are deliberately **not**
directly related (data model §3), a `CALCULATE` filter on
`FactOrders[transaction_status]` does **not** automatically propagate
to `FactOrderItems` in the model as designed — DAX filter propagation
requires an active relationship. **Successful Revenue** and
**Potential Lost Revenue** as written above only work correctly if
Power BI is told to force that filter across, e.g. via
`TREATAS`:

```dax
Successful Revenue =
CALCULATE(
    [Total Revenue],
    TREATAS(
        CALCULATETABLE(VALUES(FactOrders[order_id]), FactOrders[transaction_status] = "Successful"),
        FactOrderItems[order_id]
    )
)
```

This is documented explicitly rather than silently "fixed" by adding
the very relationship §3 argues against — the `TREATAS` pattern is the
standard, recommended way to apply a filter from one fact table to
another unrelated one in DAX, without introducing the fact-to-fact
relationship (and its double-counting risk) into the model itself.

---

## Transaction Health

| Measure | Business definition | DAX | Source | Caveats |
|---|---|---|---|---|
| **Successful Orders** | Count of orders with `transaction_status = "Successful"`. | `Successful Orders = CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[transaction_status] = "Successful")` | FactOrders | |
| **Failed Orders** | Count of orders with `transaction_status = "Failed"`. | `Failed Orders = CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[transaction_status] = "Failed")` | FactOrders | |
| **Cancelled Orders** | Count of orders with `order_status = "Cancelled"`. | `Cancelled Orders = CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[order_status] = "Cancelled")` | FactOrders | |
| **Returned Orders** | Count of orders with `order_status = "Returned"`. | `Returned Orders = CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[order_status] = "Returned")` | FactOrders | |
| **Payment Success Rate** | `COUNT(payment_status = 'Success') / COUNT(all payments) × 100` | `Payment Success Rate = DIVIDE([Successful Orders], [Total Orders]) * 100` | FactOrders | Matches `docs/business_definitions.md` exactly. |
| **Payment Failure Rate** | `COUNT(payment_status = 'Failed') / COUNT(all payments) × 100` | `Payment Failure Rate = DIVIDE([Failed Orders], [Total Orders]) * 100` | FactOrders | |
| **Cancellation Rate** | `COUNT(order_status = 'Cancelled') / COUNT(all orders) × 100` | `Cancellation Rate = DIVIDE([Cancelled Orders], [Total Orders]) * 100` | FactOrders | |
| **Return Rate** | `COUNT(order_status = 'Returned') / COUNT(all orders) × 100` | `Return Rate = DIVIDE([Returned Orders], [Total Orders]) * 100` | FactOrders | |

---

## Customer

| Measure | Business definition | DAX | Source | Caveats |
|---|---|---|---|---|
| **New Customers** | Customers whose EARLIEST order falls within the selected period. | `New Customers = CALCULATE(DISTINCTCOUNT(FactOrders[customer_id]), FILTER(VALUES(FactOrders[customer_id]), CALCULATE(MIN(FactOrders[order_date])) IN VALUES(DimDate[date_key])))` | FactOrders + DimDate | Requires the customer's first-ever order date to fall in the current filter context — a period-over-period cohort-style measure, not a simple count. |
| **Returning Customers** | Customers with more than one distinct order overall. | `Returning Customers = CALCULATE(DISTINCTCOUNT(FactOrders[customer_id]), FILTER(VALUES(FactOrders[customer_id]), CALCULATE(DISTINCTCOUNT(FactOrders[order_id])) > 1))` | FactOrders | This is the DAX equivalent of `python/exploratory_analysis.repeat_customer_rate()` — do not recompute a different definition. |
| **Active Customers** | Customers with at least one order in the currently filtered period (typically used with a date slicer). | `Active Customers = DISTINCTCOUNT(FactOrders[customer_id])` | FactOrders | Identical formula to Total Customers — named separately because "active" is meaningful specifically when a date filter/slicer is applied; with no date filter, Active Customers = Total Customers. |
| **Churned Customers** | Customers flagged `is_churned = TRUE` in `DimCustomer` (6-month inactivity, from `views/bi_ready/customer_churn.sql` — see `docs/business_definitions.md`). | `Churned Customers = CALCULATE(DISTINCTCOUNT(DimCustomer[customer_id]), DimCustomer[is_churned] = TRUE)` | DimCustomer | Uses the pre-computed `is_churned` flag already merged into DimCustomer (data model §2.1) — **does not** recompute the 6-month threshold in DAX. |
| **Churn Rate** | `Churned Customers / Total Customers (in DimCustomer) × 100` | `Churn Rate = DIVIDE([Churned Customers], DISTINCTCOUNT(DimCustomer[customer_id])) * 100` | DimCustomer | Uses `DimCustomer`'s full customer count (not `FactOrders`' count) as the denominator, since churn is a customer-level concept independent of any order-date filter. |
| **Retention Rate** | The complement of churn rate. | `Retention Rate = 100 - [Churn Rate]` | DimCustomer | Simple complement — not an independently-modeled cohort-retention measure (see `views/bi_ready/cohort_retention.sql` for that, kept as a separate, more detailed SQL-only analysis not reproduced in DAX in this phase). |
| **Customer Revenue** | Total revenue attributable to a customer (or the customers in the current filter context). | `Customer Revenue = [Total Revenue]` | FactOrderItems | Simply `Total Revenue` evaluated in a customer filter context — no separate formula needed, since `FactOrderItems` already relates to `DimCustomer` directly. |
| **Orders per Customer** | Average number of orders per customer. | `Orders per Customer = DIVIDE([Total Orders], [Total Customers])` | FactOrders | |
| **Average Customer Value** | Average total revenue per customer. | `Average Customer Value = DIVIDE([Total Revenue], [Total Customers])` | FactOrderItems / FactOrders | |

**RFM segments are NOT recalculated in DAX** — per the Phase 6
instruction to "use the existing Python/SQL RFM outputs rather than
recalculating the entire RFM methodology inside DAX." `DimCustomer[rfm_segment]`,
`[recency_score]`, `[frequency_score]`, and `[monetary_score]` are
imported directly (via the merge in data model §2.1) and used as
plain slicers/filters — e.g. "Total Revenue by rfm_segment" needs no
measure beyond `[Total Revenue]` sliced by `DimCustomer[rfm_segment]`.

---

## Risk

| Measure | Business definition | DAX | Source | Caveats |
|---|---|---|---|---|
| **High Risk Transactions** | Count of orders with `transaction_risk_flag = "High Risk"` (rule-based, see `docs/business_definitions.md` "Suspicious transaction"). | `High Risk Transactions = CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[transaction_risk_flag] = "High Risk")` | FactRisk | Never labeled "fraud" or "confirmed fraud" in any visual title — see terminology rule in `docs/business_definitions.md`. |
| **Review Transactions** | Count of orders with `transaction_risk_flag = "Review"`. | `Review Transactions = CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[transaction_risk_flag] = "Review")` | FactRisk | |
| **Duplicate Candidates** | Count of orders flagged `possible_duplicate_flag = TRUE`. | `Duplicate Candidates = CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[possible_duplicate_flag] = TRUE)` | FactRisk | "Candidate," not "confirmed duplicate" — per `docs/business_definitions.md`, the data alone cannot confirm a duplicate. |
| **High Risk Value** | Order value of orders flagged High Risk — the revenue exposure of the risk-flagged population. | `High Risk Value = CALCULATE([Total Revenue], FactRisk[transaction_risk_flag] = "High Risk")` | FactOrderItems, filtered via FactRisk | Same `TREATAS`-based cross-fact-filter caveat as Successful/Potential Lost Revenue applies here, since FactOrderItems has no direct relationship to FactRisk either. |

---

## Product

| Measure | Business definition | DAX | Source | Caveats |
|---|---|---|---|---|
| **Product Revenue** | Revenue for the product(s) in the current filter context. | `Product Revenue = [Total Revenue]` | FactOrderItems | Computed live from FactOrderItems, **not** copied from `bi_product_performance.csv`'s pre-aggregated `product_revenue` column — that export is a static, all-time total that would not respect a date/segment filter (see data model §2.3). |
| **Product Units** | Units sold for the product(s) in context. | `Product Units = [Total Units]` | FactOrderItems | Same reasoning as above. |
| **Top Product Revenue** | The revenue of the single best-selling product in the current context (typically used alongside a product-name measure in a "top product" card). | `Top Product Revenue = MAXX(VALUES(DimProduct[product_id]), [Product Revenue])` | FactOrderItems + DimProduct | Respects whatever outer filter (date, category, customer segment) is applied — recalculates the "top" dynamically rather than reading a static rank. |
| **Product Rank** | The product's revenue rank among all products in the current context. | `Product Rank = RANKX(ALL(DimProduct[product_id]), [Product Revenue], , DESC, DENSE)` | FactOrderItems + DimProduct | `ALL(DimProduct[product_id])` ensures ranking is against the full product list regardless of any product-level filter already applied in the visual (e.g. a single category slicer) — this is the "respects filter context" requirement from Step 8: the rank still reflects the product's standing within whatever OTHER filters (date, region) are active, just not artificially re-based by a product filter that would make every visible product "rank 1." |
| **Top Category Revenue** | The revenue of the single best-selling category in context. | `Top Category Revenue = MAXX(VALUES(DimProduct[category]), [Product Revenue])` | FactOrderItems + DimProduct | |
| **Category Rank** | The category's revenue rank among all categories in context. | `Category Rank = RANKX(ALL(DimProduct[category]), [Product Revenue], , DESC, DENSE)` | FactOrderItems + DimProduct | |
| **Revenue Contribution %** | The product's (or category's) share of total revenue in context. | `Revenue Contribution % = DIVIDE([Product Revenue], CALCULATE([Product Revenue], ALL(DimProduct)))` | FactOrderItems + DimProduct | `ALL(DimProduct)` in the denominator ensures the "total" is the grand total across all products, not just the ones visible after other filters — this is what makes contribution % sum to 100% correctly at any level of a product/category visual. |
| **Profit** | `SUM(order_items.profit_usd)` — assumed formula `total_price_usd - cost_usd`, not independently verified (see `docs/data_dictionary.md`). | `Profit = SUM(FactOrderItems[profit_usd])` | FactOrderItems | Carries the same "assumed formula, unverified" caveat as the SQL/Python layers — do not present as a confirmed accounting figure. |

---

## Time Intelligence

All time-intelligence measures below require `DimDate` to be marked as
the model's **Date Table** in Power BI (Table view → Mark as date
table → `date_key`) for the built-in DAX time-intelligence functions to
work correctly.

| Measure | DAX | Caveats |
|---|---|---|
| **Revenue MTD** | `Revenue MTD = TOTALMTD([Total Revenue], DimDate[date_key])` | |
| **Revenue YTD** | `Revenue YTD = TOTALYTD([Total Revenue], DimDate[date_key])` | |
| **Previous Month Revenue** | `Previous Month Revenue = CALCULATE([Total Revenue], DATEADD(DimDate[date_key], -1, MONTH))` | |
| **MoM Revenue Growth %** | `MoM Revenue Growth % = DIVIDE([Total Revenue] - [Previous Month Revenue], [Previous Month Revenue])` | |
| **Rolling 3-Month Revenue** | `Rolling 3-Month Revenue = CALCULATE([Total Revenue], DATESINPERIOD(DimDate[date_key], MAX(DimDate[date_key]), -3, MONTH))` | Mirrors the "rolling 3-month average revenue" methodology already implemented in `sql/products_revenue/09_rolling_3month_avg_revenue_by_category.sql` — same 3-month window concept, applied here at the whole-business level instead of per-category. |

### Previous Year Revenue / YoY Growth % — include with an explicit caveat, not omitted

The dataset spans March 2024 through February 2026 (per
`docs/data_dictionary.md` and `insights/key_findings.md`) — **not** two
full clean calendar years. A straight `SAMEPERIODLASTYEAR` comparison
is still meaningful for the fully-overlapping window (April–December,
present in both 2024 and 2025) but will be **misleading for
January/February and March**, where one side of the comparison is a
partial period (2024's March start, 2026's February end). Rather than
omitting YoY entirely (the data does support it for most months) or
silently computing it everywhere (which would misrepresent the edge
months), the measure is included with a mandatory caveat wired into
its behavior:

```dax
Previous Year Revenue =
CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(DimDate[date_key]))

YoY Growth % =
DIVIDE([Total Revenue] - [Previous Year Revenue], [Previous Year Revenue])

YoY Growth % (partial-period flagged) =
VAR IsPartialEdge =
    OR(
        MIN(DimDate[month_number]) IN {1, 2} && MAX(DimDate[year]) = 2026,
        MIN(DimDate[month_number]) = 3 && MIN(DimDate[year]) = 2024
    )
RETURN
    IF(IsPartialEdge, BLANK(), [YoY Growth %])
```

Use the plain `YoY Growth %` for exploratory work, but prefer the
`(partial-period flagged)` version on any dashboard visual, so
January/February/March don't silently show a misleadingly large or
small growth number sourced from an incomplete comparison period. This
directly follows the Phase 6 instruction: *"Do not create
time-intelligence calculations if the available date range makes them
meaningless"* — here the range makes them meaningful for 9 of 12
months, so the correct response is to flag the exception, not omit the
whole measure.

---

## Summary: what's intentionally excluded

Per `docs/business_definitions.md`, "Summary of what this project
explicitly does NOT claim" — no DAX measure in this library computes:
Net Revenue, a confirmed Refund amount, a confirmed Fraud
determination, or a confirmed Duplicate count. Where a measure sounds
close to one of these (e.g. **Potential Lost Revenue**, **Duplicate
Candidates**), its name and definition make the distinction explicit.
