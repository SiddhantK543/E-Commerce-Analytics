# Data Dictionary

Documents every column defined in `schema/create_tables.sql`. Business
meanings are inferred from column names, the original README, and
schema context — where a meaning genuinely cannot be determined from
these sources, it is marked **"Unconfirmed — verify against loaded
data"** rather than guessed.

## customers

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| customer_id | VARCHAR(20) | Unique customer identifier | `CUST00001` (format unconfirmed) | PK | Deduplicated on load (raw dump had duplicate customer_ids — see `sql/data_quality/01_duplicate_records.sql`) |
| customer_name | VARCHAR(100) | Full name | — | — | — |
| email | VARCHAR(100) | Contact email | — | — | — |
| gender | VARCHAR(10) | Self-reported gender | `Male` / `Female` | — | Confirm full value set before filtering (may include additional categories) |
| age | INTEGER | Age in years | — | — | Flagged if <13 or >100, see data-quality check 04 |
| country | VARCHAR(100) | Customer's country | `USA` | — | — |
| city | VARCHAR(100) | Customer's city | — | — | — |
| customer_segment | VARCHAR(30) | Source-provided segment label | `Regular` / `Premium` / `VIP` | — | Distinct from the independently-derived `customer_rfm.rfm_segment` |
| loyalty_score | NUMERIC | Loyalty/engagement score | — | — | Range/scale unconfirmed — verify against loaded data |
| account_creation_date | DATE | Date the account was created | — | — | — |

## products

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| product_id | VARCHAR(20) | Unique product identifier | — | PK | Deduplicated on load |
| product_name | VARCHAR(255) | Product name | — | — | — |
| category | VARCHAR(100) | Product category | `Electronics` | — | — |
| brand | VARCHAR(100) | Brand name | — | — | — |
| product_rating_avg | NUMERIC | Average customer rating | Expected 1-5 scale | — | Out-of-range values flagged in check 03 |
| stock_quantity | INTEGER | Units in stock | — | — | — |

## orders

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Unique order identifier | — | PK | Deduplicated on load (raw dump had duplicate order_ids, ~25% of rows removed in original project) |
| customer_id | VARCHAR(20) | Ordering customer | — | FK → customers | Orphan-checked in `sql/data_quality/02` |
| order_year | INTEGER | Year the order was placed | 2024-2026 | — | Combined with order_month/order_day to build `dim_date.date_key` |
| order_month | INTEGER | Month the order was placed | 1-12 | — | — |
| order_day | INTEGER | Day of month the order was placed | 1-31 | — | Combination validated via `make_date()`; invalid combos flagged in check 05 |
| order_status | VARCHAR(30) | Order lifecycle status | `Delivered` / `Returned` / possibly `Cancelled` etc. | — | **Unconfirmed full value set** — no CHECK constraint exists; run `sql/data_quality/03_invalid_categorical_values.sql` to confirm before relying on any specific status string beyond `'Returned'` (confirmed used in the original project's queries) |
| return_reason | VARCHAR(100) | Free-text/categorical reason for return | — | — | Only populated for returned orders (assumption, unconfirmed); NULL otherwise |

## order_items

**Grain: one row per (order_id, product_id) — the true transactional fact table.**

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Parent order | — | PK (composite), FK → orders | — |
| product_id | VARCHAR(20) | Line-item product | — | PK (composite), FK → products | — |
| quantity | INTEGER | Units purchased in this line | — | — | Non-positive/NULL flagged in check 04 |
| unit_price_usd | NUMERIC | Price per unit, in USD | — | — | Non-positive/NULL flagged in check 04 |
| discount_percent | NUMERIC | Discount applied, as a percent | 0-100 expected | — | Out-of-range flagged in check 04 |
| discount_amount_usd | NUMERIC | Discount applied, in USD | — | — | Negative values flagged in check 04 |
| total_price_usd | NUMERIC | Final line total after discount/tax | — | — | Reconciled against `unit_price × qty − discount + tax` in check 04e |
| cost_usd | NUMERIC | Cost of goods for this line | — | — | Negative values flagged |
| profit_usd | NUMERIC | `total_price_usd − cost_usd` (assumption — not verified against actual formula) | — | — | — |
| tax_usd | NUMERIC | Tax charged on this line | — | — | Negative values flagged |
| profit_margin_percent | NUMERIC | `profit_usd / total_price_usd × 100` (assumption) | — | — | Original project's Q9 (margin-growth) found this value fixed per product across all months — a known synthetic-data flatness issue |

## payments

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order this payment belongs to | — | PK, FK → orders | 1:1 with orders (one payment record per order) |
| payment_method | VARCHAR(50) | Method used | `PayPal`, `Credit Card`, etc. | — | Original project found near-equal usage across all methods — synthetic-data flatness |
| payment_status | VARCHAR(30) | Outcome of the payment | `Failed` (confirmed used); full set unconfirmed | — | Run check 03 to confirm full value set |
| installment | VARCHAR(10) | **Unconfirmed** — stored as text; could be Yes/No, an installment count, or a plan code | — | — | Run `sql/data_quality/06_text_boolean_fields_audit.sql` before use |
| currency | VARCHAR(10) | Currency code | `USD` (assumption — dataset described as USD-denominated) | — | — |

## shipping

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order this shipment belongs to | — | PK, FK → orders | 1:1 with orders |
| shipping_method | VARCHAR(50) | Method selected | `Economy`, `Standard`, `Express`, `Next Day` (confirmed used in original project) | — | — |
| shipping_cost_usd | NUMERIC | Cost of shipping | — | — | Negative values flagged |
| delivery_days | INTEGER | Days from order to delivery | — | — | Original project found ~7.5 days across ALL methods with <0.02 day variance — flagged as a synthetic-data artifact, not a real SLA difference |
| warehouse | VARCHAR(100) | Fulfilling warehouse | — | — | — |
| shipping_status | VARCHAR(30) | Shipment status | — | — | Unconfirmed full value set — run check 03 |

## reviews

**Grain: one row per (order_id, product_id).**

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order the review is attached to | — | PK (composite), FK → orders | — |
| product_id | VARCHAR(20) | Product being reviewed | — | PK (composite), FK → products | — |
| rating | INTEGER | Star rating | Expected 1-5 | — | Out-of-range flagged in check 03 |
| sentiment | VARCHAR(20) | Sentiment label | `Positive` / `Negative` / `Neutral` (assumption) | — | — |
| customer_feedback | TEXT | Free-text review body | — | — | — |

## marketing

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order this attribution belongs to | — | PK, FK → orders | 1:1 with orders |
| coupon_used | VARCHAR(5) | Whether a coupon was applied | `Yes` / `No` (confirmed used in original queries) | — | Text Yes/No — candidate for boolean cast, run check 06 first |
| coupon_code | VARCHAR(50) | Coupon code applied, if any | — | — | Only populated when coupon_used = 'Yes' (assumption) |
| campaign_source | VARCHAR(50) | Marketing campaign source | — | — | — |
| traffic_source | VARCHAR(50) | Traffic/referral source | — | — | — |

## user_behavior

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order this session belongs to | — | PK, FK → orders | 1:1 with orders |
| device_type | VARCHAR(20) | Device used | `Mobile` / `Desktop` / `Tablet` (assumption) | — | — |
| session_duration_minutes | NUMERIC | Length of the browsing session | — | — | — |
| pages_visited | INTEGER | Pages viewed in the session | — | — | — |
| abandoned_cart_before | VARCHAR(5) | Whether the customer previously abandoned a cart | `Yes` / `No` (assumption) | — | Text Yes/No — candidate for boolean cast, run check 06 first |

## risk_management

| Column | Type | Business meaning | Example | PK/FK | Cleaning/transformation |
|---|---|---|---|---|---|
| order_id | VARCHAR(20) | Order being risk-scored | — | PK, FK → orders | 1:1 with orders |
| fraud_risk_score | NUMERIC(5,2) | Fraud risk score | Conceptually 0-100 (assumption, unconfirmed) | — | Out-of-range flagged in check 04f |
| order_priority | VARCHAR(20) | Fulfillment/review priority | — | — | — |
| support_tickets | INTEGER | Number of support tickets tied to this order | — | — | — |

## Derived / BI-ready objects (not raw schema columns)

These are computed in `views/bi_ready/`, not stored in the raw schema —
documented here for completeness since they are part of the final data
model consumers will see in Power BI.

| Object | Contains | Source |
|---|---|---|
| `dim_date` | Standard calendar attributes (year, quarter, month, week, day-of-week, is_weekend) | `sql/date_dimension/create_dim_date.sql` |
| `customer_rfm` | Recency/Frequency/Monetary scores (1-5 quintiles) and an `rfm_segment` label, independent of `customers.customer_segment` | `views/bi_ready/customer_rfm.sql` |
| `customer_churn` | `is_churned` boolean (6-month inactivity threshold) and `months_since_last_order` | `views/bi_ready/customer_churn.sql` |
| `fraud_flags` | Combined risk flag (percentile rank + score/payment/ticket combination logic) | `views/bi_ready/fraud_flags.sql` |
| `transaction_health` | One row per order combining order/payment/shipping/marketing status | `views/bi_ready/transaction_health.sql` |

## Open questions to resolve once real data is loaded

These are explicitly flagged rather than assumed, per the "no
fabricated results" constraint:

1. Full value sets for `order_status`, `payment_status`,
   `shipping_status`, `sentiment`, `device_type` — confirm via
   `sql/data_quality/03_invalid_categorical_values.sql`.
2. What `payments.installment` actually stores.
3. Whether `profit_usd` and `profit_margin_percent` are truly
   `total_price_usd − cost_usd` and its percent, or computed
   differently upstream.
4. Whether `currency` varies at all, or is USD-only despite the column
   existing (the project's monetary columns are all suffixed `_usd`,
   suggesting a single currency, but the column exists for a reason).
