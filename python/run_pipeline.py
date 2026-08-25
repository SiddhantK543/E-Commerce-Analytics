"""
run_pipeline.py

End-to-end pipeline runner used for Phase 5 testing (and available for
routine local runs): loads data, runs data quality, cleaning, RFM,
segmentation, churn, anomaly detection, transaction analysis, EDA
(with charts), and BI exports, in order -- printing a concise summary
at each stage. Exits non-zero if anything fails or a BI export
verification check fails.

Usage:
    cd python/
    python3 run_pipeline.py
    # or, pointing at a different data folder:
    ECOMMERCE_DATA_DIR=/path/to/real/data python3 run_pipeline.py
"""

from __future__ import annotations

import sys

import data_loader
import data_quality
import data_cleaning
import rfm_analysis
import customer_segmentation
import churn_analysis
import anomaly_detection
import transaction_analysis
import exploratory_analysis
import export_bi_data


def main() -> int:
    print("=" * 70)
    print("STEP 1/8: Loading data")
    print("=" * 70)
    data = data_loader.load_all()
    for name, df in data.items():
        print(f"  loaded {name}: {len(df)} rows")

    print("\n" + "=" * 70)
    print("STEP 2/8: Data quality checks")
    print("=" * 70)
    dq_result = data_quality.run_full_data_quality_suite(data)
    print(dq_result["report"].summary())

    print("\n" + "=" * 70)
    print("STEP 3/8: Cleaning & feature engineering")
    print("=" * 70)
    cleaned = data_cleaning.clean_all(data)
    print(f"  customer_features: {len(cleaned['customer_features'])} rows")
    print(f"  product_features: {len(cleaned['product_features'])} rows")

    print("\n" + "=" * 70)
    print("STEP 4/8: RFM analysis & customer segmentation")
    print("=" * 70)
    rfm = rfm_analysis.compute_rfm(data["customers"], data["orders"], data["order_items"])
    print(rfm[["customer_id", "rfm_segment", "rfm_total_score"]].to_string(index=False))
    seg_summary = customer_segmentation.summarize_by_rfm_segment(rfm)
    print(seg_summary.to_string(index=False))

    print("\n" + "=" * 70)
    print("STEP 5/8: Churn analysis")
    print("=" * 70)
    churn = churn_analysis.compute_customer_churn(data["customers"], data["orders"])
    print(f"  Overall churn rate: {churn_analysis.overall_churn_rate(churn)}%")

    print("\n" + "=" * 70)
    print("STEP 6/8: Anomaly detection & transaction analysis")
    print("=" * 70)
    risk_flags = anomaly_detection.build_transaction_risk_flags(
        data["orders"], data["order_items"], data["payments"], data["risk_management"]
    )
    print(f"  Risk flag counts: {risk_flags['transaction_risk_flag'].value_counts().to_dict()}")
    health = transaction_analysis.build_transaction_health(data["orders"], data["order_items"], data["payments"])
    kpis = transaction_analysis.kpi_summary(health)
    print(f"  Payment success rate: {kpis['payment_success_rate_pct']}%")
    print(f"  Payment failure rate: {kpis['payment_failure_rate_pct']}%")

    print("\n" + "=" * 70)
    print("STEP 7/8: Exploratory analysis (with charts)")
    print("=" * 70)
    eda_results = exploratory_analysis.run_full_eda(data, generate_charts=True)
    print(f"  Repeat customer rate: {exploratory_analysis.repeat_customer_rate(cleaned['customer_features'])}%")

    print("\n" + "=" * 70)
    print("STEP 8/8: BI-ready exports")
    print("=" * 70)
    written = export_bi_data.export_all(data)
    checks = export_bi_data.verify_exports(written, data)
    all_passed = all(checks.values())
    for check_name, passed in checks.items():
        print(f"  {'✅ PASS' if passed else '❌ FAIL'}  {check_name}")

    print("\n" + "=" * 70)
    if all_passed:
        print("PIPELINE COMPLETE -- all stages ran, all BI export checks passed.")
        return 0
    else:
        print("PIPELINE COMPLETE WITH FAILURES -- see BI export checks above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
