"""
data_loader.py

Reusable CSV data-loading layer for every entity in the schema. Each
loader function:
  - reads the expected CSV from config.DATA_DIR (or an explicit path)
  - validates that the expected columns are present
  - fails with a clear, actionable error message if the file is
    missing or malformed, rather than silently returning partial data

Does NOT assume any file exists -- every function checks first and
raises FileNotFoundError with the expected path if the file isn't
there yet (e.g. before the real dataset has been downloaded per
data/README.md).
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, Iterable, Optional

import pandas as pd

from config import DATA_DIR

# ----------------------------------------------------------------------
# Expected columns per entity, matching schema/create_tables.sql
# column-for-column. Used only to validate the loaded file has what
# downstream modules expect -- not to coerce/rename anything here
# (that belongs in data_cleaning.py).
# ----------------------------------------------------------------------

EXPECTED_COLUMNS: Dict[str, Iterable[str]] = {
    "customers": [
        "customer_id", "customer_name", "email", "gender", "age",
        "country", "city", "customer_segment", "loyalty_score",
        "account_creation_date",
    ],
    "products": [
        "product_id", "product_name", "category", "brand",
        "product_rating_avg", "stock_quantity",
    ],
    "orders": [
        "order_id", "customer_id", "order_year", "order_month",
        "order_day", "order_status", "return_reason",
    ],
    "order_items": [
        "order_id", "product_id", "quantity", "unit_price_usd",
        "discount_percent", "discount_amount_usd", "total_price_usd",
        "cost_usd", "profit_usd", "tax_usd", "profit_margin_percent",
    ],
    "payments": [
        "order_id", "payment_method", "payment_status", "installment",
        "currency",
    ],
    "shipping": [
        "order_id", "shipping_method", "shipping_cost_usd",
        "delivery_days", "warehouse", "shipping_status",
    ],
    "reviews": [
        "order_id", "product_id", "rating", "sentiment",
        "customer_feedback",
    ],
    "marketing": [
        "order_id", "coupon_used", "coupon_code", "campaign_source",
        "traffic_source",
    ],
    "user_behavior": [
        "order_id", "device_type", "session_duration_minutes",
        "pages_visited", "abandoned_cart_before",
    ],
    "risk_management": [
        "order_id", "fraud_risk_score", "order_priority",
        "support_tickets",
    ],
}


def _load_entity(name: str, data_dir: Optional[Path] = None) -> pd.DataFrame:
    """
    Load a single entity's CSV, validating its columns.

    Parameters
    ----------
    name : the entity name, e.g. "customers" (must be a key in
        EXPECTED_COLUMNS)
    data_dir : override for config.DATA_DIR, mainly for testing

    Raises
    ------
    FileNotFoundError
        with a clear message and the expected path, if the CSV isn't
        present. This is expected/normal before the real dataset has
        been obtained -- see data/README.md.
    ValueError
        if the file exists but is missing expected columns.
    """
    if name not in EXPECTED_COLUMNS:
        raise ValueError(f"Unknown entity '{name}'. Known entities: {sorted(EXPECTED_COLUMNS)}")

    base_dir = Path(data_dir) if data_dir is not None else DATA_DIR
    path = base_dir / f"{name}.csv"

    if not path.exists():
        raise FileNotFoundError(
            f"Expected data file not found: {path}\n"
            f"  -> If you haven't loaded the dataset yet, see data/README.md "
            f"for how to obtain it, or point ECOMMERCE_DATA_DIR at a folder "
            f"that contains '{name}.csv'.\n"
            f"  -> For local development/testing, data/sample/ contains a "
            f"small synthetic fixture (see data/sample/README.md)."
        )

    try:
        df = pd.read_csv(path)
    except pd.errors.EmptyDataError as exc:
        raise ValueError(f"'{path}' exists but is empty or unreadable as CSV.") from exc

    expected = set(EXPECTED_COLUMNS[name])
    actual = set(df.columns)
    missing = expected - actual
    if missing:
        raise ValueError(
            f"'{path}' is missing expected column(s): {sorted(missing)}\n"
            f"  -> Expected columns for '{name}': {sorted(expected)}\n"
            f"  -> Actual columns found: {sorted(actual)}\n"
            f"  -> This usually means the file is stale, was exported with "
            f"different column names, or is the wrong file."
        )

    extra = actual - expected
    if extra:
        # Not fatal -- extra columns are common (e.g. an export tool adding
        # an index column) -- but worth surfacing since it may signal the
        # wrong file was pointed to.
        print(f"[data_loader] Note: '{name}.csv' has unexpected extra column(s): {sorted(extra)}")

    return df


def load_customers(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("customers", data_dir)


def load_products(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("products", data_dir)


def load_orders(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("orders", data_dir)


def load_order_items(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("order_items", data_dir)


def load_payments(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("payments", data_dir)


def load_shipping(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("shipping", data_dir)


def load_reviews(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("reviews", data_dir)


def load_marketing(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("marketing", data_dir)


def load_user_behavior(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("user_behavior", data_dir)


def load_risk_management(data_dir: Optional[Path] = None) -> pd.DataFrame:
    return _load_entity("risk_management", data_dir)


def load_all(data_dir: Optional[Path] = None) -> Dict[str, pd.DataFrame]:
    """
    Load every entity into a dict keyed by entity name. Any single
    missing/invalid file will raise immediately with a clear message
    (fail fast, rather than returning a partially-populated dict that
    downstream code might silently misuse).
    """
    return {name: _load_entity(name, data_dir) for name in EXPECTED_COLUMNS}
