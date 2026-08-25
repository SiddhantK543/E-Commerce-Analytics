"""
rfm_analysis.py

Independent pandas implementation of RFM (Recency/Frequency/Monetary)
segmentation, designed to be CONSISTENT with (not a replacement for)
views/bi_ready/customer_rfm.sql from Phase 4.

Methodology (must match the SQL view exactly -- see config.py's
RFM_SEGMENT_RULES, which is transcribed directly from the SQL view's
documented rule set):

  Recency  = days since each customer's most recent order, relative to
             the latest order date anywhere in the dataset (a single,
             fixed reference point -- NOT "today", consistent with the
             SQL view and the original project's churn query)
  Frequency = distinct number of orders placed
  Monetary  = total revenue (order-level order_value, summed) generated

Scores are computed by replicating Postgres's NTILE(RFM_QUANTILES)
algorithm EXACTLY (row-position-based bucketing with a deterministic
tiebreaker), not pandas.qcut.

PHASE 5 FINDING (SQL/Python reconciliation): an earlier version of this
function used pandas.qcut, which partitions by VALUE (tied values
always land in the same bucket). Postgres's NTILE instead partitions by
ROW POSITION after ORDER BY (tied values CAN land in different
buckets, split however the row order happens to fall) -- these are
different algorithms, not just a tie-breaking detail, and they produced
different segment assignments for customers with identical frequency
values on the test fixture. Both the SQL view
(views/bi_ready/customer_rfm.sql) and this function were fixed to (a)
use the identical row-position algorithm and (b) use the same
`customer_id`-ascending secondary sort key as a deterministic
tiebreaker, so results are reproducible and now match exactly. See
docs/python_analytics.md, "SQL/Python Consistency", for the full
before/after comparison.

STATUS: implemented in Phase 5 (was a NotImplementedError stub in
Phase 2 scaffolding).
"""

from __future__ import annotations

from typing import Optional

import numpy as np
import pandas as pd

from config import RFM_QUANTILES, RFM_SEGMENT_RULES, RFM_SEGMENT_DEFAULT
from data_cleaning import build_order_date, aggregate_order_items_to_order_level


def _ntile(n_rows: int, buckets: int) -> np.ndarray:
    """
    Replicates Postgres's NTILE(buckets) row-position algorithm exactly:
    divides `n_rows` (already sorted in the desired order) into
    `buckets` groups as evenly as possible. The first
    (n_rows % buckets) groups get one extra row; the rest get
    n_rows // buckets rows. Returns an array of length n_rows with
    values 1..buckets, in the same row order as the input.
    """
    base, remainder = divmod(n_rows, buckets)
    sizes = [base + 1] * remainder + [base] * (buckets - remainder)
    return np.repeat(np.arange(1, buckets + 1), sizes)[:n_rows]


def _quantile_score(df: pd.DataFrame, sort_col: str, ascending: bool, tiebreak_col: str = "customer_id") -> pd.Series:
    """
    Assigns a 1..RFM_QUANTILES score matching
    NTILE(RFM_QUANTILES) OVER (ORDER BY sort_col [ASC|DESC], tiebreak_col)
    in the SQL view exactly (row-position bucketing, not value-based
    binning -- see module docstring for why this distinction matters).

    ascending=True  -> higher raw value = higher score (Frequency, Monetary)
    ascending=False -> lower raw value = higher score (Recency: fewer
                        days since last order = better = higher score)
    """
    ordered = df.sort_values([sort_col, tiebreak_col], ascending=[ascending, True])
    buckets = _ntile(len(ordered), RFM_QUANTILES)
    return pd.Series(buckets, index=ordered.index).reindex(df.index)


def _assign_segment(row: pd.Series) -> str:
    r, f, m = row["recency_score"], row["frequency_score"], row["monetary_score"]
    for name, rule in RFM_SEGMENT_RULES:
        if rule(r, f, m):
            return name
    return RFM_SEGMENT_DEFAULT


def compute_rfm(
    customers_df: pd.DataFrame, orders_df: pd.DataFrame, order_items_df: pd.DataFrame,
    reference_date: Optional[pd.Timestamp] = None,
) -> pd.DataFrame:
    """
    Computes RFM scores and segments, one row per customer.

    Returns a DataFrame with the same column set/semantics as
    views/bi_ready/customer_rfm.sql: customer_id, customer_name,
    customer_segment, last_order_date, recency_days, frequency,
    monetary, recency_score, frequency_score, monetary_score,
    rfm_total_score, rfm_segment.
    """
    orders = build_order_date(orders_df)
    order_value = aggregate_order_items_to_order_level(order_items_df)
    order_with_value = orders.merge(order_value, on="order_id", how="inner")  # inner: mirrors SQL's INNER JOIN order_items

    if reference_date is None:
        reference_date = order_with_value["order_date"].max()

    per_customer = order_with_value.groupby("customer_id").agg(
        last_order_date=("order_date", "max"),
        frequency=("order_id", "nunique"),
        monetary=("order_value", "sum"),
    ).reset_index()
    per_customer["monetary"] = per_customer["monetary"].round(2)
    per_customer["recency_days"] = (reference_date - per_customer["last_order_date"]).dt.days

    per_customer["recency_score"] = _quantile_score(per_customer, "recency_days", ascending=False)
    per_customer["frequency_score"] = _quantile_score(per_customer, "frequency", ascending=True)
    per_customer["monetary_score"] = _quantile_score(per_customer, "monetary", ascending=True)
    per_customer["rfm_total_score"] = (
        per_customer["recency_score"] + per_customer["frequency_score"] + per_customer["monetary_score"]
    )
    per_customer["rfm_segment"] = per_customer.apply(_assign_segment, axis=1)

    result = customers_df[["customer_id", "customer_name", "customer_segment"]].merge(
        per_customer, on="customer_id", how="inner"
    )
    return result[[
        "customer_id", "customer_name", "customer_segment", "last_order_date",
        "recency_days", "frequency", "monetary", "recency_score", "frequency_score",
        "monetary_score", "rfm_total_score", "rfm_segment",
    ]]


if __name__ == "__main__":
    import data_loader

    data = data_loader.load_all()
    rfm = compute_rfm(data["customers"], data["orders"], data["order_items"])
    print(rfm.to_string(index=False))
