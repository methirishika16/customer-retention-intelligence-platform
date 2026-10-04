"""
Load order history from Snowflake and build customer features "as of" any date.

LEAKAGE RULE (the most important idea in this file):
    Features for a snapshot date may only use information that was KNOWN before that date.
    - orders purchased before the date
    - deliveries completed before the date (a late delivery isn't known until it arrives)
    - reviews answered before the date
    The label (did they buy again?) looks only at the HORIZON_DAYS AFTER the date.
"""

import numpy as np
import pandas as pd

from . import config
from .snowflake_io import read_sql

# Features the model uses. Kept small on purpose so every coefficient can be explained.
MODEL_FEATURES = [
    "log_recency_days",     # how long since the last purchase (log scale)
    "purchase_days",        # distinct days with a purchase (capped at 5)
    "log_monetary",         # total spent (log scale)
    "log_tenure_days",      # days between first and last purchase (log scale)
    "items_per_order",      # basket size
    "avg_review_score",     # satisfaction (missing -> average, see has_review)
    "has_review",           # did the customer answer a survey?
    "had_late_delivery",    # ever received an order late?
    "is_sao_paulo",         # lives in SP, the largest and best-served state
]


def load_orders_and_reviews(conn):
    """Valid orders from the dbt fact table + review answer times from staging."""
    orders = read_sql(conn, """
        select customer_unique_id, order_id, customer_state, purchased_at, delivered_at,
               is_late_delivery, order_revenue, item_count
        from MARTS.FCT_ORDERS
        where is_valid_purchase
    """)
    reviews = read_sql(conn, """
        select order_id, review_score, survey_answered_at
        from STAGING.STG_OLIST__ORDER_REVIEWS
    """)
    for col in ("purchased_at", "delivered_at"):
        orders[col] = pd.to_datetime(orders[col])
    reviews["survey_answered_at"] = pd.to_datetime(reviews["survey_answered_at"])
    orders["order_revenue"] = orders["order_revenue"].astype(float)
    orders["is_late_delivery"] = orders["is_late_delivery"].astype(float)   # True/False/None -> 1/0/NaN
    reviews["review_score"] = reviews["review_score"].astype(float)
    return orders, reviews


def build_features(orders: pd.DataFrame, reviews: pd.DataFrame, as_of: pd.Timestamp) -> pd.DataFrame:
    """One row per customer who purchased before `as_of`, using only information known then."""
    hist = orders[orders["purchased_at"] < as_of].copy()
    hist["purchase_day"] = hist["purchased_at"].dt.normalize()

    base = hist.sort_values("purchased_at").groupby("customer_unique_id").agg(
        first_purchase_at=("purchased_at", "min"),
        last_purchase_at=("purchased_at", "max"),
        order_count=("order_id", "count"),
        purchase_days=("purchase_day", "nunique"),     # same-day split orders count once
        monetary=("order_revenue", "sum"),
        total_items=("item_count", "sum"),
        customer_state=("customer_state", "last"),
    )

    # Deliveries that had ARRIVED before as_of (otherwise lateness wasn't known yet)
    delivered = hist[hist["delivered_at"] < as_of]
    late = delivered.groupby("customer_unique_id")["is_late_delivery"].max()

    # Reviews ANSWERED before as_of, for this customer's orders
    known_reviews = reviews[reviews["survey_answered_at"] < as_of].merge(
        hist[["order_id", "customer_unique_id"]], on="order_id")
    review_avg = known_reviews.groupby("customer_unique_id")["review_score"].mean()

    f = base.join(late.rename("had_late_delivery")).join(review_avg.rename("avg_review_score"))
    f["as_of_date"] = as_of
    f["recency_days"] = (as_of - f["last_purchase_at"]).dt.total_seconds() / 86400
    f["days_since_first_purchase"] = (as_of - f["first_purchase_at"]).dt.total_seconds() / 86400
    f["tenure_days"] = (f["last_purchase_at"] - f["first_purchase_at"]).dt.total_seconds() / 86400
    f["avg_order_value"] = f["monetary"] / f["order_count"]
    f["items_per_order"] = f["total_items"] / f["order_count"]
    f["is_repeat_customer"] = (f["purchase_days"] >= 2).astype(int)
    f["orders_per_month_active"] = f["order_count"] / np.maximum(f["days_since_first_purchase"] / 30.44, 1)

    # Model-ready versions
    f["avg_review_score_observed"] = f["avg_review_score"]   # NULL if the customer never answered
    f["has_review"] = f["avg_review_score"].notna().astype(int)
    # Fill missing with the average of reviews known at as_of (not the all-time average: that would leak)
    f["avg_review_score"] = f["avg_review_score"].fillna(known_reviews["review_score"].mean())
    f["had_late_delivery"] = f["had_late_delivery"].fillna(0).astype(int)
    f["is_sao_paulo"] = (f["customer_state"] == "SP").astype(int)
    f["log_recency_days"] = np.log1p(f["recency_days"])
    f["log_monetary"] = np.log1p(f["monetary"])
    f["log_tenure_days"] = np.log1p(f["tenure_days"])
    f["purchase_days"] = f["purchase_days"].clip(upper=5)
    return f.reset_index()


def add_label(features: pd.DataFrame, orders: pd.DataFrame, as_of: pd.Timestamp,
              horizon_days: int = config.HORIZON_DAYS) -> pd.DataFrame:
    """returned = 1 if the customer made a valid purchase in [as_of, as_of + horizon)."""
    window_end = as_of + pd.Timedelta(days=horizon_days)
    if window_end > orders["purchased_at"].max() + pd.Timedelta(days=1):
        raise ValueError(f"Label window {as_of.date()}..{window_end.date()} runs past the end of the data")
    in_window = orders[(orders["purchased_at"] >= as_of) & (orders["purchased_at"] < window_end)]
    out = features.copy()
    out["returned"] = out["customer_unique_id"].isin(set(in_window["customer_unique_id"])).astype(int)
    return out


def build_labelled_snapshot(orders, reviews, as_of):
    return add_label(build_features(orders, reviews, as_of), orders, as_of)
