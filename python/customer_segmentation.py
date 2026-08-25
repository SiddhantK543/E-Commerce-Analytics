"""
customer_segmentation.py

Analyzes customer segments -- both the source-provided
`customer_segment` (Regular/Premium/VIP) and the independently-derived
`rfm_segment` (Champions/Loyal Customers/Potential Loyalists/At
Risk/Lost Customers/Needs Attention) -- in terms of size, revenue
contribution, average order value, and purchase frequency.

Deliberately NOT machine-learning based (no k-means/clustering): the
project prioritizes explainability, and RFM + the source segment field
already provide clear, business-explainable groupings. See Phase 5
instructions: "Do not use machine learning unless it provides a
genuine benefit. We are prioritizing explainability."

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

import pandas as pd

from rfm_analysis import compute_rfm


def summarize_segments(rfm_df: pd.DataFrame, segment_col: str) -> pd.DataFrame:
    """
    Given an RFM-scored DataFrame (output of rfm_analysis.compute_rfm)
    and a column to group by (either 'customer_segment' or
    'rfm_segment'), returns one row per segment with:
      - segment size (customer count) and % of total customers
      - total revenue and % of total revenue
      - average order value proxy: monetary / frequency per customer,
        averaged across the segment
      - average purchase frequency (order count) per customer in the
        segment
      - average recency (days since last order)
    """
    total_customers = len(rfm_df)
    total_revenue = rfm_df["monetary"].sum()

    working = rfm_df.copy()
    working["implied_aov"] = (working["monetary"] / working["frequency"]).round(2)

    grouped = working.groupby(segment_col).agg(
        customer_count=("customer_id", "nunique"),
        total_revenue=("monetary", "sum"),
        avg_order_value=("implied_aov", "mean"),
        avg_purchase_frequency=("frequency", "mean"),
        avg_recency_days=("recency_days", "mean"),
    ).reset_index()

    grouped["pct_of_customers"] = (100 * grouped["customer_count"] / total_customers).round(2)
    grouped["pct_of_revenue"] = (100 * grouped["total_revenue"] / total_revenue).round(2) if total_revenue else 0
    grouped["total_revenue"] = grouped["total_revenue"].round(2)
    grouped["avg_order_value"] = grouped["avg_order_value"].round(2)
    grouped["avg_purchase_frequency"] = grouped["avg_purchase_frequency"].round(2)
    grouped["avg_recency_days"] = grouped["avg_recency_days"].round(1)

    return grouped.sort_values("total_revenue", ascending=False).reset_index(drop=True)


def summarize_by_source_segment(rfm_df: pd.DataFrame) -> pd.DataFrame:
    """Segment summary using the source-provided `customer_segment` (Regular/Premium/VIP)."""
    return summarize_segments(rfm_df, "customer_segment")


def summarize_by_rfm_segment(rfm_df: pd.DataFrame) -> pd.DataFrame:
    """Segment summary using the independently-derived `rfm_segment`."""
    return summarize_segments(rfm_df, "rfm_segment")


def cross_tab_source_vs_rfm(rfm_df: pd.DataFrame) -> pd.DataFrame:
    """
    Cross-tabulates the source-provided customer_segment against the
    derived rfm_segment -- useful for spotting mismatches, e.g. a
    source-labeled 'VIP' customer who is actually RFM-'At Risk'. This
    is exactly the kind of business question the two independent
    segmentation schemes are meant to surface together.
    """
    return pd.crosstab(rfm_df["customer_segment"], rfm_df["rfm_segment"], margins=True, margins_name="Total")


if __name__ == "__main__":
    import data_loader

    data = data_loader.load_all()
    rfm = compute_rfm(data["customers"], data["orders"], data["order_items"])

    print("=== By source customer_segment ===")
    print(summarize_by_source_segment(rfm).to_string(index=False))
    print("\n=== By derived rfm_segment ===")
    print(summarize_by_rfm_segment(rfm).to_string(index=False))
    print("\n=== Cross-tab: source segment vs RFM segment ===")
    print(cross_tab_source_vs_rfm(rfm))
