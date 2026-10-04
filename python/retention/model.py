"""
An interpretable "return likelihood" model: logistic regression, compared against two
simple rules so we can see whether the model adds anything over common sense.

What it predicts: P(customer makes another valid purchase in the next 180 days).
What it does NOT predict: churn. The data has no churn label; a customer who doesn't buy
in 180 days may still come back later.
"""

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, roc_auc_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from .features import MODEL_FEATURES


def make_model():
    # StandardScaler puts every feature on the same scale, so coefficient sizes are comparable.
    # Mild L2 regularisation (C=1) keeps coefficients stable; no class re-weighting, so the
    # predicted probabilities stay realistic (about 1-2%) rather than inflated.
    return make_pipeline(StandardScaler(), LogisticRegression(C=1.0, max_iter=2000))


def fit(train: pd.DataFrame):
    model = make_model()
    model.fit(train[MODEL_FEATURES], train["returned"])
    return model


def predict_proba(model, df: pd.DataFrame) -> np.ndarray:
    return model.predict_proba(df[MODEL_FEATURES])[:, 1]


# ---------------------------------------------------------------------------------------
# Baseline rules (no model). If logistic regression can't beat these, use the rule instead.
# ---------------------------------------------------------------------------------------
def rule_recency(df: pd.DataFrame) -> np.ndarray:
    """'Recent buyers come back': higher score = bought more recently."""
    return -df["recency_days"].to_numpy()


def rule_rfm(df: pd.DataFrame) -> np.ndarray:
    """Classic RFM: average of recency, frequency and monetary percentile ranks."""
    r = (-df["recency_days"]).rank(pct=True)
    f = df["purchase_days"].rank(pct=True)
    m = df["monetary"].rank(pct=True)
    return ((r + f + m) / 3).to_numpy()


# ---------------------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------------------
def top_share_stats(y: np.ndarray, score: np.ndarray, share: float) -> tuple[float, float]:
    """Return (lift, capture) when contacting the top `share` of customers by score."""
    n_top = max(int(round(len(y) * share)), 1)
    order = np.argsort(-score, kind="stable")
    top = y[order][:n_top]
    lift = top.mean() / y.mean()
    capture = top.sum() / y.sum()
    return lift, capture


def evaluate(name: str, y: np.ndarray, score: np.ndarray, proba: np.ndarray | None = None) -> dict:
    y = np.asarray(y)
    lift10, capture10 = top_share_stats(y, score, 0.10)
    lift20, capture20 = top_share_stats(y, score, 0.20)
    result = {
        "model": name,
        "customers": len(y),
        "returned": int(y.sum()),
        "base_rate": y.mean(),
        "roc_auc": roc_auc_score(y, score),
        "pr_auc": average_precision_score(y, score),
        "lift_top_10pct": lift10,
        "capture_top_10pct": capture10,
        "lift_top_20pct": lift20,
        "capture_top_20pct": capture20,
        "brier_score": brier_score_loss(y, proba) if proba is not None else np.nan,
        "brier_score_baseline": brier_score_loss(y, np.full(len(y), y.mean())) if proba is not None else np.nan,
    }
    return result


def decile_table(y: np.ndarray, proba: np.ndarray) -> pd.DataFrame:
    """Customers split into 10 equal groups by predicted probability (decile 1 = highest).
    Compares predicted vs actual return rate: the basis of the lift chart and a calibration check."""
    df = pd.DataFrame({"y": y, "p": proba})
    df["decile"] = pd.qcut(df["p"].rank(method="first", ascending=False), 10, labels=range(1, 11)).astype(int)
    t = df.groupby("decile").agg(customers=("y", "size"), returned=("y", "sum"),
                                 predicted_rate=("p", "mean"), actual_rate=("y", "mean"))
    t["lift"] = t["actual_rate"] / df["y"].mean()
    t["cumulative_capture"] = t["returned"].cumsum() / df["y"].sum()
    return t.reset_index()


def coefficient_table(model) -> pd.DataFrame:
    """Coefficients on standardised features, translated into odds ratios.
    odds_ratio_per_sd = how the odds of returning change when the feature rises by one
    standard deviation, holding everything else equal (1.0 = no effect)."""
    lr = model.named_steps["logisticregression"]
    scaler = model.named_steps["standardscaler"]
    coefs = pd.DataFrame({
        "feature": MODEL_FEATURES,
        "coefficient": lr.coef_[0],
        "feature_std": scaler.scale_,
    })
    coefs["odds_ratio_per_sd"] = np.exp(coefs["coefficient"])
    coefs["direction"] = np.where(coefs["coefficient"] > 0, "more likely to return", "less likely to return")
    return coefs.sort_values("coefficient", key=np.abs, ascending=False).reset_index(drop=True)
