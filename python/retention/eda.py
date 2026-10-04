"""
Exploratory analysis of customer behaviour. Every number here is an OBSERVATION
(what happened in the data), not a rule or a prediction.
"""

import numpy as np
import pandas as pd

from . import charts, config


def run_eda(orders: pd.DataFrame, current: pd.DataFrame, test_snapshot: pd.DataFrame) -> dict:
    """
    orders        : valid orders (one row per order)
    current       : customer features as of the scoring date
    test_snapshot : labelled snapshot (features as of TEST_SNAPSHOT + 'returned' in next 180 days)
    """
    summary = {}

    # 1. How many times do customers buy? (distinct purchase days, so split baskets count once)
    freq = current["purchase_days"].clip(upper=4).value_counts(normalize=True).sort_index()
    summary["share_one_time_buyers"] = float(freq.get(1, 0))
    summary["share_repeat_buyers"] = float(1 - freq.get(1, 0))
    charts.bar(["1", "2", "3", "4+"], freq.reindex([1, 2, 3, 4], fill_value=0).values,
               "Most customers buy only once", "Share of customers", "01_purchase_days_distribution",
               subtitle="Distinct days with a purchase, per customer (2016-09 to 2018-09)")

    # 2. When people do come back, how long does it take?
    o = orders.sort_values(["customer_unique_id", "purchased_at"]).copy()
    o["gap_days"] = (o["purchased_at"] - o.groupby("customer_unique_id")["purchased_at"].shift()).dt.days
    gaps = o["gap_days"].dropna()
    summary["repeat_orders_same_day_share"] = float((gaps == 0).mean())
    real_gaps = gaps[gaps > 0]
    for d in (90, 180, 365):
        summary[f"repeat_gap_within_{d}d"] = float((real_gaps <= d).mean())
    summary["repeat_gap_median_days"] = float(real_gaps.median())
    charts.histogram(real_gaps.clip(upper=600), np.arange(0, 610, 15),
                     "When customers return, most do so within 6 months",
                     "Days since the previous purchase (same-day split orders excluded)",
                     "02_days_between_purchases", marker=config.HORIZON_DAYS,
                     marker_label=f"{summary['repeat_gap_within_180d']:.0%} within {config.HORIZON_DAYS} days")

    # 3. Revenue concentration
    rev = np.sort(current["monetary"].to_numpy())[::-1]
    share_c = np.arange(1, len(rev) + 1) / len(rev)
    share_r = np.cumsum(rev) / rev.sum()
    summary["top20_revenue_share"] = float(share_r[int(len(rev) * 0.2) - 1])
    charts.concentration_curve(share_c, share_r, "A minority of customers drive most revenue",
                               "03_revenue_concentration")

    # 4. Who actually came back? Return rate by recency (test snapshot, observed outcome)
    t = test_snapshot.copy()
    t["recency_bucket"] = pd.cut(t["recency_days"], [0, 90, 180, 365, 10_000],
                                 labels=["0-90", "91-180", "181-365", "365+"], right=True)
    by_recency = t.groupby("recency_bucket", observed=True)["returned"].mean()
    summary["return_rate_by_recency"] = {str(k): float(v) for k, v in by_recency.items()}
    charts.bar(by_recency.index.astype(str), by_recency.values,
               "Recent buyers are more likely to buy again", "Bought again within 180 days",
               "04_return_rate_by_recency", reference=t["returned"].mean(), reference_label="average",
               subtitle=f"Customers as of {config.TEST_SNAPSHOT.date()}, by days since last purchase")

    # 5. Experience: review score and late delivery
    reviewed = t[t["has_review"] == 1].copy()
    reviewed["review_bucket"] = reviewed["avg_review_score_observed"].round().astype(int)
    by_review = reviewed.groupby("review_bucket")["returned"].mean()
    summary["return_rate_by_review"] = {int(k): float(v) for k, v in by_review.items()}
    charts.bar([f"{k}*" for k in by_review.index], by_review.values,
               "Review score has only a small, noisy link to returning", "Bought again within 180 days",
               "05_return_rate_by_review", reference=t["returned"].mean(), reference_label="average",
               subtitle="Average review score given before the snapshot date")
    by_late = t.groupby("had_late_delivery")["returned"].mean()
    summary["return_rate_late_delivery"] = float(by_late.get(1, np.nan))
    summary["return_rate_on_time"] = float(by_late.get(0, np.nan))

    # 6. Useful descriptive stats of the current customer base
    summary["customers"] = int(len(current))
    summary["median_recency_days"] = float(current["recency_days"].median())
    summary["median_monetary"] = float(current["monetary"].median())
    summary["median_avg_order_value"] = float(current["avg_order_value"].median())
    return summary
