"""
data_cleaning.py

Reusable cleaning transformations and feature engineering, applied
AFTER data_loader.py has loaded raw entities and (optionally)
data_quality.py has flagged issues. This module does not delete flagged
rows -- callers decide what to do with dq_* flag columns; cleaning here
means type coercion, date construction, and derived-field computation,
not row removal.

STATUS: implemented in Phase 5 (was a NotImplementedError stub in
Phase 2 scaffolding).

Every derived field is documented with the exact formula and, where
relevant, the SQL view it must stay consistent with.
"""

from __future__ import annotations

from typing import Dict, Optional

import numpy as np
import pandas as pd


# ----------------------------------------------------------------------
# Date parsing
# ----------------------------------------------------------------------

def build_order_date(orders_df: pd.DataFrame) -> pd.DataFrame:
    """
    Constructs a proper `order_date` column from the separate
    order_year/order_month/order_day integer columns -- the pandas
    equivalent of `make_date(order_year, order_month, order_day)` used
    throughout the SQL layer (e.g. views/bi_ready/fact_orders.sql).

    Rows with an invalid date combination get `order_date = NaT` rather
    than raising, so the caller can decide whether to investigate them
    (see data_quality.check_invalid_dates for the flagging version of
    this same check).
    """
    out = orders_df.copy()
    out["order_date"] = pd.to_datetime(
        dict(year=out["order_year"], month=out["order_month"], day=out["order_day"]),
        errors="coerce",
    )
    return out


# ----------------------------------------------------------------------
# Boolean normalization
# ----------------------------------------------------------------------

def normalize_yes_no(df: pd.DataFrame, column: str, new_column: Optional[str] = None) -> pd.DataFrame:
    """
    Casts a 'Yes'/'No' text column to a proper boolean, WITHOUT
    silently coercing unexpected values -- any value other than 'Yes'
    or 'No' becomes NaN (missing), not False, so it isn't silently lost
    as a negative. Run data_quality.check_invalid_categorical_values
    first to see whether unexpected values exist before relying on
    this.
    """
    out = df.copy()
    target = new_column or column
    mapping = {"Yes": True, "No": False}
    out[target] = out[column].map(mapping)
    return out


# ----------------------------------------------------------------------
# Order-level aggregation (GRAIN-SAFETY HELPER)
# ----------------------------------------------------------------------

def aggregate_order_items_to_order_level(order_items_df: pd.DataFrame) -> pd.DataFrame:
    """
    Aggregates order_items DOWN to one row per order_id, computing
    order_value / order_profit / line_item_count.

    This is the pandas equivalent of the `order_financials` CTE in
    views/bi_ready/vw_transaction_health.sql, and exists for the exact
    same reason: order_items is one-to-many with orders, so any join of
    orders directly to order_items followed by COUNT(order_id) or
    SUM(total_price_usd) without this aggregation step first would
    inflate order counts / double-count revenue for multi-line orders.
    ALWAYS call this before merging order-level data with order_items.
    """
    agg = order_items_df.groupby("order_id").agg(
        order_value=("total_price_usd", "sum"),
        order_profit=("profit_usd", "sum"),
        line_item_count=("product_id", "count"),
    ).reset_index()
    return agg


# ----------------------------------------------------------------------
# Customer-level aggregation
# ----------------------------------------------------------------------

def aggregate_customer_features(
    customers_df: pd.DataFrame, orders_df: pd.DataFrame, order_items_df: pd.DataFrame,
    reference_date: Optional[pd.Timestamp] = None,
) -> pd.DataFrame:
    """
    Builds one row per customer with the derived fields requested in
    the Phase 5 spec:
      - customer_order_count : distinct orders placed
      - customer_revenue     : total order_value across all their orders
      - average_order_value  : customer_revenue / customer_order_count
      - days_since_last_order: days between reference_date and their
                                most recent order (reference_date
                                defaults to the max order date in the
                                whole dataset, consistent with
                                views/bi_ready/customer_churn.sql's
                                reference_date CTE)
      - purchase_frequency   : customer_order_count / customer tenure
                                in months (orders per month since their
                                FIRST order) -- tenure is floored at 1
                                month to avoid a divide-by-zero for
                                customers whose first and reference
                                month are the same

    Only derives fields that are logically supported by the existing
    schema -- no invented columns.
    """
    orders = build_order_date(orders_df)
    order_value = aggregate_order_items_to_order_level(order_items_df)

    order_with_value = orders.merge(order_value, on="order_id", how="left")
    order_with_value["order_value"] = order_with_value["order_value"].fillna(0)

    if reference_date is None:
        reference_date = order_with_value["order_date"].max()

    grouped = order_with_value.groupby("customer_id").agg(
        customer_order_count=("order_id", "nunique"),
        customer_revenue=("order_value", "sum"),
        first_order_date=("order_date", "min"),
        last_order_date=("order_date", "max"),
    ).reset_index()

    grouped["average_order_value"] = (
        grouped["customer_revenue"] / grouped["customer_order_count"]
    ).round(2)

    grouped["days_since_last_order"] = (reference_date - grouped["last_order_date"]).dt.days

    tenure_months = (
        (reference_date.year - grouped["first_order_date"].dt.year) * 12
        + (reference_date.month - grouped["first_order_date"].dt.month)
    ).clip(lower=1)  # at least 1 month, to avoid divide-by-zero for same-month customers
    grouped["purchase_frequency"] = (grouped["customer_order_count"] / tenure_months).round(3)

    result = customers_df.merge(grouped, on="customer_id", how="left")
    return result


# ----------------------------------------------------------------------
# Product-level aggregation
# ----------------------------------------------------------------------

def aggregate_product_features(products_df: pd.DataFrame, order_items_df: pd.DataFrame) -> pd.DataFrame:
    """
    Builds one row per product with units sold, revenue, and profit --
    the product-level counterpart to aggregate_customer_features.
    """
    grouped = order_items_df.groupby("product_id").agg(
        units_sold=("quantity", "sum"),
        product_revenue=("total_price_usd", "sum"),
        product_profit=("profit_usd", "sum"),
        line_items_sold=("order_id", "count"),
    ).reset_index()
    grouped["product_revenue"] = grouped["product_revenue"].round(2)
    grouped["product_profit"] = grouped["product_profit"].round(2)

    result = products_df.merge(grouped, on="product_id", how="left")
    for col in ["units_sold", "product_revenue", "product_profit", "line_items_sold"]:
        result[col] = result[col].fillna(0)
    return result


def clean_all(data: Dict[str, pd.DataFrame]) -> Dict[str, pd.DataFrame]:
    """
    Convenience entry point: applies the standard set of cleaning
    transformations to a dict of raw DataFrames (as returned by
    data_loader.load_all()) and returns an expanded dict that also
    includes the derived customer/product feature tables and a proper
    order_date column on orders.

    Does not touch payments/shipping/reviews/etc. beyond passing them
    through -- those are cleaned/joined as needed by the specific
    analysis module that uses them (e.g. transaction_analysis.py).
    """
    cleaned = dict(data)  # shallow copy, don't mutate caller's dict

    cleaned["orders"] = build_order_date(data["orders"])
    cleaned["marketing"] = normalize_yes_no(data["marketing"], "coupon_used", "coupon_used_bool")
    cleaned["user_behavior"] = normalize_yes_no(
        data["user_behavior"], "abandoned_cart_before", "abandoned_cart_before_bool"
    )

    cleaned["customer_features"] = aggregate_customer_features(
        data["customers"], data["orders"], data["order_items"]
    )
    cleaned["product_features"] = aggregate_product_features(data["products"], data["order_items"])
    cleaned["order_value"] = aggregate_order_items_to_order_level(data["order_items"])

    return cleaned


if __name__ == "__main__":
    import data_loader

    raw = data_loader.load_all()
    cleaned = clean_all(raw)
    print("Customer features:")
    print(cleaned["customer_features"][[
        "customer_id", "customer_order_count", "customer_revenue",
        "average_order_value", "days_since_last_order", "purchase_frequency",
    ]])
