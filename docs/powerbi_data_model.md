# Power BI Data Model

This document proposes the Power BI star schema for this project. It
is a **design document only** — no `.pbix` file is created in this
phase (per Phase 6 scope: "Do not create a dashboard yet").

Source material inspected before writing this design: `data/exports/*.csv`
(Python, Phase 5), `views/bi_ready/*.sql` (SQL, Phase 3/4),
`docs/business_definitions.md`, `schema/create_tables.sql`, and
`python/export_bi_data.py`.

---

## 1. Available BI Data — Inventory

### From `views/bi_ready/` (SQL, live-connectable)

| Object | Grain | Role |
|---|---|---|
| `fact_orders` | 1 row / order | Order identity + date + status |
| `fact_order_items` | 1 row / order line item | Revenue/profit/quantity at line-item grain (carries `customer_id`, `order_date`, `product_id`) |
| `dim_customer` | 1 row / customer | Customer demographics + segment |
| `dim_product` | 1 row / product | Product catalog attributes |
| `dim_date` (physical table) | 1 row / calendar day | Full date dimension |
| `dim_payment` | 1 row / order | Payment attributes (order-grain, not payment-method-grain) |
| `dim_shipping` | 1 row / order | Shipping attributes (order-grain) |
| `dim_marketing` | 1 row / order | Campaign/coupon attribution (order-grain) |
| `customer_rfm` | 1 row / customer | RFM scores + segment (current snapshot) |
| `customer_churn` | 1 row / customer | Churn flag + recency (current snapshot) |
| `fraud_flags` / `transaction_risk_flags` | 1 row / order | Risk signals + combined flag |
| `vw_transaction_health` / `kpi_transaction_health` | 1 row / order; 1 row total | Transaction status classification; single-row KPI summary |
| `cohort_retention` | 1 row / cohort period | Retention analysis (supplementary, not part of the core star schema below) |

### From `data/exports/` (Python, flat-file-connectable)

| File | Grain | Role |
|---|---|---|
| `bi_transaction_health.csv` | 1 row / order | Same content as `vw_transaction_health`, portable |
| `bi_customer_rfm.csv` | 1 row / customer | Same content as `customer_rfm` |
| `bi_customer_churn.csv` | 1 row / customer | Same content as `customer_churn` |
| `bi_product_performance.csv` | 1 row / product | **Pre-aggregated** revenue/profit/units per product |
| `bi_revenue_trends.csv` | 1 row / calendar month | **Pre-aggregated** monthly revenue |
| `bi_risk_analysis.csv` | 1 row / order | Same content as `transaction_risk_flags` |

Both sources are kept in sync (Phase 5 verified this — see
`docs/python_analytics.md` §10) and are treated as **interchangeable**
for modeling purposes: the same star schema below works whether Power
BI connects live to PostgreSQL (`views/bi_ready/`) or imports the flat
files (`data/exports/`). The choice is an operational one (live
refresh vs. portability), not a modeling one.

**One important exception:** `bi_product_performance.csv` and
`bi_revenue_trends.csv` are **pre-aggregated**. They are useful as a
standalone reference/validation export, but they are **not** used as
the source of Power BI's product or revenue measures — see §7 (Product
Measures, in `docs/powerbi_measures.md`) for why, and §9 below for the
concrete risk this avoids.

## 2. Proposed Star Schema

```
                         ┌───────────────┐
                         │   DimDate     │
                         │ date_key (PK) │
                         └───────┬───────┘
                    ┌────────────┼────────────┐
                    │(1)                    (1)│
                    ▼                          ▼
          ┌──────────────────┐        ┌──────────────────────┐
          │    FactOrders    │        │   FactOrderItems      │
          │  order_id (PK)   │        │ order_id+product_id   │
          │  customer_id(FK) │        │      (PK)              │
          │  order_date (FK) │        │  order_id, customer_id,│
          │  payment_method  │        │  product_id, order_date│
          │  (FK)            │        │  (all FK)              │
          └───────┬──────────┘        └──────────┬─────────────┘
              (1) │                          (∞) │      (∞)
                  │ 1:1                          │       │
                  ▼                              ▼       ▼
          ┌──────────────┐              ┌──────────────┐ │
          │  FactRisk    │              │  DimProduct  │ │
          │ order_id(PK) │              │product_id(PK)│ │
          └──────────────┘              └──────────────┘ │
                                                            │
                    ┌───────────────────────────────────────┘
                    │ (∞ from both FactOrders and FactOrderItems)
                    ▼
            ┌──────────────────┐        ┌────────────────────┐
            │   DimCustomer    │        │  DimPaymentMethod   │
            │ customer_id (PK) │        │ payment_method (PK) │
            │ (+ RFM + churn   │        └─────────┬───────────┘
            │  merged in)      │                  │ (∞, from FactOrders only)
            └──────────────────┘                  ▲
                                     (relationship shown once, applies to FactOrders)
```

*(FactOrders and FactOrderItems are each related independently to
`DimDate` and `DimCustomer` — they are deliberately **not** related to
each other. See §3 for why.)*

### Fact tables

| Fact table | Grain | Source | Primary key |
|---|---|---|---|
| **FactOrders** | **One row = one order.** | `vw_transaction_health` / `bi_transaction_health.csv` | `order_id` |
| **FactOrderItems** | **One row = one product line within an order.** | `fact_order_items` (SQL only — no direct CSV equivalent exported in Phase 5; see `docs/powerbi_measures.md` §"Limitations") | `order_id` + `product_id` (composite) |
| **FactRisk** | **One row = one order's risk assessment.** | `transaction_risk_flags` / `bi_risk_analysis.csv` | `order_id` |

### Dimension tables

| Dimension | Grain | Source | Primary key |
|---|---|---|---|
| **DimCustomer** | One row = one customer | `dim_customer` merged with `customer_rfm` + `customer_churn` (see §2.1) | `customer_id` |
| **DimProduct** | One row = one product | `dim_product` (descriptive attributes only — see §2.3) | `product_id` |
| **DimDate** | One row = one calendar day | `dim_date` (physical table, `sql/date_dimension/create_dim_date.sql`) | `date_key` |
| **DimPaymentMethod** | One row = one distinct payment method | Derived (see §2.2) | `payment_method` |

### Deliberately NOT created as separate tables

| Candidate | Decision | Why |
|---|---|---|
| `FactPayments` | **Folded into FactOrders** | `payments` is 1:1 with `orders` (one payment record per order, confirmed via schema PK). A separate fact table at an identical grain to FactOrders adds a join hop with no analytical benefit. `payment_method`, `payment_status` live directly on FactOrders. |
| `FactShipping` | **Folded into FactOrders** | Same reasoning — `shipping` is 1:1 with `orders`. `shipping_method`, `delivery_days`, `shipping_cost_usd` are FactOrders attributes, not a separate fact. |
| `DimGeography` | **Not created; `country`/`city` stay on DimCustomer** | Only 2 low-cardinality columns, sourced entirely from `customers`, with no other fact table needing geography independent of the customer. A separate dimension would add a snowflake join with no query-performance or clarity benefit at this data volume. Revisit only if a future data source adds ship-to/warehouse geography distinct from the customer's own address. |
| `DimMarketing` | **Not included as a core dimension in this phase** | Available (`dim_marketing`: `coupon_used`, `campaign_source`) but no dashboard page in the Phase 6 scope currently requires campaign-level slicing. Documented here as available for a future "Marketing" page rather than added speculatively. |

### 2.1 Why RFM and churn are merged INTO DimCustomer, not kept separate

`customer_rfm` and `customer_churn` are both **1 row per customer**,
**current-snapshot** data (computed as of the dataset's max order
date, not a time series). Since there is only one snapshot — not RFM
history over time — treating them as separate fact tables would be
over-engineering: there is nothing to aggregate or filter by that a
plain dimension attribute can't already do (e.g. slicing FactOrders by
`DimCustomer[rfm_segment]`). They are merged into a single wide
`DimCustomer` via a Power Query merge on `customer_id`:

```
dim_customer
  merge on customer_id  <-  customer_rfm   (keep: recency_days, frequency,
                                             monetary, recency_score,
                                             frequency_score, monetary_score,
                                             rfm_total_score, rfm_segment)
  merge on customer_id  <-  customer_churn (keep: is_churned,
                                             months_since_last_order)
```

`customer_name` and `customer_segment` appear in more than one source
— keep the `dim_customer` copy and drop the duplicates from the merged
sources to avoid ambiguous/duplicate columns.

**If RFM/churn need to be recomputed on a rolling basis in the future**
(e.g. daily), this decision should be revisited — a snapshot-per-day
model would then need a proper fact table with a date key, not a
dimension attribute. Not needed for the current single-snapshot scope.

### 2.2 DimPaymentMethod — a small "junk"-style lookup dimension

Unlike `DimGeography` (rejected above), `DimPaymentMethod` **is**
worth extracting: `payment_method` is a genuinely reusable, very
low-cardinality categorical value (5 distinct values confirmed on the
test fixture: `Apple Pay`, `Bank Transfer`, `Credit Card`, `Debit
Card`, `PayPal` — see `docs/business_definitions.md` for the full
confirmed-value caveat on the real dataset). Extracting it into its
own one-column dimension:

- Lets Power BI show a clean payment-method slicer without scanning
  FactOrders
- Is trivial to build in Power Query: reference the FactOrders query →
  keep only the `payment_method` column → **Remove Duplicates**

This is exactly the kind of "use the actual available data and choose
the cleanest model" judgment call the low-cardinality/high-reuse
profile of this column supports, in contrast to `DimGeography`.

### 2.3 DimProduct stays descriptive-only (no pre-aggregated revenue columns)

`bi_product_performance.csv` includes `units_sold`, `product_revenue`,
and `product_profit` alongside the descriptive columns. These
aggregate columns are **deliberately excluded** from `DimProduct`:
putting a static, pre-computed total on a dimension row means it can
never respond to a report's date/customer/segment filters — a user
filtering to Q1 2025 would still see the product's *all-time* revenue
next to it, which is misleading. `DimProduct` therefore keeps only
`product_id`, `product_name`, `category`, `brand`,
`product_rating_avg`, `stock_quantity`; all revenue/units/profit
figures are computed as DAX measures against `FactOrderItems` instead
(see `docs/powerbi_measures.md`), so they correctly respect whatever
filter context the report applies.

## 3. Relationships

| From | To | Cardinality | Cross-filter direction | Notes |
|---|---|---|---|---|
| `DimCustomer[customer_id]` | `FactOrders[customer_id]` | One-to-many | Single (Dim → Fact) | Standard |
| `DimCustomer[customer_id]` | `FactOrderItems[customer_id]` | One-to-many | Single (Dim → Fact) | FactOrderItems carries its own `customer_id` (confirmed present in `fact_order_items.sql`), so it relates to DimCustomer **directly**, not through FactOrders |
| `DimDate[date_key]` | `FactOrders[order_date]` | One-to-many | Single (Dim → Fact) | |
| `DimDate[date_key]` | `FactOrderItems[order_date]` | One-to-many | Single (Dim → Fact) | Independent relationship, not routed through FactOrders |
| `DimProduct[product_id]` | `FactOrderItems[product_id]` | One-to-many | Single (Dim → Fact) | |
| `DimPaymentMethod[payment_method]` | `FactOrders[payment_method]` | One-to-many | Single (Dim → Fact) | |
| `FactOrders[order_id]` | `FactRisk[order_id]` | One-to-one | **Both directions** | Safe here specifically because no other relationship path connects these two tables (see below) |

### `FactOrders` ↔ `FactOrderItems`: deliberately **NOT** related directly

This is the relationship the Phase 6 spec calls out for special
attention ("Orders → Order Items"), so the reasoning is spelled out in
full:

- Both tables **already** connect independently to the same `DimDate`
  and `DimCustomer` dimensions (see above), which is sufficient for
  every cross-analysis Power BI needs to do between order-level and
  line-item-level facts (e.g. "revenue by month by customer segment"
  pulls from FactOrderItems + DimDate + DimCustomer; "payment failure
  rate by month" pulls from FactOrders + DimDate).
- A **direct** `order_id`-based relationship between them would be a
  **fact-to-fact relationship at different grains** (one order : many
  line items). This is technically possible in Power BI but is a
  well-known source of double-counting: if `FactOrders[order_value]`
  (already a per-order total) is summed while a visual is filtered by
  a `FactOrderItems`-sourced field (e.g. `product_category`), the
  order's value gets repeated once per matching line item.
- **Concrete illustration** (validation-only, not a real dataset
  finding): a hypothetical $100 order with 2 line items, joined
  directly and summed per matching line item, produces $200 — double
  the correct value. See §9 for the query that demonstrates this.
- **Conclusion:** no relationship is created between FactOrders and
  FactOrderItems. If a specific report page genuinely needs both
  order-level and line-item-level context in one visual, that should
  be solved with a Power Query merge into a new query (materializing
  the join explicitly, at a chosen grain) — never with a live model
  relationship between two same-order, different-grain fact tables.

### `FactOrders` ↔ `FactRisk`: why bidirectional 1:1 is safe here

Both tables share the exact same grain (one row per order) and primary
key (`order_id`), and — critically — **no other relationship path
connects them** (FactRisk has no relationship to DimProduct, DimDate,
or DimCustomer of its own in this design). A bidirectional one-to-one
relationship between them cannot create ambiguity because there is
only ever one path between any two tables in this model. This lets a
visual filtered by `FactRisk[transaction_risk_flag] = 'High Risk'`
correctly filter `FactOrders` measures (e.g. Total Revenue at risk),
and vice versa.

*(If a future phase adds a direct FactRisk-to-DimCustomer relationship
for risk-specific customer segmentation, this decision should be
revisited — a second path would then make bidirectional filtering
ambiguous, and it should be switched to single-direction.)*

## 4. Date Dimension

`dim_date` (built by `sql/date_dimension/create_dim_date.sql`) already
contains every field the Phase 6 spec asks for, plus a few extras:

| Column | Maps to spec requirement |
|---|---|
| `date_key` | Date |
| `year` | Year |
| `quarter`, `quarter_label` | Quarter |
| `month_number` | Month Number |
| `month_name`, `month_short_name` | Month (Name) |
| `year_month_label`, `year_month_key` | Year-Month |
| `iso_week` | Week |
| `day_of_month` | Day |
| `day_of_week_number`, `day_of_week_name`, `day_of_week_short_name` | Day of Week |
| `is_weekend` | (extra — not in spec, kept as a useful bonus) |

**Chronological sorting in Power BI** (a common real gotcha, called
out explicitly per Step 4's "ensure proper chronological sorting"):
`month_name` and `day_of_week_name` are text and will sort
alphabetically by default (April before January). In Power BI Desktop,
set:
- `DimDate[month_name]` → **Sort by Column** → `month_number`
- `DimDate[day_of_week_name]` → **Sort by Column** → `day_of_week_number`
- `DimDate[quarter_label]` → **Sort by Column** → `quarter`

`year_month_label` (`"2024-01"` style) already sorts correctly as text
without any extra configuration, since it's zero-padded and
year-first.

## 5. Grain Discipline Summary

| Table | Grain (one row =) |
|---|---|
| FactOrders | one order |
| FactOrderItems | one product line within an order |
| FactRisk | one order's risk assessment |
| DimCustomer | one customer |
| DimProduct | one product |
| DimDate | one calendar day |
| DimPaymentMethod | one distinct payment method |

No table in this model mixes two grains. Every fact table's grain is
stated in its own `SELECT` in `views/bi_ready/` and was verified
row-by-row against the synthetic test fixture (§9).

## 6. Validation

See `docs/powerbi_measures.md` for the full measure library and
`docs/powerbi_data_model.md` §3 above for relationship-level reasoning.
Concrete validation query results (row counts, duplicate-key checks,
and the fact-to-fact double-counting illustration) are recorded in
`powerbi/model_design.md` §"Validation Results" and summarized in the
Phase 6 final report.
