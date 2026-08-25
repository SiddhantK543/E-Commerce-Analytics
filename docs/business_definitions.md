# Business Definitions

This document is the single source of truth for every business term
used in the Transaction Health & Data-Quality layer (Phase 3) and
should be used consistently in all later SQL, Python, and Power BI
work. Where the underlying schema does not support a term as commonly
understood, that limitation is stated explicitly rather than papered
over.

## Confirmed status values in this project

Before defining anything else: the schema places **no CHECK/enum
constraint** on any status column, so the exact value sets below are
only confirmed for the values this project's queries have actually
used or the small synthetic test dataset built in Phase 2/3. **Run
`sql/data_quality/03_invalid_categorical_values.sql` against the real
dataset once loaded, and update this table if additional values
exist.**

| Column | Confirmed values in use | Notes |
|---|---|---|
| `orders.order_status` | `Delivered`, `Returned`, `Cancelled` | No confirmed `Refunded` or `Pending` value exists |
| `payments.payment_status` | `Success`, `Failed` | No confirmed `Pending` value exists yet — the classification logic below handles one defensively in case it appears, but it has not been observed |
| `shipping.shipping_status` | `Delivered`, `Cancelled` (assumption, unconfirmed beyond original project usage) | Verify against real data |

## Core financial definitions

| Term | Definition | Formula |
|---|---|---|
| **Order value** | The total transaction value of one order, summed across all its line items. | `SUM(order_items.total_price_usd)` grouped by `order_id` |
| **Gross transaction value** | The order value of ALL orders, regardless of payment outcome or order status. | `SUM(order_value)` across every order |
| **Successful revenue** | Order value counted ONLY for orders where the payment succeeded and the order was not cancelled or returned. | `SUM(order_value) WHERE transaction_status = 'Successful'` |
| **Potential lost revenue** | Order value counted ONLY for orders where the payment failed. This is a *potential* figure — it represents revenue that did not convert, not a guaranteed recoverable amount. | `SUM(order_value) WHERE payment_status = 'Failed'` |
| **Net revenue** | **Not currently computable.** Net revenue would require confirmed refund amounts and/or transaction fees, neither of which exist as columns in this schema. `order_items.profit_usd` measures product-level profit (revenue minus cost of goods), which is a related but distinct concept — it is NOT "net revenue after refunds/fees." |
| **Profit** | `order_items.profit_usd`, summed per order. Assumed formula (per `docs/data_dictionary.md`): `total_price_usd - cost_usd`. Not independently verified against real data. |

**Critical rule:** gross transaction value, successful revenue, and
potential lost revenue are never added together as if they were three
parts of one total spend — successful revenue and potential lost
revenue are each subsets of gross transaction value, not additions to
it. (There may also be a small "unclassified" remainder if any order
falls outside both categories — see `sql/payments/payment_health.sql`
query 8 for the full reconciliation.)

## Transaction status classification

Implemented in `views/bi_ready/vw_transaction_health.sql` as
`transaction_status`:

| transaction_status | Rule | Confirmed to occur in this project? |
|---|---|---|
| **Successful** | `payment_status = 'Success'` AND `order_status` not in `('Cancelled','Returned')` | ✅ Yes |
| **Failed** | `payment_status = 'Failed'` | ✅ Yes |
| **Cancelled** | `order_status = 'Cancelled'` | ✅ Yes |
| **Returned** | `order_status = 'Returned'` | ✅ Yes |
| **Pending** | `payment_status = 'Pending'` | ❌ Not observed — logic present defensively, in case this value exists in the real dataset. If it never appears, this branch is simply unreachable and does no harm. |
| **Refunded** | **Not implemented.** There is no `Refunded` value in `order_status` or `payment_status`, and no refund-amount column anywhere in the schema. A `Returned` order MAY imply a refund happened in the real business process, but this is an unconfirmed assumption, not something the data states. We do not classify any transaction as "Refunded." |
| **Unclassified** | Anything not matching the rules above (e.g. a NULL payment_status, or an order_status value not yet seen) | Should be rare/zero if the confirmed value sets above are complete — a non-zero count here is itself a data-quality signal worth investigating |
| **Suspicious** | **Not part of `transaction_status`.** Suspicion is a risk assessment, not a transaction outcome, and conflating the two would make it impossible to see "this order succeeded AND is also suspicious" (an important combination for fraud review). Suspicion is instead captured separately as `transaction_risk_flag` (see below). |

### transaction_health_flag (simplified 3-value summary)

| transaction_health_flag | Maps from transaction_status |
|---|---|
| **Healthy** | Successful |
| **At Risk** | Cancelled, Returned |
| **Lost** | Failed |
| **Unclassified** | Pending, Unclassified |

## Refunds & cancellations terminology

| Term | Definition |
|---|---|
| **Cancellation** | An order where `order_status = 'Cancelled'`. |
| **Return** | An order where `order_status = 'Returned'`. `return_reason` provides the stated reason where populated. |
| **Refund** | **Not directly observable.** No column records whether money was actually returned to the customer, or how much. Any dollar figure associated with a returned/cancelled order is labeled **"order value associated with returns/cancellations"**, never "refund amount," because we do not know the actual refunded sum (which could differ from the order value — e.g. partial refunds, restocking fees). |
| **Cancellation rate** | `COUNT(orders WHERE order_status = 'Cancelled') / COUNT(all orders) × 100` |
| **Return rate** | `COUNT(orders WHERE order_status = 'Returned') / COUNT(all orders) × 100` |

## Payment terminology

| Term | Definition |
|---|---|
| **Successful transaction** | `payment_status = 'Success'` |
| **Failed transaction** / **Payment failure** | `payment_status = 'Failed'` |
| **Transaction success rate** | `COUNT(payment_status = 'Success') / COUNT(all payments) × 100` |
| **Payment failure rate** | `COUNT(payment_status = 'Failed') / COUNT(all payments) × 100` |

## Risk & anomaly terminology

| Term | Definition |
|---|---|
| **Duplicate transaction (candidate)** | A line item that matches another line item on customer, product, exact amount, exact order date, and payment method (see `sql/risk_fraud/03_duplicate_transaction_detection.sql`). This is a candidate for review, not a confirmed duplicate — it could be a legitimate repeat purchase. |
| **Confirmed duplicate** | **Not determined by any query in this project.** Requires human review of each flagged candidate; the data alone cannot distinguish "duplicate charge" from "customer bought two of the same thing on the same day." |
| **Suspicious transaction** | An order where `transaction_risk_flag = 'High Risk'` (see `views/bi_ready/transaction_risk_flags.sql`) — i.e., two or more rule-based risk signals fired, or the fraud score alone exceeds the illustrative threshold. This is a **rule-based framework**, explicitly not a machine-learning model, and is intended to prioritize orders for human review, not to make an automated fraud determination. |
| **transaction_risk_flag** | One of `Normal`, `Review`, `High Risk` — see `views/bi_ready/transaction_risk_flags.sql` for the exact signal-counting logic. |

## Customer/segmentation terminology (carried over from Phase 2, referenced here for consistency)

| Term | Definition |
|---|---|
| **Customer segment** | The source-provided categorical label in `customers.customer_segment` (`Regular`/`Premium`/`VIP`) — NOT derived by this project. |
| **RFM segment** | Independently derived in `views/bi_ready/customer_rfm.sql` from Recency/Frequency/Monetary quintile scores. Distinct from `customer_segment` above. |
| **Churn** | A customer whose most recent order is more than 6 months before the latest order date anywhere in the dataset (see `views/bi_ready/customer_churn.sql`). This is a project-defined threshold, not a business-confirmed definition. |

## Summary of what this project explicitly does NOT claim

- No net revenue figure (no fee/refund-amount data to support it)
- No confirmed "Refunded" or "Pending" transactions (the schema/data doesn't demonstrably contain them)
- No confirmed fraud determinations — only rule-based risk prioritization
- No confirmed duplicate transactions — only duplicate candidates for review
- No claim that the 6-month churn threshold, the 2-standard-deviation "unusually high value" threshold, or the fraud-score-80 threshold are statistically optimized; they are documented, explainable starting points
