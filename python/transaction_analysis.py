"""
transaction_analysis.py

Calculates transaction-health KPIs using the EXACT business definitions
established in docs/business_definitions.md and implemented in
views/bi_ready/vw_transaction_health.sql / kpi_transaction_health.sql
(Phase 3/4). Does not introduce any new/conflicting KPI definitions.

Key terminology (see docs/business_definitions.md for full detail):
  - transaction_status: Successful / Failed / Cancelled / Returned /
    Pending / Unclassified (mutually exclusive per order)
  - gross_transaction_value, successful_revenue, and
    potential_lost_revenue are SUBSETS of one another's total, never
    summed together as if independent

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

import pandas as pd

from data_cleaning import build_order_date, aggregate_order_items_to_order_level


def build_transaction_health(orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame) -> pd.DataFrame:
    """
    One row per order, with order_value and a transaction_status
    classification -- the pandas equivalent of
    views/bi_ready/vw_transaction_health.sql (grain-safety: order_items
    aggregated to order_value BEFORE merging with orders/payments, for
    the same reason documented in that SQL view and in
    data_cleaning.aggregate_order_items_to_order_level).
    """
    orders = build_order_date(orders_df)
    order_value = aggregate_order_items_to_order_level(order_items_df)[["order_id", "order_value"]]

    result = orders.merge(order_value, on="order_id", how="left")
    result["order_value"] = result["order_value"].fillna(0)
    result = result.merge(payments_df[["order_id", "payment_status", "payment_method"]], on="order_id", how="left")

    def _status(row: pd.Series) -> str:
        if row["payment_status"] == "Failed":
            return "Failed"
        if row["order_status"] == "Cancelled":
            return "Cancelled"
        if row["order_status"] == "Returned":
            return "Returned"
        if row["payment_status"] == "Pending":
            return "Pending"
        if row["payment_status"] == "Success" and row["order_status"] not in ("Cancelled", "Returned"):
            return "Successful"
        return "Unclassified"

    result["transaction_status"] = result.apply(_status, axis=1)

    result["successful_value"] = result["order_value"].where(result["transaction_status"] == "Successful", 0)
    result["affected_order_value"] = result["order_value"].where(
        result["order_status"].isin(["Cancelled", "Returned"]), 0
    )
    result["potential_lost_value"] = result["order_value"].where(result["transaction_status"] == "Failed", 0)

    return result


def kpi_summary(transaction_health_df: pd.DataFrame) -> dict:
    """
    Single-row KPI summary matching views/bi_ready/kpi_transaction_health.sql:
    total transactions, successful/failed/cancelled/returned counts and
    rates, potential lost revenue, successful revenue, affected order
    value, and average order value.
    """
    df = transaction_health_df
    total = len(df)

    def _rate(status: str) -> float:
        return round(100 * (df["transaction_status"] == status).sum() / total, 2) if total else 0.0

    return {
        "total_orders": total,
        "total_order_value": round(df["order_value"].sum(), 2),
        "successful_orders": int((df["transaction_status"] == "Successful").sum()),
        "failed_orders": int((df["transaction_status"] == "Failed").sum()),
        "cancelled_orders": int((df["transaction_status"] == "Cancelled").sum()),
        "returned_orders": int((df["transaction_status"] == "Returned").sum()),
        "payment_success_rate_pct": _rate("Successful"),
        "payment_failure_rate_pct": _rate("Failed"),
        "cancellation_rate_pct": _rate("Cancelled"),
        "return_rate_pct": _rate("Returned"),
        "potential_lost_revenue": round(df["potential_lost_value"].sum(), 2),
        "total_successful_revenue": round(df["successful_value"].sum(), 2),
        "total_affected_order_value": round(df["affected_order_value"].sum(), 2),
        "average_order_value": round(df["order_value"].mean(), 2) if total else 0.0,
    }


def risk_flagged_transaction_count(risk_flags_df: pd.DataFrame) -> dict:
    """Counts of orders by transaction_risk_flag (Normal/Review/High Risk), from anomaly_detection output."""
    counts = risk_flags_df["transaction_risk_flag"].value_counts().to_dict()
    return {
        "normal": counts.get("Normal", 0),
        "review": counts.get("Review", 0),
        "high_risk": counts.get("High Risk", 0),
    }


if __name__ == "__main__":
    import data_loader
    import anomaly_detection

    data = data_loader.load_all()
    health = build_transaction_health(data["orders"], data["order_items"], data["payments"])
    kpis = kpi_summary(health)

    print("=== KPI Summary ===")
    for k, v in kpis.items():
        print(f"  {k}: {v}")

    flags = anomaly_detection.build_transaction_risk_flags(
        data["orders"], data["order_items"], data["payments"], data["risk_management"]
    )
    print("\n=== Risk-flagged transaction counts ===")
    print(risk_flagged_transaction_count(flags))
