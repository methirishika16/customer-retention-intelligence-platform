"""
Every assumption of the Sprint 3 workflow in ONE place.

Change a number here and re-run `python python/run_sprint3.py`. Nothing else needs editing.
Each setting says whether it is a DATA FACT, a BUSINESS RULE or an ASSUMPTION.
"""

from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[2]
CHART_DIR = PROJECT_ROOT / "docs" / "images" / "sprint3"   # charts (committed to Git)
OUTPUT_DIR = PROJECT_ROOT / "outputs"                       # CSV exports (git-ignored)

# --------------------------------------------------------------------------------------
# Prediction target
# --------------------------------------------------------------------------------------
# BUSINESS RULE: "Will the customer make another valid purchase in the next 180 days?"
# Why 180 days: 77% of repeat purchases (excluding same-day split orders) happen within
# 180 days of the previous one, and it matches the "Active" window used in dbt.
HORIZON_DAYS = 180

# DATA FACT: last purchase in the data is 2018-09-03. Scoring "as of" the next day means
# every known order is included in the features.
SCORING_DATE = pd.Timestamp("2018-09-04")

# Time-travel snapshots. For each date we build features from orders BEFORE the date and
# label who purchased in the following HORIZON_DAYS. Leakage rule: every TRAIN label window
# must end before the TEST snapshot date (2017-09-01 + 180 days = 2018-02-28 < 2018-03-01).
TRAIN_SNAPSHOTS = [pd.Timestamp("2017-06-01"), pd.Timestamp("2017-09-01")]
TEST_SNAPSHOT = pd.Timestamp("2018-03-01")            # out-of-time test (2018-03-01 -> 2018-08-28)

# --------------------------------------------------------------------------------------
# Activity status (BUSINESS RULE, same thresholds as dbt vars)
# --------------------------------------------------------------------------------------
ACTIVE_DAYS = 180      # last purchase <= 180 days ago  -> Active
INACTIVE_DAYS = 365    # last purchase  > 365 days ago  -> Inactive   (in between: Cooling)

# --------------------------------------------------------------------------------------
# Tiers (BUSINESS RULES, based on rank so they adapt to the data)
# --------------------------------------------------------------------------------------
# Risk = how UNLIKELY the model thinks a return is, relative to other customers.
RISK_HIGH_BELOW_PCT = 0.40   # bottom 40% of predicted return probability -> High risk
RISK_LOW_ABOVE_PCT = 0.80    # top 20%                                       -> Low risk
NEW_CUSTOMER_DAYS = 90       # first purchase within the last 90 days        -> New Customer
POOR_EXPERIENCE_REVIEW = 2.0 # average review <= 2 stars                     -> service recovery first

# --------------------------------------------------------------------------------------
# Priority score weights (BUSINESS RULE: must add up to 1)
# --------------------------------------------------------------------------------------
PRIORITY_WEIGHTS = {
    "value": 0.45,        # how much the customer has spent (percentile)
    "likelihood": 0.35,   # how likely they are to respond / come back (model percentile)
    "urgency": 0.20,      # how close they are to slipping away (activity status)
}
URGENCY_BY_STATUS = {"Cooling": 1.0, "Active": 0.6, "Inactive": 0.3}

# --------------------------------------------------------------------------------------
# Marketing actions (ASSUMPTIONS: illustrative costs per customer in BRL; replace with real ones)
# --------------------------------------------------------------------------------------
ACTION_COST_BRL = {
    "Service recovery": 20.00,          # apology + voucher after a bad experience
    "Win-back offer": 25.00,            # personal discount for valuable lapsing customers
    "Loyalty reward": 15.00,            # thank-you perk for repeat customers
    "Second-purchase incentive": 10.00, # small coupon to earn the crucial 2nd order
    "Product cross-sell": 2.00,         # personalised recommendation email + retargeting
    "Low-cost email campaign": 0.10,    # generic newsletter / reminder
}
BUDGET_SCENARIOS_BRL = [10_000, 25_000, 50_000, 100_000]

# --------------------------------------------------------------------------------------
# Snowflake output
# --------------------------------------------------------------------------------------
OUTPUT_SCHEMA = "ML"   # CRI_DB.ML holds model outputs (kept apart from dbt-managed schemas)
