# 📊 Key Findings & Business Insights

> Analysis of the Global E-Commerce Dataset (2024–2026)
> All figures derived from SQL queries on ~800,000 order records

---

## 1. Revenue Analysis

### Revenue by Product Category

| Category    | Total Revenue   | Share  |
|-------------|-----------------|--------|
| Electronics | $104,138,855    | 34.4%  |
| Home        | $65,329,673     | 21.6%  |
| Sports      | $54,355,229     | 17.9%  |
| Health      | $42,765,644     | 14.1%  |
| Clothing    | $33,754,419     | 11.1%  |
| **Total**   | **$302,343,820**| **100%** |

**Finding:** Electronics dominates revenue at $104M — nearly 60% more than the second-placed Home category. The top 3 categories (Electronics, Home, Sports) account for ~74% of total revenue.

**Business Recommendation:** Prioritize inventory and marketing spend for Electronics. Investigate growth opportunities in Clothing which significantly underperforms.

---

### Year-over-Year Performance

| Year | Total Revenue   | Total Profit   | Profit Margin |
|------|-----------------|----------------|---------------|
| 2024 | $136,822,045    | $54,614,287    | 39.92%        |
| 2025 | $149,990,667    | $59,857,425    | 39.91%        |
| 2026*| $13,531,108     | $5,402,758     | 39.93%        |

*2026 is partial data (January–February only)

**Finding:** Revenue grew ~10% from 2024 to 2025 while profit margins remained stable at 40%, indicating efficient scaling without cost inflation.

**Business Recommendation:** Maintain current cost structure while pursuing growth strategies — the 40% margin is healthy and stable.

---

### Cumulative Revenue Milestones

| Milestone | Reached At       |
|-----------|------------------|
| $100M     | ~October 2024    |
| $150M     | ~January 2025    |
| $200M     | ~June 2025       |
| $250M     | ~September 2025  |
| $300M     | February 2026    |

**Finding:** Business adds approximately $50M in cumulative revenue every 4 months, reflecting a consistent and predictable revenue engine.

---

## 2. Customer Analysis

### Orders by Customer Segment

| Segment  | Total Orders | Share |
|----------|--------------|-------|
| Regular  | 446,152      | 59.1% |
| Premium  | 223,643      | 29.6% |
| VIP      | 74,648       | 9.9%  |
| **Total**| **744,443**  | **100%** |

**Finding:** Regular customers drive order volume at 59%, but order count alone doesn't reflect revenue contribution. VIP customers, while only 10% by volume, likely generate disproportionate revenue per order.

**Business Recommendation:** Run a revenue-per-segment analysis to confirm VIP value. Focus retention efforts on Premium segment — converting Premium to VIP is the highest-value growth lever.

---

### Customer Churn Analysis

| Metric                    | Value            |
|---------------------------|------------------|
| Total customers analyzed  | 744,443          |
| Churned customers         | 555,936          |
| Churn rate                | ~70%             |
| Inactivity threshold      | 6 months         |
| Reference date            | February 2026    |
| Churn cutoff date         | August 2025      |

**Finding:** 70% of customers are classified as churned — they have not placed an order in 6+ months relative to the dataset end date.

**Business Recommendation:** Segment churned customers by their last purchased category and deploy personalized reactivation campaigns. Prioritize VIP and Premium churned customers where recovery revenue potential is highest.

---

## 3. Payment & Marketing Analysis

### Failed Coupon Payment Orders

| Metric                | Value           |
|-----------------------|-----------------|
| Orders affected       | 18,513          |
| Lost revenue          | $7,445,393.63   |

**Finding:** 18,513 orders where customers actively applied a coupon code still resulted in payment failure. These customers demonstrated the highest purchase intent in the dataset — they found a discount, applied it, but never completed the transaction.

**Business Recommendation:**
- Implement payment retry prompts immediately after failure
- Send automated recovery emails within 1 hour of failure
- Offer alternative payment methods at the retry stage
- This represents a **direct and measurable recovery opportunity**

---

### VIP Payment Method Distribution

| Payment Method | Orders | Share  |
|----------------|--------|--------|
| PayPal         | 15,157 | 20.4%  |
| Debit Card     | 15,004 | 20.2%  |
| Bank Transfer  | 14,927 | 20.1%  |
| Credit Card    | 14,884 | 20.0%  |
| Apple Pay      | 14,676 | 19.7%  |

**Finding:** No single payment method dominates among VIP customers — all five are used almost equally.

**Business Recommendation:** Maintain full support for all five payment methods. Removing or degrading any method risks alienating ~20% of the VIP base.

---

## 4. Fraud Risk Analysis

| Metric                         | Value    |
|--------------------------------|----------|
| High-risk orders identified    | 37,581   |
| Detection method               | PERCENT_RANK() per country |
| Threshold                      | Top 5% per country |
| Coverage                       | All countries in dataset |

**Finding:** 37,581 orders (approximately 4.7% of total) were flagged as high-risk using per-country fraud scoring — consistent with the 5% target threshold.

**Business Recommendation:**
- Flag these orders for manual review before fulfillment
- Implement automatic hold for scores above a defined threshold
- Per-country analysis ensures fair detection across all regions — a global threshold would be dominated by high-volume countries

---

## 5. Shipping Performance

### Average Delivery Days by Method

| Shipping Method | Avg Delivery Days |
|-----------------|-------------------|
| Economy         | 7.50              |
| Standard        | 7.50              |
| Express         | 7.51              |
| Next Day        | 7.52              |

**Finding:** ⚠️ All shipping methods deliver in virtually identical timeframes (~7.5 days). "Next Day" averaging 7.52 days is a significant discrepancy from its name.

**Data Note:** This is a synthetic data artifact. In real data, meaningful differences between shipping methods would be expected and would enable genuine SLA performance analysis.

---

## 6. Month-over-Month Revenue Growth

**Period analyzed:** March 2024 — February 2026 (24 months)

| Metric                    | Value        |
|---------------------------|--------------|
| Average monthly revenue   | ~$12.5M      |
| Growth range              | -10% to +15% |
| Largest drop              | -94.53% (Feb 2026 — partial month) |

**Finding:** Revenue is remarkably stable month-over-month with no significant seasonal patterns. February 2026 shows a -94.53% drop attributed entirely to incomplete data for that month.

---

## 7. Data Quality Notes

| Issue                     | Finding                              | Impact                           |
|---------------------------|--------------------------------------|----------------------------------|
| Duplicate primary keys    | Found in raw dump file               | ~25% rows removed during import  |
| Uniform delivery times    | All methods ~7.5 days                | Shipping analysis not meaningful |
| Uniform product quantities| Top products all show identical sales| Product ranking limited          |
| Uniform payment methods   | Near-equal distribution across all   | Preference analysis not possible |
| Partial year data         | 2024 starts March, 2026 ends Feb     | YoY comparisons must be adjusted |

---

*All SQL queries are documented in the `/queries` directory with inline explanations of concepts used and business context for each finding.*
