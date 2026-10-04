"""
Sprint 4: export Tableau-ready data sources from Snowflake to tableau/data/*.csv

    python python/export_tableau_data.py

Why CSV? Tableau PUBLIC (free, needed for a public portfolio link) cannot connect to
Snowflake. Tableau Desktop / Cloud users can connect live to the same tables instead
(see tableau/README.md). The CSVs are git-ignored: they're rebuilt from Snowflake.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from retention.config import PROJECT_ROOT  # noqa: E402
from retention.snowflake_io import connect, read_sql  # noqa: E402

EXPORT_DIR = PROJECT_ROOT / "tableau" / "data"

# file name -> (Snowflake query, what it powers in the dashboard)
SOURCES = {
    "customers": (
        """
        select s.*,
               date_trunc('month', s.first_purchase_date)::date as acquisition_month,
               r.avg_review_score, r.late_delivery_count
        from ML.CUSTOMER_RETENTION_SCORES s
        join MARTS.CUSTOMER_RFM r using (customer_unique_id)
        """,
        "One row per customer: segments, risk, actions, priority (most views)",
    ),
    "kpi_summary": ("select * from MARTS.KPI_SUMMARY", "Executive KPI tiles"),
    "monthly_revenue": ("select * from MARTS.MONTHLY_REVENUE", "Revenue trend, new vs returning"),
    "cohort_retention": ("select * from MARTS.COHORT_RETENTION", "Cohort retention heatmap"),
    "customer_acquisition_monthly": ("select * from MARTS.CUSTOMER_ACQUISITION_MONTHLY", "Acquisition trend"),
    "category_performance": ("select * from MARTS.CATEGORY_PERFORMANCE", "Category opportunity view"),
    "budget_scenarios": ("select * from ML.BUDGET_SCENARIOS", "Budget scenario table"),
    "model_evaluation": ("select * from ML.MODEL_EVALUATION", "Model appendix"),
    "model_lift_by_decile": ("select * from ML.MODEL_LIFT_BY_DECILE", "Model appendix: lift chart"),
    "model_coefficients": ("select * from ML.MODEL_COEFFICIENTS", "Model appendix: drivers"),
}


def main():
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    conn = connect()
    for name, (sql, purpose) in SOURCES.items():
        df = read_sql(conn, sql)
        df.to_csv(EXPORT_DIR / f"{name}.csv", index=False)
        print(f"  {name + '.csv':<36} {len(df):>7,} rows   {purpose}")
    conn.close()
    print(f"\nDone. Files in {EXPORT_DIR.relative_to(PROJECT_ROOT)}/")


if __name__ == "__main__":
    main()
