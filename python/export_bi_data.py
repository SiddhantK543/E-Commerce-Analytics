"""
export_bi_data.py

Exports clean, BI-ready analytical datasets to CSV for Power BI (which
can import these directly, as an alternative to connecting live to
PostgreSQL's views/bi_ready/ objects). Every export here corresponds to
-- and should reconcile with -- a SQL view of the same purpose; see
docs/python_analytics.md, "SQL/Python Consistency" for the verified
comparison.

Outputs (only genuinely useful, non-redundant datasets -- no raw-table
re-exports):
  - bi_transaction_health.csv : one row per order, transaction_status +
    value breakdown (mirrors vw_transaction_health.sql)
  - bi_customer_rfm.csv       : one row per customer, RFM scores + segment
    (mirrors customer_rfm.sql)
  - bi_customer_churn.csv     : one row per customer, is_churned + recency
    (mirrors customer_churn.sql)
  - bi_product_performance.csv: one row per product, revenue/profit/units
  - bi_revenue_trends.csv     : one row per calendar month, revenue/orders/AOV
  - bi_risk_analysis.csv      : one row per order, risk signals + flag
    (mirrors transaction_risk_flags.sql)
  - bi_order_items.csv        : one row per (order_id, product_id) line
    item -- mirrors views/bi_ready/fact_order_items.sql exactly (added
    to close the gap documented in powerbi/model_design.md §4: Power
    BI's FactOrderItems previously had no flat-file source, only the
    live-PostgreSQL view)

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict

import pandas as pd

from config import EXPORT_DIR, ensure_output_dirs
import data_loader
import transaction_analysis
import anomaly_detection
import exploratory_analysis
from rfm_analysis import compute_rfm
from churn_analysis import compute_customer_churn
from data_cleaning import aggregate_product_features, build_order_date


def export_all(data: Dict[str, pd.DataFrame] | None = None) -> Dict[str, Path]:
    """
    Runs every analysis module and writes its BI-ready output to
    config.EXPORT_DIR. Returns a dict of {export_name: path_written}
    for verification/testing.
    """
    ensure_output_dirs()
    if data is None:
        data = data_loader.load_all()

    written: Dict[str, Path] = {}

    # bi_transaction_health.csv
    health = transaction_analysis.build_transaction_health(data["orders"], data["order_items"], data["payments"])
    path = EXPORT_DIR / "bi_transaction_health.csv"
    health.to_csv(path, index=False)
    written["bi_transaction_health"] = path

    # bi_customer_rfm.csv
    rfm = compute_rfm(data["customers"], data["orders"], data["order_items"])
    path = EXPORT_DIR / "bi_customer_rfm.csv"
    rfm.to_csv(path, index=False)
    written["bi_customer_rfm"] = path

    # bi_customer_churn.csv
    churn = compute_customer_churn(data["customers"], data["orders"])
    path = EXPORT_DIR / "bi_customer_churn.csv"
    churn.to_csv(path, index=False)
    written["bi_customer_churn"] = path

    # bi_product_performance.csv
    product_perf = aggregate_product_features(data["products"], data["order_items"])
    path = EXPORT_DIR / "bi_product_performance.csv"
    product_perf.to_csv(path, index=False)
    written["bi_product_performance"] = path

    # bi_revenue_trends.csv
    revenue_trend = exploratory_analysis.monthly_revenue_trend(data["orders"], data["order_items"])
    path = EXPORT_DIR / "bi_revenue_trends.csv"
    revenue_trend.to_csv(path, index=False)
    written["bi_revenue_trends"] = path

    # bi_risk_analysis.csv
    risk = anomaly_detection.build_transaction_risk_flags(
        data["orders"], data["order_items"], data["payments"], data["risk_management"]
    )
    path = EXPORT_DIR / "bi_risk_analysis.csv"
    risk.to_csv(path, index=False)
    written["bi_risk_analysis"] = path

    # bi_order_items.csv -- line-item grain, mirrors fact_order_items.sql exactly
    orders_with_date = build_order_date(data["orders"])[["order_id", "customer_id", "order_date"]]
    order_items = data["order_items"].merge(orders_with_date, on="order_id", how="inner")
    order_items = order_items[[
        "order_id", "product_id", "customer_id", "order_date", "quantity",
        "unit_price_usd", "discount_percent", "discount_amount_usd", "total_price_usd",
        "cost_usd", "profit_usd", "tax_usd", "profit_margin_percent",
    ]]
    path = EXPORT_DIR / "bi_order_items.csv"
    order_items.to_csv(path, index=False)
    written["bi_order_items"] = path

    return written


def verify_exports(written: Dict[str, Path], data: Dict[str, pd.DataFrame]) -> Dict[str, bool]:
    """
    Basic sanity checks on the exported files: correct row counts (no
    inflation), no duplicate primary keys, expected columns present.
    Used by the Phase 5 test run (see docs/python_analytics.md,
    "Testing").
    """
    checks = {}

    health = pd.read_csv(written["bi_transaction_health"])
    checks["transaction_health_row_count_matches_orders"] = len(health) == len(data["orders"])
    checks["transaction_health_no_duplicate_order_id"] = not health["order_id"].duplicated().any()

    rfm = pd.read_csv(written["bi_customer_rfm"])
    checks["customer_rfm_no_duplicate_customer_id"] = not rfm["customer_id"].duplicated().any()
    checks["customer_rfm_scores_in_valid_range"] = rfm[
        ["recency_score", "frequency_score", "monetary_score"]
    ].isin(range(1, 6)).all().all()

    churn = pd.read_csv(written["bi_customer_churn"])
    checks["customer_churn_no_duplicate_customer_id"] = not churn["customer_id"].duplicated().any()
    checks["customer_churn_is_churned_is_boolean"] = churn["is_churned"].isin([True, False]).all()

    risk = pd.read_csv(written["bi_risk_analysis"])
    checks["risk_analysis_no_duplicate_order_id"] = not risk["order_id"].duplicated().any()
    checks["risk_analysis_flag_values_valid"] = risk["transaction_risk_flag"].isin(
        ["Normal", "Review", "High Risk"]
    ).all()

    revenue = pd.read_csv(written["bi_revenue_trends"])
    checks["revenue_total_matches_transaction_health"] = abs(
        revenue["revenue"].sum() - health["order_value"].sum()
    ) < 0.01

    order_items = pd.read_csv(written["bi_order_items"])
    checks["order_items_no_duplicate_line_items"] = not order_items.duplicated(
        subset=["order_id", "product_id"]
    ).any()
    checks["order_items_revenue_matches_transaction_health"] = abs(
        order_items["total_price_usd"].sum() - health["order_value"].sum()
    ) < 0.01

    return checks


if __name__ == "__main__":
    data = data_loader.load_all()
    written = export_all(data)

    print("Exported files:")
    for name, path in written.items():
        print(f"  {name}: {path}")

    print("\nVerification checks:")
    checks = verify_exports(written, data)
    all_passed = True
    for check_name, passed in checks.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status}  {check_name}")
        all_passed = all_passed and passed

    if not all_passed:
        raise SystemExit("One or more BI export verification checks FAILED -- see above.")
    print("\nAll BI export verification checks passed.")
