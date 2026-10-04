"""
Sprint 3 — Customer Retention Intelligence pipeline.

    python python/run_sprint3.py

Steps
  1. Load orders, reviews and the dbt customer model (MARTS.CUSTOMER_RFM) from Snowflake
  2. Exploratory analysis                              -> docs/images/sprint3/*.png
  3. Build leakage-safe time snapshots, train on 2017, test on 2018 (out-of-time)
  4. Compare logistic regression with two simple rules (recency, RFM)
  5. Refit on all labelled snapshots, score every customer as of 2018-09-04
  6. Value tier, risk tier, customer group, next best action, priority score, budget plan
  7. Validate the output, then write it to Snowflake (CRI_DB.ML) and outputs/*.csv

Observation vs rule vs prediction:
  OBSERVATION = happened in the data (spend, recency, orders)
  RULE        = a business definition we chose (tiers, groups, actions, priority)
  PREDICTION  = model output (return_probability, expected_revenue_180d)
"""

import json
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
warnings.filterwarnings("ignore", category=UserWarning)

from retention import actions, charts, config, eda  # noqa: E402
from retention import features as F  # noqa: E402
from retention import model as M  # noqa: E402
from retention.snowflake_io import connect, read_sql, write_table  # noqa: E402


def step(n, text):
    print(f"\n[{n}/7] {text}")


def main():
    config.OUTPUT_DIR.mkdir(exist_ok=True)

    # 1. Load -------------------------------------------------------------------------------
    step(1, "Loading data from Snowflake")
    conn = connect()
    orders, reviews = F.load_orders_and_reviews(conn)
    rfm = read_sql(conn, """
        select customer_unique_id, total_revenue, order_count, avg_order_value, customer_state,
               first_purchase_date, last_purchase_date, days_since_last_purchase,
               r_score, f_score, m_score, rfm_segment, is_high_value, activity_status
        from MARTS.CUSTOMER_RFM
    """)
    rfm["total_revenue"] = rfm["total_revenue"].astype(float)
    print(f"  {len(orders):,} valid orders | {len(reviews):,} reviews | {len(rfm):,} customers")

    # 3 (data prep first, EDA uses the snapshots) -------------------------------------------
    train = pd.concat([F.build_labelled_snapshot(orders, reviews, d) for d in config.TRAIN_SNAPSHOTS],
                      ignore_index=True)
    test = F.build_labelled_snapshot(orders, reviews, config.TEST_SNAPSHOT)
    current = F.build_features(orders, reviews, config.SCORING_DATE)

    # 2. EDA --------------------------------------------------------------------------------
    step(2, "Exploratory analysis")
    eda_summary = eda.run_eda(orders, current, test)
    print(f"  one-time buyers: {eda_summary['share_one_time_buyers']:.1%} | "
          f"top 20% of customers = {eda_summary['top20_revenue_share']:.1%} of revenue | "
          f"repeat purchases within 180 days: {eda_summary['repeat_gap_within_180d']:.1%}")

    # 3-4. Train & evaluate -------------------------------------------------------------------
    step(3, "Training on 2017 snapshots, testing on 2018 (out-of-time)")
    for d in config.TRAIN_SNAPSHOTS:
        assert d + pd.Timedelta(days=config.HORIZON_DAYS) <= config.TEST_SNAPSHOT, "train label window overlaps test"
    print(f"  train: {len(train):,} customer-snapshots, {train['returned'].sum()} returned ({train['returned'].mean():.2%})")
    print(f"  test : {len(test):,} customers, {test['returned'].sum()} returned ({test['returned'].mean():.2%})")
    lr = M.fit(train)
    p_test = M.predict_proba(lr, test)

    step(4, "Comparing logistic regression with simple rules")
    evaluation = pd.DataFrame([
        M.evaluate("Logistic regression", test["returned"], p_test, p_test),
        M.evaluate("Rule: most recent first", test["returned"], M.rule_recency(test)),
        M.evaluate("Rule: RFM score", test["returned"], M.rule_rfm(test)),
        M.evaluate("Random (no model)", test["returned"], np.random.default_rng(0).random(len(test))),
    ])
    deciles = M.decile_table(test["returned"].to_numpy(), p_test)
    print(evaluation[["model", "roc_auc", "pr_auc", "lift_top_10pct", "capture_top_20pct"]].round(3).to_string(index=False))

    charts.bar(deciles["decile"], deciles["lift"],
               "Customers the model ranks highest return ~2x more often",
               "Lift (actual return rate ÷ average)", "06_lift_by_decile", fmt="{:.1f}x",
               highlight=[0], reference=1.0, reference_label="average",
               subtitle=f"Out-of-time test: customers as of {config.TEST_SNAPSHOT.date()}, decile 1 = highest predicted")

    # 5. Final model: refit on every labelled snapshot, score everyone ------------------------
    step(5, f"Refitting on all labelled snapshots and scoring customers as of {config.SCORING_DATE.date()}")
    final_train = pd.concat([train, test], ignore_index=True)
    final_model = M.fit(final_train)
    coefficients = M.coefficient_table(final_model)
    # Stability check: compare with the model trained on 2017 only. A feature whose effect
    # flips direction between the two fits is too weak to interpret.
    train_only = M.coefficient_table(lr).set_index("feature")["odds_ratio_per_sd"]
    coefficients["odds_ratio_train_2017_only"] = coefficients["feature"].map(train_only)
    coefficients["stable_direction"] = (
        (coefficients["odds_ratio_per_sd"] - 1) * (coefficients["odds_ratio_train_2017_only"] - 1) > 0
    )
    nice = {"log_recency_days": "Days since last purchase", "avg_review_score": "Average review score",
            "had_late_delivery": "Had a late delivery", "log_tenure_days": "Customer tenure",
            "purchase_days": "Purchase days (frequency)", "has_review": "Answered a review",
            "is_sao_paulo": "Lives in São Paulo", "items_per_order": "Items per order",
            "log_monetary": "Total spend"}
    charts.hbar([nice[f] for f in coefficients["feature"]], coefficients["odds_ratio_per_sd"],
                "What moves the odds of a customer returning", "Odds ratio per 1 standard deviation (1.0 = no effect)",
                "07_odds_ratios", fmt="{:.2f}x", center=1.0,
                colors=[charts.BLUE if v >= 1 else charts.ORANGE for v in coefficients["odds_ratio_per_sd"]])
    print(coefficients[["feature", "odds_ratio_per_sd", "odds_ratio_train_2017_only", "stable_direction"]]
          .round(3).to_string(index=False))

    scored = current.copy()
    scored["return_probability"] = M.predict_proba(final_model, scored)

    # 6. Business layer ------------------------------------------------------------------------
    step(6, "Building tiers, groups, next best actions, priority score and budget plan")
    df = scored.merge(rfm, on="customer_unique_id", how="inner", suffixes=("", "_dbt"))
    df["expected_revenue_180d"] = df["return_probability"] * df["avg_order_value"]
    df["value_tier"] = actions.value_tier(df)
    df["risk_tier"] = actions.risk_tier(df["return_probability"])
    df["customer_group"] = actions.customer_group(df)
    df = pd.concat([df, actions.next_best_action(df)], axis=1)
    df["priority_score"] = actions.priority_score(df)
    df = actions.add_budget_columns(df)
    scenarios = actions.budget_scenarios(df)

    groups = (df.groupby("customer_group")
                .agg(customers=("customer_unique_id", "count"), revenue=("total_revenue", "sum"),
                     avg_priority=("priority_score", "mean"))
                .sort_values("avg_priority", ascending=False))
    charts.hbar(groups.index.tolist(), groups["customers"].tolist(), "Customers per retention group",
                "Customers", "08_customer_groups", fmt="{:,.0f}")
    print(groups.round(1).to_string())
    print(scenarios[["budget_brl", "customers_reached", "share_of_historical_revenue",
                     "high_value_customers_reached"]].round(3).to_string(index=False))

    # 7. Validate & write -----------------------------------------------------------------------
    step(7, "Validating and writing results")
    output = df[[
        # identity & observations (from dbt / order history)
        "customer_unique_id", "customer_state", "first_purchase_date", "last_purchase_date",
        "recency_days", "order_count", "purchase_days", "total_revenue", "avg_order_value",
        "tenure_days", "items_per_order", "avg_review_score_observed", "had_late_delivery",
        "is_repeat_customer", "rfm_segment", "r_score", "f_score", "m_score",
        # rules
        "activity_status", "value_tier",
        # predictions
        "return_probability", "expected_revenue_180d",
        # rules built on predictions
        "risk_tier", "customer_group", "next_best_action", "action_reason", "action_cost_brl",
        "priority_score", "priority_rank", "cumulative_action_cost_brl",
    ]].copy()
    output["recency_days"] = output["recency_days"].round(1)
    output["tenure_days"] = output["tenure_days"].round(1)
    output["return_probability"] = output["return_probability"].round(5)
    output["expected_revenue_180d"] = output["expected_revenue_180d"].round(2)
    output["scored_as_of"] = config.SCORING_DATE.date()
    output["model_version"] = "logreg_v1"

    checks = {
        "one row per customer": output["customer_unique_id"].is_unique,
        "every dbt customer scored": len(output) == len(rfm),
        "probabilities between 0 and 1": output["return_probability"].between(0, 1).all(),
        "priority score between 0 and 100": output["priority_score"].between(0, 100).all(),
        "every action has a cost": output["action_cost_brl"].notna().all(),
        "no missing group": output["customer_group"].notna().all(),
    }
    for name, ok in checks.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    if not all(checks.values()):
        raise SystemExit("Validation failed: nothing written to Snowflake.")

    tables = {
        "CUSTOMER_RETENTION_SCORES": output,
        "MODEL_EVALUATION": evaluation.assign(test_snapshot=config.TEST_SNAPSHOT.date(),
                                              horizon_days=config.HORIZON_DAYS),
        "MODEL_COEFFICIENTS": coefficients,
        "MODEL_LIFT_BY_DECILE": deciles,
        "BUDGET_SCENARIOS": scenarios,
    }
    for name, table in tables.items():
        n = write_table(conn, table, name, config.OUTPUT_SCHEMA)
        table.to_csv(config.OUTPUT_DIR / f"{name.lower()}.csv", index=False)
        print(f"  wrote CRI_DB.{config.OUTPUT_SCHEMA}.{name} ({n:,} rows)")

    summary = {"eda": eda_summary, "evaluation": evaluation.to_dict(orient="records"),
               "groups": groups.reset_index().to_dict(orient="records"),
               "actions": output["next_best_action"].value_counts().to_dict(),
               "budget": scenarios.to_dict(orient="records")}
    (config.OUTPUT_DIR / "sprint3_summary.json").write_text(json.dumps(summary, indent=2, default=str))
    conn.close()
    print("\nDone. Charts in docs/images/sprint3/, tables in CRI_DB.ML, CSVs in outputs/.")


if __name__ == "__main__":
    main()
