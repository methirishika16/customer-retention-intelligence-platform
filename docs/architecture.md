# Architecture

```mermaid
flowchart LR
    A["📁 Raw Data<br/>9 Olist CSV files<br/>(Kaggle)"]
    B[("❄️ Snowflake<br/>CRI_DB.RAW<br/>stage + COPY INTO")]
    C["🔧 dbt<br/>staging → marts<br/>tests & docs"]
    D["🐍 Python<br/>RFM segmentation<br/>churn-risk scoring"]
    E["📊 Tableau<br/>executive dashboard"]
    F["🖥️ Streamlit<br/>retention app"]

    A -->|"upload to internal stage"| B
    B -->|"sources"| C
    C -->|"customer marts"| D
    D --> E
    D --> F

    classDef done fill:#d4edda,stroke:#28a745,color:#000
    classDef next fill:#f8f9fa,stroke:#6c757d,color:#000,stroke-dasharray: 4 3
    class A,B done
    class C,D,E,F next
```

| Layer | Tool | Sprint | What happens |
|---|---|:---:|---|
| Raw data | CSV files | 1 ✅ | Downloaded from Kaggle, profiled with `python/inspect_dataset.py` |
| Warehouse | Snowflake | 1 ✅ | Loaded 1:1 into `CRI_DB.RAW`, validated with SQL checks |
| Transformation | dbt | 2 | Clean names, fix grains, build customer-level models |
| Analytics | Python | 3 | RFM scores, inactivity/churn-risk flags, prioritisation |
| Presentation | Tableau / Streamlit | 4 | Dashboards and an interactive retention app |

Solid green = built in Sprint 1. Dashed = planned.
