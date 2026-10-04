# Architecture

```mermaid
flowchart LR
    A["📁 Raw data<br/>9 Olist CSV files (Kaggle)"]
    B[("❄️ Snowflake<br/>CRI_DB.RAW<br/>stage + COPY INTO")]
    C["🔧 dbt<br/>CRI_DB.STAGING / INTERMEDIATE / MARTS<br/>22 models · 112 tests"]
    D["🐍 Python<br/>return model · groups<br/>next best action · priority"]
    E[("❄️ CRI_DB.ML<br/>customer scores<br/>budget scenarios")]
    F["📊 Tableau<br/>5 dashboards"]
    G["🖥️ Streamlit<br/>(future)"]

    A -->|"upload to internal stage"| B
    B -->|"sources"| C
    C -->|"customer marts"| D
    D -->|"write_pandas"| E
    C -->|"KPIs, cohorts, categories"| F
    E -->|"scores, actions, priority"| F
    E -.-> G

    classDef done fill:#d4edda,stroke:#28a745,color:#000
    classDef build fill:#fff4e5,stroke:#eb6834,color:#000
    classDef next fill:#f8f9fa,stroke:#6c757d,color:#000,stroke-dasharray: 4 3
    class A,B,C,D,E done
    class F build
    class G next
```

| Layer | Tool | Sprint | What happens |
|---|---|:---:|---|
| Raw data | CSV files | 1 ✅ | Downloaded from Kaggle, profiled with `python/inspect_dataset.py` |
| Warehouse | Snowflake | 1 ✅ | Loaded 1:1 into `CRI_DB.RAW`, validated with SQL checks |
| Transformation | dbt | 2 ✅ | Staging → intermediate → marts: clean data, KPIs, customer model, RFM, cohorts ([details](dbt_models.md)) |
| Analytics | Python | 3 ✅ | Leakage-safe return model, value × risk groups, next best action, priority score, budget plan ([details](sprint_3_methodology.md)) |
| Presentation | Tableau | 4 | 5 dashboards ([spec](tableau_dashboard_spec.md)); data via `python/export_tableau_data.py` |
| App | Streamlit | future | Marketing-facing priority list with a budget slider |

Green = built and validated. Orange = designed, built by hand in Tableau. Dashed = future improvement.

**Snowflake schemas:** `RAW` (source copy) · `STAGING`, `INTERMEDIATE`, `MARTS` (dbt-managed) · `ML` (Python output).
