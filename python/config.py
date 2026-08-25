"""
config.py

Central configuration for the Python analytics layer: file paths,
environment-driven overrides, and the business constants/thresholds
that must stay consistent with the SQL layer (schema/, sql/,
views/bi_ready/, docs/business_definitions.md).

No machine-specific paths are hardcoded here. Everything is resolved
relative to the repository root, with environment-variable overrides
for anything that might legitimately differ between environments
(e.g. a real data drop living outside the repo).
"""

from __future__ import annotations

import os
from pathlib import Path

# ----------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------

# Repository root = two levels up from this file (python/config.py -> repo root)
REPO_ROOT = Path(__file__).resolve().parent.parent

# Where to read entity CSVs from. Defaults to the synthetic sample
# fixture (data/sample/) documented in data/sample/README.md.
# Point ECOMMERCE_DATA_DIR at the real dataset export once available --
# no code changes should be required, only this environment variable
# (or the equivalent argument to data_loader functions).
DATA_DIR = Path(os.environ.get("ECOMMERCE_DATA_DIR", REPO_ROOT / "data" / "sample"))

# Where BI-ready exports are written. Git-ignored (see .gitignore),
# same convention as data/raw/.
EXPORT_DIR = Path(os.environ.get("ECOMMERCE_EXPORT_DIR", REPO_ROOT / "data" / "exports"))

# Where generated charts (visualization.py) are written. Git-ignored.
FIGURES_DIR = Path(os.environ.get("ECOMMERCE_FIGURES_DIR", REPO_ROOT / "data" / "figures"))

# Optional: a live PostgreSQL connection string, for callers that prefer
# to read from the database (e.g. views/bi_ready/) rather than CSV.
# Not required -- data_loader.py's primary path is CSV, per the Phase 5
# spec ("It should support the actual CSV/data files once they are
# available").
DATABASE_URL = os.environ.get("ECOMMERCE_DATABASE_URL")  # e.g. postgresql://user:pass@host/db


# ----------------------------------------------------------------------
# Business constants
#
# These MUST stay consistent with the SQL layer. Each constant below
# references the exact SQL file/view it mirrors -- if the SQL definition
# ever changes, this file needs to change with it (and vice versa).
# See docs/business_definitions.md for the authoritative prose
# definitions.
# ----------------------------------------------------------------------

# Churn: a customer is "churned" if their most recent order is more
# than this many months before the latest order date in the dataset.
# Mirrors: views/bi_ready/customer_churn.sql
CHURN_INACTIVITY_MONTHS = 6

# RFM: number of quantile buckets for Recency/Frequency/Monetary
# scoring (1 = worst, RFM_QUANTILES = best). Mirrors the NTILE(5) used
# in views/bi_ready/customer_rfm.sql.
RFM_QUANTILES = 5

# RFM segment rules, evaluated in order (first match wins), reproduced
# here in a data-driven form so rfm_analysis.py can apply the EXACT
# same logic as views/bi_ready/customer_rfm.sql rather than restating
# it ad hoc. Each rule is (name, function(recency, frequency, monetary) -> bool).
# Documented rule set (from customer_rfm.sql, Phase 4):
#   Champions            : R>=4 AND F>=4 AND M>=4
#   Loyal Customers       : R>=3 AND F>=3
#   Potential Loyalists   : R>=4 AND F<=2
#   At Risk               : R<=2 AND (F>=3 OR M>=3)
#   Lost Customers        : R<=2 AND F<=2 AND M<=2
#   Needs Attention       : catch-all
RFM_SEGMENT_RULES = [
    ("Champions", lambda r, f, m: r >= 4 and f >= 4 and m >= 4),
    ("Loyal Customers", lambda r, f, m: r >= 3 and f >= 3),
    ("Potential Loyalists", lambda r, f, m: r >= 4 and f <= 2),
    ("At Risk", lambda r, f, m: r <= 2 and (f >= 3 or m >= 3)),
    ("Lost Customers", lambda r, f, m: r <= 2 and f <= 2 and m <= 2),
]
RFM_SEGMENT_DEFAULT = "Needs Attention"

# Risk/anomaly thresholds. Mirrors:
# views/bi_ready/transaction_risk_flags.sql (Phase 4)
FRAUD_SCORE_HIGH_RISK_THRESHOLD = 80        # fraud_risk_score > this => High Risk on its own
HIGH_VALUE_ZSCORE_THRESHOLD = 2             # order_value > mean + N*stddev => "unusually high value"
REPEATED_FAILED_PAYMENT_THRESHOLD = 2       # >= this many failed payments for a customer
RISK_SIGNALS_FOR_HIGH_RISK = 2              # >= this many non-fraud-score signals => High Risk
RISK_SIGNALS_FOR_REVIEW = 1                 # exactly this many signals => Review

# Confirmed categorical value sets (per docs/business_definitions.md).
# Anything outside these sets is a data-quality signal, not silently
# accepted -- see data_quality.py.
CONFIRMED_ORDER_STATUSES = {"Delivered", "Returned", "Cancelled"}
CONFIRMED_PAYMENT_STATUSES = {"Success", "Failed", "Pending"}  # Pending handled defensively, not yet observed
CONFIRMED_YES_NO_VALUES = {"Yes", "No"}

# Expected rating scale (products.product_rating_avg, reviews.rating)
RATING_MIN = 1
RATING_MAX = 5

# Plausible age bounds (customers.age) -- matches sql/data_quality/04
AGE_MIN = 13
AGE_MAX = 100

# Plausible profit-margin bounds (order_items.profit_margin_percent) --
# matches sql/data_quality/09
MARGIN_PCT_MIN = -100
MARGIN_PCT_MAX = 100


def ensure_output_dirs() -> None:
    """Create EXPORT_DIR and FIGURES_DIR if they don't exist yet."""
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
