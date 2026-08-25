# DAX Measures — Copy/Paste Reference

Condensed, implementation-focused version of the full measure library
in `docs/powerbi_measures.md`. **That file is authoritative** for
business definitions and caveats — read it before using any measure
here, especially the ⚠️ callouts on cross-fact-table filtering
(Successful Revenue, Potential Lost Revenue, High Risk Value) and the
partial-period caveat on YoY Growth %.

Create a dedicated measure table (e.g. `_Measures`) in Power BI rather
than scattering these across fact tables.

```dax
-- ===== SALES / REVENUE =====

Total Revenue = SUM(FactOrderItems[total_price_usd])

Gross Transaction Value = [Total Revenue]

Successful Revenue =
CALCULATE(
    [Total Revenue],
    TREATAS(
        CALCULATETABLE(VALUES(FactOrders[order_id]), FactOrders[transaction_status] = "Successful"),
        FactOrderItems[order_id]
    )
)

Potential Lost Revenue =
CALCULATE(
    [Total Revenue],
    TREATAS(
        CALCULATETABLE(VALUES(FactOrders[order_id]), FactOrders[transaction_status] = "Failed"),
        FactOrderItems[order_id]
    )
)

Average Order Value = DIVIDE([Total Revenue], [Total Orders])

Total Orders = DISTINCTCOUNT(FactOrders[order_id])

Total Customers = DISTINCTCOUNT(FactOrders[customer_id])

Total Units = SUM(FactOrderItems[quantity])


-- ===== TRANSACTION HEALTH =====

Successful Orders =
CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[transaction_status] = "Successful")

Failed Orders =
CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[transaction_status] = "Failed")

Cancelled Orders =
CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[order_status] = "Cancelled")

Returned Orders =
CALCULATE(DISTINCTCOUNT(FactOrders[order_id]), FactOrders[order_status] = "Returned")

Payment Success Rate = DIVIDE([Successful Orders], [Total Orders]) * 100

Payment Failure Rate = DIVIDE([Failed Orders], [Total Orders]) * 100

Cancellation Rate = DIVIDE([Cancelled Orders], [Total Orders]) * 100

Return Rate = DIVIDE([Returned Orders], [Total Orders]) * 100


-- ===== CUSTOMER =====

New Customers =
CALCULATE(
    DISTINCTCOUNT(FactOrders[customer_id]),
    FILTER(
        VALUES(FactOrders[customer_id]),
        CALCULATE(MIN(FactOrders[order_date])) IN VALUES(DimDate[date_key])
    )
)

Returning Customers =
CALCULATE(
    DISTINCTCOUNT(FactOrders[customer_id]),
    FILTER(VALUES(FactOrders[customer_id]), CALCULATE(DISTINCTCOUNT(FactOrders[order_id])) > 1)
)

Active Customers = DISTINCTCOUNT(FactOrders[customer_id])

Churned Customers =
CALCULATE(DISTINCTCOUNT(DimCustomer[customer_id]), DimCustomer[is_churned] = TRUE)

Churn Rate = DIVIDE([Churned Customers], DISTINCTCOUNT(DimCustomer[customer_id])) * 100

Retention Rate = 100 - [Churn Rate]

Customer Revenue = [Total Revenue]

Orders per Customer = DIVIDE([Total Orders], [Total Customers])

Average Customer Value = DIVIDE([Total Revenue], [Total Customers])

-- RFM segments/scores are NOT DAX measures -- use DimCustomer[rfm_segment],
-- [recency_score], [frequency_score], [monetary_score] directly as slicers/columns.


-- ===== RISK =====

High Risk Transactions =
CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[transaction_risk_flag] = "High Risk")

Review Transactions =
CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[transaction_risk_flag] = "Review")

Duplicate Candidates =
CALCULATE(DISTINCTCOUNT(FactRisk[order_id]), FactRisk[possible_duplicate_flag] = TRUE)

High Risk Value =
CALCULATE(
    [Total Revenue],
    TREATAS(
        CALCULATETABLE(VALUES(FactRisk[order_id]), FactRisk[transaction_risk_flag] = "High Risk"),
        FactOrderItems[order_id]
    )
)


-- ===== PRODUCT =====

Product Revenue = [Total Revenue]

Product Units = [Total Units]

Top Product Revenue = MAXX(VALUES(DimProduct[product_id]), [Product Revenue])

Product Rank = RANKX(ALL(DimProduct[product_id]), [Product Revenue], , DESC, DENSE)

Top Category Revenue = MAXX(VALUES(DimProduct[category]), [Product Revenue])

Category Rank = RANKX(ALL(DimProduct[category]), [Product Revenue], , DESC, DENSE)

Revenue Contribution % =
DIVIDE([Product Revenue], CALCULATE([Product Revenue], ALL(DimProduct)))

Profit = SUM(FactOrderItems[profit_usd])


-- ===== TIME INTELLIGENCE =====
-- Requires DimDate marked as the model's Date Table on [date_key]

Revenue MTD = TOTALMTD([Total Revenue], DimDate[date_key])

Revenue YTD = TOTALYTD([Total Revenue], DimDate[date_key])

Previous Month Revenue =
CALCULATE([Total Revenue], DATEADD(DimDate[date_key], -1, MONTH))

MoM Revenue Growth % =
DIVIDE([Total Revenue] - [Previous Month Revenue], [Previous Month Revenue])

Rolling 3-Month Revenue =
CALCULATE([Total Revenue], DATESINPERIOD(DimDate[date_key], MAX(DimDate[date_key]), -3, MONTH))

Previous Year Revenue =
CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(DimDate[date_key]))

YoY Growth % =
DIVIDE([Total Revenue] - [Previous Year Revenue], [Previous Year Revenue])

-- Prefer this version on dashboard visuals -- see docs/powerbi_measures.md
-- for why the partial-period edge months (Mar 2024, Jan-Feb 2026) are flagged blank:
YoY Growth % (partial-period flagged) =
VAR IsPartialEdge =
    OR(
        MIN(DimDate[month_number]) IN {1, 2} && MAX(DimDate[year]) = 2026,
        MIN(DimDate[month_number]) = 3 && MIN(DimDate[year]) = 2024
    )
RETURN
    IF(IsPartialEdge, BLANK(), [YoY Growth %])
```
