"""
data_quality.py

An analytical/data-science validation layer that complements (does not
replace) the authoritative SQL data-quality layer in sql/data_quality/.

Philosophy, unchanged from the SQL layer: **flag, don't silently
delete.** Every check below returns a structured report and, where
useful, adds a boolean flag column to the relevant DataFrame -- no
function in this module drops rows.

Relationship to SQL:
  - sql/data_quality/*.sql is the authoritative DATABASE validation
    layer (runs against staging tables before data is trusted).
  - This module re-implements the same checks in pandas so they can run
    against a CSV export directly (no database required), and to
    cross-validate that the two layers agree on a shared fixture.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

import numpy as np
import pandas as pd

from config import (
    AGE_MIN, AGE_MAX, CONFIRMED_ORDER_STATUSES, CONFIRMED_PAYMENT_STATUSES,
    CONFIRMED_YES_NO_VALUES, MARGIN_PCT_MIN, MARGIN_PCT_MAX, RATING_MIN, RATING_MAX,
)


@dataclass
class DataQualityReport:
    """A structured, printable summary of every check run."""
    checks: List[Dict] = field(default_factory=list)

    def add(self, check_name: str, table: str, issue_count: int, detail: str = "") -> None:
        self.checks.append({
            "check": check_name,
            "table": table,
            "issue_count": int(issue_count),
            "detail": detail,
        })

    def to_frame(self) -> pd.DataFrame:
        return pd.DataFrame(self.checks)

    def summary(self) -> str:
        df = self.to_frame()
        if df.empty:
            return "No checks were run."
        total_issues = df["issue_count"].sum()
        lines = [f"Data Quality Report -- {len(df)} checks run, {total_issues} total flagged rows/groups:"]
        for _, row in df.iterrows():
            flag = "⚠️ " if row["issue_count"] > 0 else "✅ "
            lines.append(f"  {flag}[{row['table']}] {row['check']}: {row['issue_count']} issue(s) {row['detail']}")
        return "\n".join(lines)


def check_missing_values(df: pd.DataFrame, table: str, required_cols: List[str], report: DataQualityReport) -> pd.DataFrame:
    """Flags rows with a NULL in any of `required_cols`. Adds `dq_missing_required_field`."""
    out = df.copy()
    missing_mask = out[required_cols].isnull().any(axis=1)
    out["dq_missing_required_field"] = missing_mask
    report.add("missing_required_values", table, int(missing_mask.sum()), f"columns checked: {required_cols}")
    return out


def check_duplicate_records(df: pd.DataFrame, table: str, key_cols: List[str], report: DataQualityReport) -> pd.DataFrame:
    """Flags rows that share a key with at least one other row. Adds `dq_duplicate_key`."""
    out = df.copy()
    dup_mask = out.duplicated(subset=key_cols, keep=False)
    out["dq_duplicate_key"] = dup_mask
    report.add("duplicate_records", table, int(dup_mask.sum()), f"key columns: {key_cols}")
    return out


def check_orphan_relationship(
    child_df: pd.DataFrame, parent_df: pd.DataFrame, key_col: str,
    child_table: str, parent_table: str, report: DataQualityReport,
) -> pd.DataFrame:
    """
    Flags child rows whose `key_col` value doesn't exist in the parent
    table. Mirrors the LEFT JOIN ... WHERE parent.key IS NULL pattern
    used throughout sql/data_quality/02 and 08.
    """
    out = child_df.copy()
    valid_keys = set(parent_df[key_col].dropna())
    orphan_mask = ~out[key_col].isin(valid_keys)
    out["dq_orphan_reference"] = orphan_mask
    report.add(
        "orphan_relationship", child_table, int(orphan_mask.sum()),
        f"{child_table}.{key_col} -> {parent_table}.{key_col}"
    )
    return out


def check_invalid_dates(orders_df: pd.DataFrame, report: DataQualityReport) -> pd.DataFrame:
    """
    Flags orders whose (order_year, order_month, order_day) cannot form
    a valid calendar date. Mirrors
    sql/data_quality/05_missing_values_and_invalid_dates.sql.
    """
    out = orders_df.copy()

    def _is_valid(row) -> bool:
        try:
            pd.Timestamp(year=int(row["order_year"]), month=int(row["order_month"]), day=int(row["order_day"]))
            return True
        except (ValueError, TypeError):
            return False

    valid_mask = out.apply(_is_valid, axis=1)
    out["dq_invalid_date"] = ~valid_mask
    report.add("invalid_dates", "orders", int((~valid_mask).sum()), "order_year/order_month/order_day combination")
    return out


def check_invalid_numeric_values(order_items_df: pd.DataFrame, report: DataQualityReport) -> pd.DataFrame:
    """
    Flags non-positive/NULL quantity or unit_price_usd, and negative
    discount/tax/cost. Mirrors
    sql/data_quality/04_invalid_numeric_values.sql.
    """
    out = order_items_df.copy()
    out["dq_invalid_quantity"] = out["quantity"].isnull() | (out["quantity"] <= 0)
    out["dq_invalid_unit_price"] = out["unit_price_usd"].isnull() | (out["unit_price_usd"] <= 0)
    out["dq_negative_discount"] = out["discount_amount_usd"] < 0
    out["dq_negative_tax"] = out["tax_usd"] < 0
    out["dq_negative_cost"] = out["cost_usd"] < 0

    report.add("invalid_quantity", "order_items", int(out["dq_invalid_quantity"].sum()))
    report.add("invalid_unit_price", "order_items", int(out["dq_invalid_unit_price"].sum()))
    report.add("negative_discount", "order_items", int(out["dq_negative_discount"].sum()))
    report.add("negative_tax", "order_items", int(out["dq_negative_tax"].sum()))
    report.add("negative_cost", "order_items", int(out["dq_negative_cost"].sum()))
    return out


def check_invalid_ratings(df: pd.DataFrame, table: str, rating_col: str, report: DataQualityReport) -> pd.DataFrame:
    """Flags ratings outside [RATING_MIN, RATING_MAX]. Mirrors sql/data_quality/03."""
    out = df.copy()
    invalid_mask = (out[rating_col] < RATING_MIN) | (out[rating_col] > RATING_MAX)
    out["dq_invalid_rating"] = invalid_mask
    report.add("invalid_rating", table, int(invalid_mask.sum()), f"expected [{RATING_MIN}, {RATING_MAX}]")
    return out


def check_invalid_categorical_values(
    df: pd.DataFrame, table: str, col: str, confirmed_values: set, report: DataQualityReport,
) -> pd.DataFrame:
    """
    Flags values in `col` that are not in `confirmed_values`. Mirrors
    sql/data_quality/03_invalid_categorical_values.sql -- surfaces
    unexpected values rather than assuming a fixed enum, since the
    schema has no CHECK constraint (see docs/business_definitions.md).
    """
    out = df.copy()
    unexpected_mask = ~out[col].isin(confirmed_values) & out[col].notna()
    out[f"dq_unexpected_{col}"] = unexpected_mask
    if unexpected_mask.any():
        unexpected_values = sorted(out.loc[unexpected_mask, col].unique().tolist())
    else:
        unexpected_values = []
    report.add(
        f"unexpected_{col}", table, int(unexpected_mask.sum()),
        f"confirmed set: {sorted(confirmed_values)}; unexpected values seen: {unexpected_values}"
    )
    return out


def check_invalid_age(customers_df: pd.DataFrame, report: DataQualityReport) -> pd.DataFrame:
    """Flags implausible ages. Mirrors sql/data_quality/04_invalid_numeric_values.sql (4h)."""
    out = customers_df.copy()
    invalid_mask = out["age"].notna() & ((out["age"] < AGE_MIN) | (out["age"] > AGE_MAX))
    out["dq_invalid_age"] = invalid_mask
    report.add("invalid_age", "customers", int(invalid_mask.sum()), f"expected [{AGE_MIN}, {AGE_MAX}]")
    return out


def check_profit_margin_bounds(order_items_df: pd.DataFrame, report: DataQualityReport) -> pd.DataFrame:
    """Flags margin percent outside a plausible range. Mirrors sql/data_quality/09 (9d)."""
    out = order_items_df.copy()
    invalid_mask = (out["profit_margin_percent"] < MARGIN_PCT_MIN) | (out["profit_margin_percent"] > MARGIN_PCT_MAX)
    out["dq_invalid_margin_pct"] = invalid_mask
    report.add("invalid_margin_pct", "order_items", int(invalid_mask.sum()), f"expected [{MARGIN_PCT_MIN}, {MARGIN_PCT_MAX}]")
    return out


def check_profit_reconciliation(order_items_df: pd.DataFrame, report: DataQualityReport, tolerance: float = 1.00) -> pd.DataFrame:
    """
    Flags rows where profit_usd doesn't reconcile with the assumed
    formula total_price_usd - cost_usd, beyond a small rounding
    tolerance. Mirrors sql/data_quality/09_invalid_profit_and_margin_values.sql (9a).
    Assumption, not confirmed against real data -- see
    docs/data_dictionary.md.
    """
    out = order_items_df.copy()
    expected_profit = out["total_price_usd"] - out["cost_usd"]
    variance = (out["profit_usd"] - expected_profit).abs()
    mismatch_mask = variance > tolerance
    out["dq_profit_mismatch"] = mismatch_mask
    report.add(
        "profit_reconciliation", "order_items", int(mismatch_mask.sum()),
        f"assumed formula: total_price_usd - cost_usd, tolerance ±{tolerance}"
    )
    return out


def run_full_data_quality_suite(data: Dict[str, pd.DataFrame]) -> Dict[str, object]:
    """
    Runs the full pandas data-quality suite against a dict of DataFrames
    as returned by data_loader.load_all(), and returns both the flagged
    DataFrames and a consolidated report.

    Returns
    -------
    dict with keys:
      - "report": DataQualityReport
      - "flagged": dict of {table_name: DataFrame with dq_* flag columns added}
    """
    report = DataQualityReport()
    flagged: Dict[str, pd.DataFrame] = {}

    customers = data["customers"]
    orders = data["orders"]
    order_items = data["order_items"]
    payments = data["payments"]
    shipping = data["shipping"]
    reviews = data["reviews"]
    products = data["products"]
    marketing = data["marketing"]
    user_behavior = data["user_behavior"]

    # Missing values
    customers = check_missing_values(customers, "customers", ["customer_id", "customer_name", "email"], report)
    orders = check_missing_values(orders, "orders", ["order_id", "customer_id", "order_status"], report)

    # Duplicates
    customers = check_duplicate_records(customers, "customers", ["customer_id"], report)
    orders = check_duplicate_records(orders, "orders", ["order_id"], report)
    order_items = check_duplicate_records(order_items, "order_items", ["order_id", "product_id"], report)
    payments = check_duplicate_records(payments, "payments", ["order_id"], report)
    shipping = check_duplicate_records(shipping, "shipping", ["order_id"], report)

    # Orphan relationships
    orders = check_orphan_relationship(orders, customers, "customer_id", "orders", "customers", report)
    order_items = check_orphan_relationship(order_items, orders, "order_id", "order_items", "orders", report)
    order_items = check_orphan_relationship(order_items, products, "product_id", "order_items", "products", report)
    payments = check_orphan_relationship(payments, orders, "order_id", "payments", "orders", report)

    # Invalid dates
    orders = check_invalid_dates(orders, report)

    # Invalid numeric values
    order_items = check_invalid_numeric_values(order_items, report)
    order_items = check_profit_margin_bounds(order_items, report)
    order_items = check_profit_reconciliation(order_items, report)

    # Invalid ratings
    reviews = check_invalid_ratings(reviews, "reviews", "rating", report)
    products = check_invalid_ratings(products, "products", "product_rating_avg", report)

    # Invalid categorical values
    orders = check_invalid_categorical_values(orders, "orders", "order_status", CONFIRMED_ORDER_STATUSES, report)
    payments = check_invalid_categorical_values(payments, "payments", "payment_status", CONFIRMED_PAYMENT_STATUSES, report)
    marketing = check_invalid_categorical_values(marketing, "marketing", "coupon_used", CONFIRMED_YES_NO_VALUES, report)
    user_behavior = check_invalid_categorical_values(
        user_behavior, "user_behavior", "abandoned_cart_before", CONFIRMED_YES_NO_VALUES, report
    )

    # Invalid age
    customers = check_invalid_age(customers, report)

    flagged.update({
        "customers": customers, "orders": orders, "order_items": order_items,
        "payments": payments, "shipping": shipping, "reviews": reviews,
        "products": products, "marketing": marketing, "user_behavior": user_behavior,
    })

    return {"report": report, "flagged": flagged}


if __name__ == "__main__":
    import data_loader

    data = data_loader.load_all()
    result = run_full_data_quality_suite(data)
    print(result["report"].summary())
