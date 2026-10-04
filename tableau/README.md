# Tableau

| What | Where |
|---|---|
| Dashboard design (every view, field, filter, title) | [../docs/tableau_dashboard_spec.md](../docs/tableau_dashboard_spec.md) |
| Data for Tableau Public | `tableau/data/*.csv`: create with `python python/export_tableau_data.py` (git-ignored) |
| Published dashboard | **[INSERT Tableau Public link]** |
| Screenshots | `docs/images/dashboard/` **[INSERT after building]** |
| Workbook (optional, no data) | `tableau/customer_retention.twb` **[INSERT if saved]** |

Tableau Public can't connect to Snowflake, which is why the CSV export exists.
With Tableau Desktop or Cloud, connect live to `CRI_DB.ML` and `CRI_DB.MARTS` instead.
