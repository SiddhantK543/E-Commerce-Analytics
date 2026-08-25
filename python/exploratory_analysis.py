"""
exploratory_analysis.py

Independent (pandas-based) exploratory analysis, organized around the
four business areas the Phase 5 spec asks for: Sales, Customers,
Transactions, Risk. Cross-validates SQL findings (sql/transactions/,
sql/customers/, sql/payments/, sql/risk_fraud/) rather than duplicating
them blindly -- where a number should match a known SQL result, the
docstring says so.

Each function returns a small, focused DataFrame (or dict) plus,
where useful, calls visualization.py to produce a single supporting
chart. Charts are generated on demand via run_full_eda(), not
automatically on import.

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

from typing import Dict

import pandas as pd

from data_cleaning import build_order_date, aggregate_order_items_to_order_level, aggregate_product_features
import transaction_analysis
import anomaly_detection
import visualization


# ----------------------------------------------------------------------
# Sales
# ----------------------------------------------------------------------

def monthly_revenue_trend(orders_df: pd.DataFrame, order_items_df: pd.DataFrame) -> pd.DataFrame:
    """Revenue and order count per calendar month. Cross-validates sql/transactions/03/04."""
    orders = build_order_date(orders_df)
    order_value = aggregate_order_items_to_order_level(order_items_df)
    merged = orders.merge(order_value, on="order_id", how="left")
    merged["order_value"] = merged["order_value"].fillna(0)
    merged["year_month"] = merged["order_date"].dt.to_period("M").astype(str)

    grouped = merged.groupby("year_month").agg(
        revenue=("order_value", "sum"), order_count=("order_id", "nunique"),
    ).reset_index().sort_values("year_month")
    grouped["revenue"] = grouped["revenue"].round(2)
    grouped["average_order_value"] = (grouped["revenue"] / grouped["order_count"]).round(2)
    return grouped


def category_performance(order_items_df: pd.DataFrame, products_df: pd.DataFrame) -> pd.DataFrame:
    """Revenue/profit/units by product category. Cross-validates sql/products_revenue/04."""
    merged = order_items_df.merge(products_df[["product_id", "category"]], on="product_id", how="left")
    grouped = merged.groupby("category").agg(
        revenue=("total_price_usd", "sum"), profit=("profit_usd", "sum"), units_sold=("quantity", "sum"),
    ).reset_index()
    grouped["revenue"] = grouped["revenue"].round(2)
    grouped["profit"] = grouped["profit"].round(2)
    return grouped.sort_values("revenue", ascending=False).reset_index(drop=True)


def product_performance(products_df: pd.DataFrame, order_items_df: pd.DataFrame) -> pd.DataFrame:
    """Per-product revenue/profit/units sold. Wraps data_cleaning.aggregate_product_features."""
    return aggregate_product_features(products_df, order_items_df).sort_values("product_revenue", ascending=False)


# ----------------------------------------------------------------------
# Customers
# ----------------------------------------------------------------------

def customer_distribution(customers_df: pd.DataFrame) -> Dict[str, pd.DataFrame]:
    """Simple demographic distributions: by segment, country, gender."""
    return {
        "by_segment": customers_df["customer_segment"].value_counts().rename_axis("customer_segment").reset_index(name="count"),
        "by_country": customers_df["country"].value_counts().rename_axis("country").reset_index(name="count"),
        "by_gender": customers_df["gender"].value_counts().rename_axis("gender").reset_index(name="count"),
    }


def customer_value_distribution(customer_features_df: pd.DataFrame) -> pd.DataFrame:
    """Distribution summary (min/25%/50%/75%/max) of customer_revenue and purchase_frequency."""
    return customer_features_df[["customer_revenue", "average_order_value", "purchase_frequency"]].describe().round(2)


def repeat_customer_rate(customer_features_df: pd.DataFrame) -> float:
    """% of customers with more than one order -- a simple, explainable loyalty proxy."""
    repeat = (customer_features_df["customer_order_count"] > 1).sum()
    return round(100 * repeat / len(customer_features_df), 2) if len(customer_features_df) else 0.0


# ----------------------------------------------------------------------
# Transactions
# ----------------------------------------------------------------------

def transaction_health_summary(orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame) -> dict:
    """Wraps transaction_analysis.kpi_summary -- see that module for the authoritative KPI definitions."""
    health = transaction_analysis.build_transaction_health(orders_df, order_items_df, payments_df)
    return transaction_analysis.kpi_summary(health)


# ----------------------------------------------------------------------
# Risk
# ----------------------------------------------------------------------

def risk_score_distribution(risk_management_df: pd.DataFrame) -> pd.DataFrame:
    """Distribution summary of fraud_risk_score."""
    return risk_management_df[["fraud_risk_score"]].describe().round(2)


def high_risk_transactions(orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame, risk_management_df: pd.DataFrame) -> pd.DataFrame:
    """Orders flagged 'High Risk' by anomaly_detection.build_transaction_risk_flags, sorted by fraud score."""
    flags = anomaly_detection.build_transaction_risk_flags(orders_df, order_items_df, payments_df, risk_management_df)
    return flags[flags["transaction_risk_flag"] == "High Risk"].sort_values("fraud_risk_score", ascending=False)


def duplicate_candidates(orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame) -> pd.DataFrame:
    """Orders flagged as possible-duplicate candidates (see anomaly_detection.flag_possible_duplicates)."""
    orders = orders_df.copy()
    orders["possible_duplicate_flag"] = anomaly_detection.flag_possible_duplicates(orders_df, order_items_df, payments_df).values
    return orders[orders["possible_duplicate_flag"]]


def failed_payment_patterns(orders_df: pd.DataFrame, payments_df: pd.DataFrame) -> pd.DataFrame:
    """Per-customer failed-payment counts, sorted descending. Cross-validates sql/payments/payment_health.sql query 4."""
    counts = anomaly_detection.flag_repeated_failed_payments(orders_df, payments_df)
    return counts.sort_values("failed_payment_count", ascending=False)


def run_full_eda(data: Dict[str, pd.DataFrame], generate_charts: bool = True) -> Dict[str, object]:
    """Runs every EDA function above and returns a dict of results; optionally saves supporting charts."""
    results = {
        "monthly_revenue_trend": monthly_revenue_trend(data["orders"], data["order_items"]),
        "category_performance": category_performance(data["order_items"], data["products"]),
        "product_performance": product_performance(data["products"], data["order_items"]),
        "customer_distribution": customer_distribution(data["customers"]),
        "repeat_customer_rate_pct": None,  # filled below, needs customer_features
        "transaction_health_summary": transaction_health_summary(data["orders"], data["order_items"], data["payments"]),
        "risk_score_distribution": risk_score_distribution(data["risk_management"]),
        "high_risk_transactions": high_risk_transactions(data["orders"], data["order_items"], data["payments"], data["risk_management"]),
        "duplicate_candidates": duplicate_candidates(data["orders"], data["order_items"], data["payments"]),
        "failed_payment_patterns": failed_payment_patterns(data["orders"], data["payments"]),
    }

    if generate_charts:
        visualization.plot_monthly_revenue_trend(results["monthly_revenue_trend"])
        visualization.plot_product_revenue_ranking(results["product_performance"])

    return results


if __name__ == "__main__":
    import data_loader

    data = data_loader.load_all()
    results = run_full_eda(data, generate_charts=True)

    print("=== Monthly revenue trend ===")
    print(results["monthly_revenue_trend"].to_string(index=False))
    print("\n=== Category performance ===")
    print(results["category_performance"].to_string(index=False))
    print("\n=== Transaction health summary ===")
    print(results["transaction_health_summary"])
    print("\n=== High-risk transactions ===")
    print(results["high_risk_transactions"][["order_id", "customer_id", "fraud_risk_score", "transaction_risk_flag"]].to_string(index=False))
