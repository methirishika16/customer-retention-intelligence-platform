"""
Turn observations + the model's prediction into business decisions:
value tier, risk tier, customer group, next best action, priority score and budget plan.
Everything in this file is a BUSINESS RULE: transparent, editable in config.py.
"""

import numpy as np
import pandas as pd

from . import config


def value_tier(df: pd.DataFrame) -> pd.Series:
    """High = dbt's is_high_value (top 20% spend, or repeat buyer in top 40%).
    Medium = M score 3-4. Low = M score 1-2 (bottom 40% of spend)."""
    return np.select(
        [df["is_high_value"], df["m_score"] >= 3],
        ["High", "Medium"],
        default="Low",
    )


def risk_tier(return_probability: pd.Series) -> pd.Series:
    """Relative risk: rank customers by predicted return probability.
    Bottom 40% -> High risk, top 20% -> Low risk, the rest -> Medium."""
    pct = return_probability.rank(pct=True)
    return np.select(
        [pct <= config.RISK_HIGH_BELOW_PCT, pct > config.RISK_LOW_ABOVE_PCT],
        ["High", "Low"],
        default="Medium",
    )


def customer_group(df: pd.DataFrame) -> pd.Series:
    """First matching rule wins."""
    is_loyal = (df["purchase_days"] >= 2) & (df["activity_status"] != "Inactive")
    is_new = (df["purchase_days"] == 1) & (df["days_since_first_purchase"] <= config.NEW_CUSTOMER_DAYS)
    high_risk = df["risk_tier"] == "High"
    return np.select(
        [
            is_loyal,
            is_new,
            (df["value_tier"] == "High") & high_risk,
            (df["value_tier"] == "High"),
            (df["value_tier"] == "Medium") & high_risk,
            (df["value_tier"] == "Medium"),
        ],
        [
            "Loyal Customer",
            "New Customer",
            "High Value - High Risk",
            "High Value - Lower Risk",
            "Medium Value - High Risk",
            "Medium Value - Lower Risk",
        ],
        default="Low Value",
    )


# group -> (action, reason)
ACTION_BY_GROUP = {
    "Loyal Customer": ("Loyalty reward", "Proven repeat buyer: thank and retain"),
    "New Customer": ("Second-purchase incentive", "First purchase in the last 90 days: the 2nd order is the hardest"),
    "High Value - High Risk": ("Win-back offer", "Spent a lot but unlikely to return without a reason"),
    "High Value - Lower Risk": ("Product cross-sell", "Valuable and still engaged: suggest related products"),
    "Medium Value - High Risk": ("Second-purchase incentive", "Mid spender drifting away: small coupon"),
    "Medium Value - Lower Risk": ("Product cross-sell", "Mid spender, reasonably engaged: recommend products"),
    "Low Value": ("Low-cost email campaign", "Low historical spend: keep in touch cheaply"),
}


def next_best_action(df: pd.DataFrame) -> pd.DataFrame:
    action = df["customer_group"].map(lambda g: ACTION_BY_GROUP[g][0])
    reason = df["customer_group"].map(lambda g: ACTION_BY_GROUP[g][1])
    # Override: a bad experience comes first. Don't send a sales offer to someone who
    # rated us 1-2 stars; fix the relationship. Only for customers worth the cost.
    unhappy = (df["avg_review_score_observed"] <= config.POOR_EXPERIENCE_REVIEW) & df["value_tier"].isin(["High", "Medium"])
    action = action.where(~unhappy, "Service recovery")
    reason = reason.where(~unhappy, "Gave a 1-2 star review: apologise before selling")
    return pd.DataFrame({"next_best_action": action, "action_reason": reason,
                         "action_cost_brl": action.map(config.ACTION_COST_BRL)})


def priority_score(df: pd.DataFrame) -> pd.Series:
    """0-100. Weighted mix of value (percentile of spend), likelihood (percentile of predicted
    return probability) and urgency (activity status). Higher = contact first."""
    w = config.PRIORITY_WEIGHTS
    value_pct = df["total_revenue"].rank(pct=True)
    likelihood_pct = df["return_probability"].rank(pct=True)
    urgency = df["activity_status"].map(config.URGENCY_BY_STATUS)
    score = 100 * (w["value"] * value_pct + w["likelihood"] * likelihood_pct + w["urgency"] * urgency)
    return score.round(1)


def add_budget_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rank by priority and add a running total of action cost.
    To apply ANY budget: keep customers whose cumulative_action_cost_brl <= budget."""
    out = df.sort_values(["priority_score", "total_revenue"], ascending=False).copy()
    out["priority_rank"] = np.arange(1, len(out) + 1)
    out["cumulative_action_cost_brl"] = out["action_cost_brl"].cumsum().round(2)
    return out


def budget_scenarios(df: pd.DataFrame) -> pd.DataFrame:
    """For each budget: how many customers we can reach (in priority order) and what they represent."""
    rows = []
    total_revenue = df["total_revenue"].sum()
    for budget in config.BUDGET_SCENARIOS_BRL:
        chosen = df[df["cumulative_action_cost_brl"] <= budget]
        row = {
            "budget_brl": budget,
            "customers_reached": len(chosen),
            "share_of_customers": len(chosen) / len(df),
            "spend_brl": chosen["action_cost_brl"].sum(),
            "historical_revenue_of_reached": chosen["total_revenue"].sum(),
            "share_of_historical_revenue": chosen["total_revenue"].sum() / total_revenue,
            "high_value_customers_reached": int((chosen["value_tier"] == "High").sum()),
            # Prediction: revenue expected from these customers in 180 days if nothing is done.
            "expected_baseline_revenue_180d": chosen["expected_revenue_180d"].sum(),
            "lowest_priority_score_included": chosen["priority_score"].min() if len(chosen) else np.nan,
        }
        for action in config.ACTION_COST_BRL:
            row[f"n_{action.lower().replace(' ', '_').replace('-', '_')}"] = int((chosen["next_best_action"] == action).sum())
        rows.append(row)
    return pd.DataFrame(rows)
