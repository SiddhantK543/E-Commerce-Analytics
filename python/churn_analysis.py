"""
churn_analysis.py

Uses the EXACT SAME churn definition established in the SQL layer
(views/bi_ready/customer_churn.sql, Phase 4): a customer is "churned"
if their most recent order is more than CHURN_INACTIVITY_MONTHS (6)
months before the latest order date anywhere in the dataset. This is a
project-defined threshold, not a business-confirmed one -- see
docs/business_definitions.md.

Do NOT introduce a different churn definition here -- every function
in this module is a breakdown/cross-tab of the same single
is_churned flag, not an alternative churn model.

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

from typing import Optional

import pandas as pd

from data_cleaning import build_order_date
from config import CHURN_INACTIVITY_MONTHS


def compute_customer_churn(
    customers_df: pd.DataFrame, orders_df: pd.DataFrame, reference_date: Optional[pd.Timestamp] = None,
) -> pd.DataFrame:
    """
    Computes is_churned per customer, matching
    views/bi_ready/customer_churn.sql exactly:
      - reference_date = max order date across the whole dataset
      - months_since_last_order = days between reference_date and the
        customer's last order date, divided by 30.0 (matches the SQL
        view's `(latest_order_date - last_order_date) / 30.0` -- an
        approximation, not calendar-accurate months, intentionally kept
        identical to the SQL formula rather than "improved" in Python,
        per the "do not introduce a different definition" rule)
      - is_churned = last_order_date < reference_date - 6 months
    """
    orders = build_order_date(orders_df)

    last_order = orders.groupby("customer_id").agg(last_order_date=("order_date", "max")).reset_index()

    if reference_date is None:
        reference_date = orders["order_date"].max()

    last_order["months_since_last_order"] = (
        (reference_date - last_order["last_order_date"]).dt.days / 30.0
    ).round(1)

    churn_cutoff = reference_date - pd.DateOffset(months=CHURN_INACTIVITY_MONTHS)
    last_order["is_churned"] = last_order["last_order_date"] < churn_cutoff

    result = customers_df.merge(last_order, on="customer_id", how="inner")
    result["latest_order_date"] = reference_date
    return result


def overall_churn_rate(churn_df: pd.DataFrame) -> float:
    """Overall % of customers flagged as churned."""
    return round(100 * churn_df["is_churned"].mean(), 2)


def churn_by_rfm_segment(churn_df: pd.DataFrame, rfm_df: pd.DataFrame) -> pd.DataFrame:
    """
    Churn rate broken down by RFM segment (from rfm_analysis.compute_rfm).
    Note: RFM's own `recency_score` is DERIVED FROM the same
    last_order_date this churn flag uses, so a strong correlation
    between "Lost Customers"/"At Risk" RFM segments and is_churned=True
    is expected and mutually reinforcing, not a coincidence to be
    surprised by.
    """
    merged = churn_df.merge(rfm_df[["customer_id", "rfm_segment"]], on="customer_id", how="left")
    grouped = merged.groupby("rfm_segment").agg(
        customer_count=("customer_id", "nunique"),
        churned_count=("is_churned", "sum"),
    ).reset_index()
    grouped["churn_rate_pct"] = (100 * grouped["churned_count"] / grouped["customer_count"]).round(2)
    return grouped.sort_values("churn_rate_pct", ascending=False).reset_index(drop=True)


def churn_by_customer_value(churn_df: pd.DataFrame, rfm_df: pd.DataFrame) -> pd.DataFrame:
    """Churn rate broken down by monetary_score quintile (1=lowest value, 5=highest value)."""
    merged = churn_df.merge(rfm_df[["customer_id", "monetary_score"]], on="customer_id", how="left")
    grouped = merged.groupby("monetary_score").agg(
        customer_count=("customer_id", "nunique"),
        churned_count=("is_churned", "sum"),
    ).reset_index()
    grouped["churn_rate_pct"] = (100 * grouped["churned_count"] / grouped["customer_count"]).round(2)
    return grouped.sort_values("monetary_score", ascending=False).reset_index(drop=True)


def churn_by_geography(churn_df: pd.DataFrame) -> pd.DataFrame:
    """Churn rate broken down by customer country."""
    grouped = churn_df.groupby("country").agg(
        customer_count=("customer_id", "nunique"),
        churned_count=("is_churned", "sum"),
    ).reset_index()
    grouped["churn_rate_pct"] = (100 * grouped["churned_count"] / grouped["customer_count"]).round(2)
    return grouped.sort_values("churn_rate_pct", ascending=False).reset_index(drop=True)


def churn_over_time(orders_df: pd.DataFrame, churn_df: pd.DataFrame) -> pd.DataFrame:
    """
    A simple proxy for "churn over time": counts, per calendar month,
    how many customers' LAST order fell in that month. A large count in
    a month far from the reference date indicates a cohort of customers
    who stopped ordering around that time. This is a lightweight,
    explainable view -- not a survival-analysis model.
    """
    merged = churn_df.copy()
    merged["last_order_month"] = merged["last_order_date"].dt.to_period("M").astype(str)
    grouped = merged.groupby("last_order_month").agg(
        customers_with_last_order_this_month=("customer_id", "nunique"),
        of_which_now_churned=("is_churned", "sum"),
    ).reset_index()
    return grouped.sort_values("last_order_month").reset_index(drop=True)


def churn_among_high_value_customers(churn_df: pd.DataFrame, rfm_df: pd.DataFrame, top_n_monetary_score: int = 5) -> pd.DataFrame:
    """
    Filters to only the highest-value RFM monetary tier
    (monetary_score == top_n_monetary_score, default 5, i.e. top
    quintile) and reports their individual churn status -- these are
    the customers whose loss has the highest revenue impact, and the
    ones a retention campaign should prioritize first.
    """
    merged = churn_df.merge(rfm_df[["customer_id", "monetary_score", "monetary"]], on="customer_id", how="inner")
    high_value = merged[merged["monetary_score"] == top_n_monetary_score].copy()
    return high_value[[
        "customer_id", "customer_name", "country", "monetary",
        "last_order_date", "months_since_last_order", "is_churned",
    ]].sort_values("monetary", ascending=False).reset_index(drop=True)


if __name__ == "__main__":
    import data_loader
    from rfm_analysis import compute_rfm

    data = data_loader.load_all()
    churn = compute_customer_churn(data["customers"], data["orders"])
    rfm = compute_rfm(data["customers"], data["orders"], data["order_items"])

    print(f"Overall churn rate: {overall_churn_rate(churn)}%")
    print("\n=== Churn by RFM segment ===")
    print(churn_by_rfm_segment(churn, rfm).to_string(index=False))
    print("\n=== Churn by customer value (monetary quintile) ===")
    print(churn_by_customer_value(churn, rfm).to_string(index=False))
    print("\n=== Churn by geography ===")
    print(churn_by_geography(churn).to_string(index=False))
    print("\n=== Churn among high-value customers (top monetary quintile) ===")
    print(churn_among_high_value_customers(churn, rfm).to_string(index=False))
