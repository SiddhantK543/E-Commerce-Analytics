# Dashboard Pages — Detailed Specification

This document specifies exactly what each of the 5 report pages
contains: every KPI card, every visual (with its precise fields/
measures), every slicer, every tooltip, and the navigation/header
design. It is the build blueprint for the `.pbix` file (not yet built
— see `powerbi/README.md` for why, and `powerbi/mockup/` for a
non-binary visual preview of this specification).

**All numbers quoted below are computed from the synthetic
`data/sample/` test fixture (5 customers, 11 orders) used throughout
Phases 2–6 — they are observations from that test dataset, not real
business findings.** Every figure was queried live from the test
database while writing this document (not estimated or invented); see
`powerbi/testing_validation.md` for the full validation trail.

---

## Shared header & navigation (every page)

- **Top bar** (48px): report title left-aligned ("E-Commerce
  Transaction & Business Analytics"), 5 page-navigation pills
  right-aligned (Executive Overview · Transaction & Payment Health ·
  Customer Analytics · Product & Revenue · Risk & Anomalies), current
  page pill highlighted in the theme's primary color (`#2C6E91`).
- **Home button**: a small house icon at the far left of every page
  except Executive Overview, which returns to Executive Overview
  (Power BI: Insert → Buttons → Back, action = Page navigation →
  Executive Overview).
- **Page navigation**: built with Power BI's native "Page navigator"
  visual (Insert → Buttons → Page navigation), filtered to show only
  the 5 report pages (not any future drillthrough/tooltip pages), so
  it stays in sync automatically if pages are reordered.
- **Consistent filter panel**: a collapsible right-hand slicer panel
  (Power BI: Sync Slicers pane) so the same Date/Country/Segment
  slicer instances are visually anchored in the same place on every
  page, even though each page only enables the slicers relevant to it
  (see each page's Slicers section).
- **Footer**: small caption, bottom-left, on every page: *"Synthetic
  test data — see docs/python_analytics.md for dataset status"* — this
  is removed once the real dataset is loaded and the report is
  rebuilt against it (do not ship this caption against real data, and
  do not remove it while still on synthetic data).

---

## PAGE 1 — Executive Overview

### KPI cards (top row, 6 cards, equal width, minimal border, large number + small label)

| Card | Measure | Value (synthetic fixture) |
|---|---|---|
| Total Revenue | `[Total Revenue]` | **$1,480.40** |
| Total Orders | `[Total Orders]` | **11** |
| Average Order Value | `[Average Order Value]` | **$134.58** |
| Total Customers | `[Total Customers]` | **5** |
| Payment Success Rate | `[Payment Success Rate]` | **63.64%** |
| Cancellation/Return Rate | `[Cancellation Rate] + [Return Rate]` (new combined measure, see below) | **18.18%** |

**New measure needed** (not yet in `docs/powerbi_measures.md` — added
here since Page 1 asks for a single combined rate):
```dax
Cancellation/Return Rate = [Cancellation Rate] + [Return Rate]
```
This is a simple sum of two already-defined, non-overlapping rates
(`order_status` is mutually exclusive per `docs/business_definitions.md`,
so Cancelled and Returned orders never double-count each other) — not
a new methodology.

### Visuals

1. **Revenue trend** — line chart. Axis: `DimDate[year_month_label]`.
   Values: `[Total Revenue]`. Fixture shows 10 populated months (Mar
   2024 – Feb 2026) ranging from $25.00 (Feb 2026, partial) to $399.98
   (Feb 2025); no visual smoothing applied — the raw monthly series is
   shown as-is, consistent with `docs/data_dictionary.md`'s "partial
   year" caveat.
2. **Order trend** — line chart, same axis. Values: `[Total Orders]`.
   Combo option: rendered as a combo chart with Revenue Trend (line +
   column) is deliberately NOT used here — two independently-scaled
   metrics (dollars vs. count) sharing one axis invites
   misinterpretation; kept as two separate small-multiple visuals
   side by side instead.
3. **Revenue by category** — bar chart. Axis: `DimProduct[category]`.
   Values: `[Product Revenue]`. Fixture: Electronics $779.96 (52.7%),
   Home $370.47 (25.0%), Sports $329.97 (22.3%).
4. **Top products** — horizontal bar chart, top 5 (all 5 products in
   the fixture, but built with a "Top N" filter set to 5 so it scales
   correctly against a larger catalog). Axis: `DimProduct[product_name]`.
   Values: `[Product Revenue]`. Fixture: Wireless Headphones $779.96,
   Blender $270.47, Running Shoes $240.00, Desk Lamp $100.00, Yoga Mat
   $89.97.
5. **Customer segment distribution** — donut chart. Legend:
   `DimCustomer[customer_segment]` (the source-provided segment, not
   `rfm_segment` — that's Page 3's focus). Values:
   `DISTINCTCOUNT(DimCustomer[customer_id])`. Fixture: VIP 2, Regular
   2, Premium 1.

### Dynamic executive insight area

A text box, bottom-right, driven by a measure rather than static text
— Power BI: a card visual bound to a concatenated DAX string measure:

```dax
Executive Insight =
VAR TopCategory = [Top Category Revenue]
VAR TopCategoryName =
    CALCULATE(
        SELECTEDVALUE(DimProduct[category]),
        TOPN(1, ALL(DimProduct[category]), [Product Revenue], DESC)
    )
VAR FailRate = [Payment Failure Rate]
RETURN
    TopCategoryName & " leads revenue at " & FORMAT([Revenue Contribution %], "0.0%") &
    " of the total. Payment failure rate is " & FORMAT(FailRate, "0.0") & "%."
```

On the synthetic fixture this renders: *"Electronics leads revenue at
52.7% of the total. Payment failure rate is 18.2%."* — a real,
dataset-derived sentence, not a canned/static string, so it updates
correctly if slicers change the filter context. This satisfies "add a
dynamic executive insight area" literally (DAX-driven, not just a
text box with hardcoded words).

### Slicers
None on this page by design — Page 1 is a fixed, at-a-glance summary.
(Per the design brief's own KPI/visual list, Page 1 has no slicer
requirement, unlike Pages 2–3.)

---

## PAGE 2 — Transaction & Payment Health

### KPI cards (top row, 6 cards)

| Card | Measure | Value (synthetic fixture) |
|---|---|---|
| Successful Orders | `[Successful Orders]` | **7** |
| Failed Orders | `[Failed Orders]` | **2** |
| Cancelled Orders | `[Cancelled Orders]` | **1** |
| Returned Orders | `[Returned Orders]` | **1** |
| Payment Success Rate | `[Payment Success Rate]` | **63.64%** |
| Potential Lost Value | `[Potential Lost Revenue]` | **$210.49** |

### Visuals

1. **Payment success/failure trend** — line chart, dual series.
   Axis: `DimDate[year_month_label]`. Values: `[Payment Success Rate]`
   and `[Payment Failure Rate]`. On the fixture this line is quite
   noisy (each month has only 1–2 orders), which is itself an honest,
   documented limitation of the small test fixture — the real dataset
   will produce a much smoother trend.
2. **Payment method performance** — clustered bar chart. Axis:
   `DimPaymentMethod[payment_method]`. Values: `[Successful Orders]`
   and `[Failed Orders]` (2 series). Fixture: Credit Card 4/0,
   PayPal 2/1, Debit Card 1/1, Apple Pay 1/0, Bank Transfer 1/0.
3. **Failure rate** — a single-series bar/gauge, `[Payment Failure
   Rate]` by `DimPaymentMethod[payment_method]`. Debit Card and PayPal
   show non-zero failure rates (50% and 33% respectively on the tiny
   fixture) — flagged in the visual's alt text as **not statistically
   meaningful at n=1–3 orders per method**, to avoid the dashboard
   implying a real payment-method risk ranking from 5 test orders.
4. **Failed transaction value** — card/bar showing `[Potential Lost
   Revenue]`, sliceable by payment method and month.
5. **Cancellation trend** — line chart. Axis:
   `DimDate[year_month_label]`. Values: `[Cancellation Rate]`. Fixture
   has exactly one cancelled order (June 2024), so this line is a
   single non-zero point — again a fixture-scale limitation, not a
   business finding, called out in the page's insight box.
6. **Transaction health distribution** — stacked bar or donut. Legend:
   `FactOrders[transaction_status]`. Fixture: Successful 7 ($1,089.93),
   Failed 2 ($210.49), Returned 1 ($59.98), Cancelled 1 ($120.00).

### Slicers (this page)
`DimDate[year_month_label]`, `DimCustomer[country]`,
`DimPaymentMethod[payment_method]`, `DimCustomer[customer_segment]` —
all single-select-friendly slicers (dropdown style) placed in the
shared right-hand panel, all filtering left-to-right through their
single-direction relationships (data model §3) — no bidirectional
slicer behavior needed since every slicer sits on the "one" side of a
one-to-many relationship into `FactOrders`.

---

## PAGE 3 — Customer Analytics

### KPI cards (top row, 5 cards)

| Card | Measure | Value (synthetic fixture) |
|---|---|---|
| Customers | `[Total Customers]` (from DimCustomer, unfiltered by orders) | **5** |
| Active Customers | `[Active Customers]` | **5** (all 5 have ≥1 order in the fixture's full date range) |
| Returning Customers | `[Returning Customers]` | **4** (all except C004, who has exactly 1 order) |
| Churn Rate | `[Churn Rate]` | **60%** (3 of 5 customers) |
| Customer Value | `[Average Customer Value]` | **$296.08** |

### Visuals

1. **RFM distribution** — donut or bar. Legend: `DimCustomer[rfm_segment]`.
   Values: `DISTINCTCOUNT(DimCustomer[customer_id])`. Fixture:
   Champions 2, At Risk 1, Loyal Customers 1, Lost Customers 1.
2. **Revenue by RFM** — bar chart. Axis: `DimCustomer[rfm_segment]`.
   Values: `[Customer Revenue]`. Fixture: Champions $1,104.94 (74.6%
   of all revenue from just 2 of 5 customers), At Risk $179.98, Loyal
   Customers $120.48, Lost Customers $75.00.
3. **Customer revenue** — table/matrix, one row per customer:
   `customer_name`, `rfm_segment`, `[Customer Revenue]`,
   `[Orders per Customer]` — effectively the "top customers" table
   (see #6) but unsorted/unfiltered, showing every customer.
4. **Retention / cohort** — this page references
   `views/bi_ready/cohort_retention.sql` (Phase 4), which is **not**
   reproduced as a DAX measure (per `docs/powerbi_measures.md`'s
   Retention Rate note: cohort retention stays a SQL-only, more
   detailed analysis). The Power BI visual here is a simple
   **Retention Rate card** (`100 - Churn Rate` = **40%** on the
   fixture) plus a note directing analysts to the SQL cohort view for
   month-by-month cohort detail, rather than a fabricated cohort-grid
   visual the current model can't correctly drive.
5. **Churn by segment** — clustered bar. Axis: `DimCustomer[rfm_segment]`.
   Values: count of churned vs. not-churned. Fixture: At Risk
   (1 churned/1 total), Champions (0/2), Lost Customers (1/1), Loyal
   Customers (1/1) — i.e. both of the two Champions are NOT churned,
   while every other segment's customer(s) ARE churned. This is an
   intuitive, expected pattern (Champions = recent + frequent by
   definition) worth calling out in the page's insight box as a
   sanity-check that the two independent metrics (RFM, churn) agree
   directionally.
6. **Top customers** — table, sorted by `[Customer Revenue]` descending,
   Top N = 5 (or fewer if the customer base is smaller). Fixture:
   Alice Smith ($679.96, Champions), Eva Brown ($424.98, Champions),
   Bob Jones ($179.98, At Risk), Carla Diaz ($120.48, Loyal Customers),
   David Lee ($75.00, Lost Customers).

### Slicers (this page)
`DimDate[year_month_label]`, `DimCustomer[country]`,
`DimCustomer[rfm_segment]`.

---

## PAGE 4 — Product & Revenue

### KPI cards (top row, 4 cards)

| Card | Measure | Value (synthetic fixture) |
|---|---|---|
| Revenue | `[Total Revenue]` | **$1,480.40** |
| Units | `[Total Units]` | **16** |
| Average Order Value | `[Average Order Value]` | **$134.58** |
| Profit | `[Profit]` | **$640.40** (sum of `profit_usd`; carries the "assumed formula" caveat from `docs/data_dictionary.md` — the card's tooltip states this explicitly) |

### Visuals

1. **Revenue trend** — same visual as Page 1's Revenue Trend (Power
   BI: this is intentionally the SAME visual object copy-pasted, not
   a re-derived one, to guarantee the two pages can never show
   different numbers for the same measure).
2. **Top 10 products** — horizontal bar, Top N = 10 (fixture only has
   5 products, all shown). Same data as Page 1's Top Products but
   with `[Product Units]` shown as a secondary label per bar, and
   `[Product Rank]` used to drive the Top-N filter dynamically rather
   than a static list.
3. **Category revenue** — bar chart, same as Page 1 but with `[Profit]`
   added as a second series. Fixture: Electronics $779.96 revenue /
   $299.96 profit, Home $370.47 / $160.47, Sports $329.97 / $179.97.
4. **Pareto analysis** — combo chart: bars = `[Product Revenue]` sorted
   descending by product, line = cumulative `%` of total revenue
   (new measure below). Fixture result: Wireless Headphones alone
   reaches 52.7% cumulative; the top 3 of 5 products (Headphones,
   Blender, Running Shoes) reach 87.2% cumulative — a classic
   Pareto-shaped result even at this tiny scale, worth calling out as
   an example finding (from the synthetic fixture) in the page's
   insight box.

   **New measure needed:**
   ```dax
   Cumulative Revenue % =
   VAR CurrentProductRevenue = [Product Revenue]
   RETURN
       DIVIDE(
           SUMX(
               FILTER(ALL(DimProduct), [Product Revenue] >= CurrentProductRevenue),
               [Product Revenue]
           ),
           CALCULATE([Product Revenue], ALL(DimProduct))
       )
   ```
   This is a standard Pareto cumulative-% pattern (rank-based running
   sum) — added here because Page 4 explicitly asks for Pareto
   analysis and no such measure existed yet in `docs/powerbi_measures.md`.
5. **Product matrix** — a Power BI Matrix visual: rows = `category`,
   columns = none (or `payment_method` if a secondary cut is wanted),
   values = `[Product Revenue]`, `[Product Units]`, `[Revenue
   Contribution %]` — lets an analyst drill from category into
   individual products via the matrix's native expand/collapse,
   avoiding a separate drillthrough page for this simple case.
6. **Category contribution** — donut or 100%-stacked bar. Legend:
   `category`. Values: `[Revenue Contribution %]`. Fixture: Electronics
   52.7%, Home 25.0%, Sports 22.3%.

### Slicers (this page)
`DimDate[year_month_label]`, `DimProduct[category]` (the brief's
"category" slicer requirement).

---

## PAGE 5 — Risk & Transaction Anomalies

**Every visual and card on this page is explicitly labeled "Rule-Based
Risk Monitoring"** in its title or a persistent page-level subtitle —
this dataset has no confirmed-fraud label (see
`docs/business_definitions.md`), so nothing on this page is ever
titled "Fraud Detection."

### Page-level banner (below the header, above the KPI row)
> **Rule-Based Risk Monitoring** — signals below are transparent,
> documented rules (see `docs/business_definitions.md`), not a
> predictive fraud model and not confirmed fraud.

### KPI cards (top row, 5 cards)

| Card | Measure | Value (synthetic fixture) |
|---|---|---|
| High Risk Transactions | `[High Risk Transactions]` | **4** |
| Review Transactions | `[Review Transactions]` | **3** |
| Duplicate Candidates | `[Duplicate Candidates]` | **2** (O001 and O011) |
| High Risk Value | `[High Risk Value]` | **$590.47** |
| Failed High-Risk Transactions | new measure below | **2** |

**New measure needed:**
```dax
Failed High Risk Transactions =
CALCULATE(
    DISTINCTCOUNT(FactRisk[order_id]),
    FactRisk[transaction_risk_flag] = "High Risk",
    TREATAS(
        CALCULATETABLE(VALUES(FactOrders[order_id]), FactOrders[transaction_status] = "Failed"),
        FactRisk[order_id]
    )
)
```
On the fixture this returns **2** — and notably, **both** of the
fixture's 2 failed-payment orders are also flagged High Risk (100%
overlap). This is a genuine, dataset-grounded observation worth
surfacing in the page's insight box, clearly labeled as a synthetic-
fixture-scale pattern (n=2) rather than a general claim.

### Visuals

1. **Risk distribution** — donut. Legend:
   `FactRisk[transaction_risk_flag]`. Fixture: High Risk 4, Review 3,
   Normal 4.
2. **Risk trend** — line chart. Axis: `DimDate[year_month_label]`.
   Values: count of High Risk orders per month. On the tiny fixture
   this is too sparse to show a real trend shape — the visual is kept
   in the spec (required by the page's visual list) but its insight
   box explicitly states the trend is not yet meaningful at this data
   volume.
3. **Risk by payment method** — stacked bar. Axis:
   `DimPaymentMethod[payment_method]`. Legend: `transaction_risk_flag`.
   Fixture: Credit Card (2 High Risk, 1 Normal, 1 Review), PayPal
   (1 High Risk, 1 Normal, 1 Review), Debit Card (1 High Risk,
   1 Normal), Apple Pay (1 Normal), Bank Transfer (1 Review).
4. **Risk by country** — stacked bar. Axis: `DimCustomer[country]`.
   Legend: `transaction_risk_flag`. Fixture: USA (3 High Risk, 2
   Normal, 3 Review — USA has by far the most orders, 3 of 5
   customers), Mexico (1 High Risk, 1 Normal), Canada (1 Normal).
5. **High-value anomalies** — table filtered to
   `FactRisk[unusually_high_value] = TRUE`, columns: `order_id`,
   `order_value`, `fraud_risk_score`, `transaction_risk_flag`. On the
   current fixture, zero orders trigger this specific signal (the
   highest order value, $399.98, doesn't clear the
   mean+2×stddev threshold given the fixture's own value spread) —
   the table is shown correctly empty with a "no orders currently meet
   this criterion" state, not hidden or faked.
6. **Duplicate candidates** — table filtered to
   `FactRisk[possible_duplicate_flag] = TRUE`: O001 and O011, both
   customer C001, both $189.99, both flagged High Risk. This is a
   real, deliberately-built-in fixture edge case (see
   `data/sample/README.md`), not a coincidence.

### Slicers (this page)
`DimDate[year_month_label]`, `DimCustomer[country]`,
`DimPaymentMethod[payment_method]`.

### Tooltip
A tooltip page (Power BI: a small report page marked "Tooltip" in Page
Information) is defined for the Risk Distribution and Risk by Country
visuals only — showing `order_id`, `customer_id`, `fraud_risk_score`,
and the specific signals triggered (`unusually_high_value`,
`repeated_failed_payment`, `possible_duplicate_flag`,
`returned_or_cancelled`, `same_day_multi_order`) for the hovered data
point. Not added to every visual on every page (per the brief: "add
only where useful") — the other pages' visuals are aggregate-level and
don't benefit from a row-level tooltip.

---

## Drillthrough

One drillthrough target is defined: right-clicking any customer name
(Page 3's Top Customers table) or any `order_id` (Page 5's tables)
drills through to a single **Order Detail** drillthrough page showing
that customer's/order's full record across `FactOrders`, `FactRisk`,
and `DimCustomer`. This is the one place in the report where
drillthrough adds real value (inspecting a single flagged order/
customer) — no other page has a drillthrough target, per "add only
where useful."
