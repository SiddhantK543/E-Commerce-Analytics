"""
anomaly_detection.py

A transparent, rule-based + statistical anomaly layer, explicitly NOT a
production fraud-detection model. Terminology used throughout:
"anomaly", "review candidate", "high-risk transaction" -- never "fraud"
or "confirmed fraud", since this project's data has no confirmed-fraud
label (see docs/business_definitions.md, "Risk & anomaly terminology").

This module is designed to REPRODUCE the SQL rule-based risk framework
in views/bi_ready/transaction_risk_flags.sql (Phase 4) signal-for-
signal, so Python and SQL can be cross-validated against each other
(Phase 5, Step 10/14). It is not an independent/conflicting definition
of risk.

Signals implemented (matching the SQL view exactly):
  1. unusually_high_value      : order_value > mean + Z * stddev
  2. repeated_failed_payment   : customer has >= N failed payments
  3. possible_duplicate_flag   : a same customer/product/amount/date/
                                  payment_method match with another order
  4. high_fraud_score          : risk_management.fraud_risk_score > threshold
  5. returned_or_cancelled     : order_status in ('Returned','Cancelled')
  6. same_day_multi_order      : customer placed >1 order on the same day

Combining rule (matching the SQL view exactly):
  - fraud_risk_score alone > threshold => 'High Risk'
  - >= RISK_SIGNALS_FOR_HIGH_RISK non-fraud-score signals => 'High Risk'
  - == RISK_SIGNALS_FOR_REVIEW non-fraud-score signals => 'Review'
  - otherwise => 'Normal'

STATUS: implemented in Phase 5.
"""

from __future__ import annotations

from typing import Optional

import numpy as np
import pandas as pd

from config import (
    FRAUD_SCORE_HIGH_RISK_THRESHOLD, HIGH_VALUE_ZSCORE_THRESHOLD,
    REPEATED_FAILED_PAYMENT_THRESHOLD, RISK_SIGNALS_FOR_HIGH_RISK, RISK_SIGNALS_FOR_REVIEW,
)
from data_cleaning import build_order_date, aggregate_order_items_to_order_level


def flag_unusually_high_value(order_value_df: pd.DataFrame, z_threshold: float = HIGH_VALUE_ZSCORE_THRESHOLD) -> pd.Series:
    """Z-score based outlier flag: order_value > mean + z_threshold * population stddev (matches SQL's stddev_pop)."""
    mean_value = order_value_df["order_value"].mean()
    stddev_value = order_value_df["order_value"].std(ddof=0)  # ddof=0 => population stddev, matches SQL's stddev_pop
    return order_value_df["order_value"] > (mean_value + z_threshold * stddev_value)


def flag_unusually_high_value_iqr(order_value_df: pd.DataFrame, k: float = 1.5) -> pd.Series:
    """
    Alternative IQR-based outlier flag (Q3 + k*IQR), offered alongside
    the z-score method per the Phase 5 spec's suggestion to consider
    both. Not used in the combined risk flag below (which mirrors the
    SQL view's z-score-only approach) -- provided for EDA/comparison
    purposes in exploratory_analysis.py.
    """
    q1 = order_value_df["order_value"].quantile(0.25)
    q3 = order_value_df["order_value"].quantile(0.75)
    iqr = q3 - q1
    return order_value_df["order_value"] > (q3 + k * iqr)


def flag_repeated_failed_payments(orders_df: pd.DataFrame, payments_df: pd.DataFrame, threshold: int = REPEATED_FAILED_PAYMENT_THRESHOLD) -> pd.DataFrame:
    """Per-customer failed-payment counts, and a boolean >= threshold flag, keyed by customer_id."""
    failed = orders_df.merge(payments_df[["order_id", "payment_status"]], on="order_id", how="inner")
    failed = failed[failed["payment_status"] == "Failed"]
    counts = failed.groupby("customer_id").size().reset_index(name="failed_payment_count")
    counts["repeated_failed_payment"] = counts["failed_payment_count"] >= threshold
    return counts


def flag_possible_duplicates(orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame) -> pd.Series:
    """
    Flags order_ids that share {customer_id, product_id, total_price_usd,
    order_date, payment_method} with at least one OTHER order -- a
    "duplicate transaction candidate" per docs/business_definitions.md,
    not a confirmed duplicate (could be a legitimate repeat purchase on
    the same day). Mirrors the `duplicate_orders` CTE in
    views/bi_ready/transaction_risk_flags.sql.
    """
    orders = build_order_date(orders_df)
    merged = (
        order_items_df.merge(orders[["order_id", "customer_id", "order_date"]], on="order_id", how="inner")
        .merge(payments_df[["order_id", "payment_method"]], on="order_id", how="inner")
    )
    key_cols = ["customer_id", "product_id", "total_price_usd", "order_date", "payment_method"]
    dup_mask = merged.duplicated(subset=key_cols, keep=False)
    dup_order_ids = set(merged.loc[dup_mask, "order_id"])
    return orders_df["order_id"].isin(dup_order_ids)


def flag_same_day_multi_order(orders_df: pd.DataFrame) -> pd.Series:
    """Flags orders where the same customer placed more than one order on the same calendar day."""
    orders = build_order_date(orders_df)
    counts = orders.groupby(["customer_id", "order_date"]).size().reset_index(name="orders_that_day")
    multi = counts[counts["orders_that_day"] > 1]
    multi_keys = set(zip(multi["customer_id"], multi["order_date"]))
    return orders.apply(lambda r: (r["customer_id"], r["order_date"]) in multi_keys, axis=1)


def build_transaction_risk_flags(
    orders_df: pd.DataFrame, order_items_df: pd.DataFrame, payments_df: pd.DataFrame,
    risk_management_df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Builds the combined risk-flag table, one row per order, replicating
    views/bi_ready/transaction_risk_flags.sql (Phase 4) signal-for-
    signal and combining-rule-for-combining-rule.
    """
    order_value = aggregate_order_items_to_order_level(order_items_df)[["order_id", "order_value"]]

    result = orders_df[["order_id", "customer_id", "order_status"]].merge(order_value, on="order_id", how="left")
    result["order_value"] = result["order_value"].fillna(0)

    result["unusually_high_value"] = flag_unusually_high_value(result)

    failed_counts = flag_repeated_failed_payments(orders_df, payments_df)
    result = result.merge(failed_counts[["customer_id", "repeated_failed_payment"]], on="customer_id", how="left")
    result["repeated_failed_payment"] = result["repeated_failed_payment"].fillna(False)

    result["possible_duplicate_flag"] = flag_possible_duplicates(orders_df, order_items_df, payments_df).values

    risk = risk_management_df[["order_id", "fraud_risk_score"]]
    result = result.merge(risk, on="order_id", how="left")
    result["high_fraud_score"] = result["fraud_risk_score"] > FRAUD_SCORE_HIGH_RISK_THRESHOLD

    result["returned_or_cancelled"] = result["order_status"].isin(["Returned", "Cancelled"])

    result["same_day_multi_order"] = flag_same_day_multi_order(orders_df).values

    non_fraud_signal_cols = [
        "unusually_high_value", "repeated_failed_payment", "possible_duplicate_flag",
        "returned_or_cancelled", "same_day_multi_order",
    ]
    result["signals_triggered"] = result[non_fraud_signal_cols].sum(axis=1)

    def _combine(row: pd.Series) -> str:
        if row["high_fraud_score"]:
            return "High Risk"
        if row["signals_triggered"] >= RISK_SIGNALS_FOR_HIGH_RISK:
            return "High Risk"
        if row["signals_triggered"] == RISK_SIGNALS_FOR_REVIEW:
            return "Review"
        return "Normal"

    result["transaction_risk_flag"] = result.apply(_combine, axis=1)

    return result[[
        "order_id", "customer_id", "order_value", "fraud_risk_score",
        "unusually_high_value", "repeated_failed_payment", "possible_duplicate_flag",
        "high_fraud_score", "returned_or_cancelled", "same_day_multi_order",
        "signals_triggered", "transaction_risk_flag",
    ]]


def compare_with_sql_risk_flags(python_flags: pd.DataFrame, sql_flags: pd.DataFrame) -> pd.DataFrame:
    """
    Merges the Python-computed flags with the SQL view's output
    (e.g. exported from `select * from transaction_risk_flags`) and
    returns only the rows where transaction_risk_flag disagrees --
    an empty result means full agreement. Used in Phase 5 testing
    (see docs/python_analytics.md) rather than assumed.
    """
    merged = python_flags.merge(
        sql_flags[["order_id", "transaction_risk_flag"]], on="order_id", suffixes=("_python", "_sql")
    )
    disagreements = merged[merged["transaction_risk_flag_python"] != merged["transaction_risk_flag_sql"]]
    return disagreements


if __name__ == "__main__":
    import data_loader

    data = data_loader.load_all()
    flags = build_transaction_risk_flags(data["orders"], data["order_items"], data["payments"], data["risk_management"])
    print(flags.to_string(index=False))
