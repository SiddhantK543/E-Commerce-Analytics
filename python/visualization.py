"""
visualization.py

A small set of consistent, professional-looking charts supporting
specific business questions -- not an exhaustive gallery. Per the
Phase 5 spec: "Do not spend excessive effort making Python charts
visually elaborate. The Power BI dashboard will be the main
visualization layer." Every function here saves a PNG to
config.FIGURES_DIR (git-ignored) and returns the path.

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import matplotlib
matplotlib.use("Agg")  # headless-safe backend, no display required
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd

from config import FIGURES_DIR, ensure_output_dirs

# One consistent, professional style applied everywhere in this module.
_PALETTE = ["#2C6E91", "#63A375", "#D98E04", "#B5495B", "#6C5B7B", "#8C8C8C"]


def _apply_style() -> None:
    plt.rcParams.update({
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "axes.edgecolor": "#333333",
        "axes.grid": True,
        "grid.color": "#E5E5E5",
        "grid.linewidth": 0.6,
        "font.size": 10,
        "axes.titlesize": 12,
        "axes.titleweight": "bold",
        "axes.spines.top": False,
        "axes.spines.right": False,
    })


def _save(fig: plt.Figure, name: str) -> Path:
    ensure_output_dirs()
    path = FIGURES_DIR / f"{name}.png"
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path


def plot_monthly_revenue_trend(monthly_revenue_df: pd.DataFrame, month_col: str = "year_month", value_col: str = "revenue") -> Path:
    """Line chart: revenue by calendar month."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(monthly_revenue_df[month_col], monthly_revenue_df[value_col], marker="o", color=_PALETTE[0], linewidth=2)
    ax.set_title("Monthly Revenue Trend")
    ax.set_ylabel("Revenue (USD)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    plt.xticks(rotation=45, ha="right")
    return _save(fig, "monthly_revenue_trend")


def plot_payment_success_failure_trend(monthly_payment_df: pd.DataFrame, month_col: str = "year_month") -> Path:
    """Line chart: payment success rate and failure rate over time."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(monthly_payment_df[month_col], monthly_payment_df["success_rate_pct"], marker="o", color=_PALETTE[1], label="Success rate")
    ax.plot(monthly_payment_df[month_col], monthly_payment_df["failure_rate_pct"], marker="o", color=_PALETTE[3], label="Failure rate")
    ax.set_title("Payment Success / Failure Rate Trend")
    ax.set_ylabel("Rate (%)")
    ax.legend(frameon=False)
    plt.xticks(rotation=45, ha="right")
    return _save(fig, "payment_success_failure_trend")


def plot_customer_segment_distribution(segment_summary_df: pd.DataFrame, segment_col: str = "customer_segment") -> Path:
    """Bar chart: customer count by segment."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.bar(segment_summary_df[segment_col], segment_summary_df["customer_count"], color=_PALETTE[:len(segment_summary_df)])
    ax.set_title("Customer Segment Distribution")
    ax.set_ylabel("Customer count")
    plt.xticks(rotation=20, ha="right")
    return _save(fig, "customer_segment_distribution")


def plot_rfm_segment_revenue(rfm_segment_summary_df: pd.DataFrame) -> Path:
    """Bar chart: total revenue by RFM segment."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(7, 4))
    ordered = rfm_segment_summary_df.sort_values("total_revenue", ascending=False)
    ax.bar(ordered["rfm_segment"], ordered["total_revenue"], color=_PALETTE[0])
    ax.set_title("Revenue by RFM Segment")
    ax.set_ylabel("Revenue (USD)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    plt.xticks(rotation=20, ha="right")
    return _save(fig, "rfm_segment_revenue")


def plot_churn_by_segment(churn_by_segment_df: pd.DataFrame, segment_col: str = "rfm_segment") -> Path:
    """Bar chart: churn rate (%) by segment."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(churn_by_segment_df[segment_col], churn_by_segment_df["churn_rate_pct"], color=_PALETTE[3])
    ax.set_title("Churn Rate by Segment")
    ax.set_ylabel("Churn rate (%)")
    ax.set_ylim(0, 100)
    plt.xticks(rotation=20, ha="right")
    return _save(fig, "churn_by_segment")


def plot_product_revenue_ranking(product_features_df: pd.DataFrame, top_n: int = 10) -> Path:
    """Horizontal bar chart: top N products by revenue."""
    _apply_style()
    top = product_features_df.sort_values("product_revenue", ascending=False).head(top_n)
    fig, ax = plt.subplots(figsize=(7, max(3, 0.4 * len(top))))
    ax.barh(top["product_name"], top["product_revenue"], color=_PALETTE[2])
    ax.invert_yaxis()
    ax.set_title(f"Top {top_n} Products by Revenue")
    ax.set_xlabel("Revenue (USD)")
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    return _save(fig, "product_revenue_ranking")


def plot_transaction_risk_distribution(risk_flags_df: pd.DataFrame) -> Path:
    """Bar chart: order count by transaction_risk_flag (Normal/Review/High Risk)."""
    _apply_style()
    order = ["Normal", "Review", "High Risk"]
    counts = risk_flags_df["transaction_risk_flag"].value_counts().reindex(order).fillna(0)
    fig, ax = plt.subplots(figsize=(6, 4))
    colors = [_PALETTE[1], _PALETTE[2], _PALETTE[3]]
    ax.bar(counts.index, counts.values, color=colors)
    ax.set_title("Transaction Risk Distribution")
    ax.set_ylabel("Order count")
    return _save(fig, "transaction_risk_distribution")


def plot_cancellation_return_trend(monthly_cancel_return_df: pd.DataFrame, month_col: str = "year_month") -> Path:
    """Line chart: cancellation rate and return rate over time."""
    _apply_style()
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(monthly_cancel_return_df[month_col], monthly_cancel_return_df["cancellation_rate_pct"], marker="o", color=_PALETTE[3], label="Cancellation rate")
    ax.plot(monthly_cancel_return_df[month_col], monthly_cancel_return_df["return_rate_pct"], marker="o", color=_PALETTE[4], label="Return rate")
    ax.set_title("Cancellation / Return Rate Trend")
    ax.set_ylabel("Rate (%)")
    ax.legend(frameon=False)
    plt.xticks(rotation=45, ha="right")
    return _save(fig, "cancellation_return_trend")
