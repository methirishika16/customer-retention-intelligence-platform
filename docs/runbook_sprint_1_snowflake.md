# Runbook: Sprint 1, Snowflake Data Foundation

Step-by-step instructions moved here from the README.


**Goal:** load the Olist dataset into Snowflake as a clean, validated RAW layer that later sprints can trust.

### Deliverables
- Raw dataset profiled and every column checked against the expected schema
- Snowflake warehouse `CRI_WH`, database `CRI_DB`, schema `RAW`
- 9 RAW tables loaded 1:1 from the source CSVs (~1.55M rows)
- Validation suite: row counts, nulls, duplicates, data types/domains, relationships
- Data model, data dictionary, architecture diagram, business problem statement

### Design decisions
| Decision | Why |
|---|---|
| Keep RAW identical to source (names, typos, order) | RAW is an audit copy. Cleaning happens in dbt where it is tested and documented. |
| Zip prefixes as `VARCHAR` | Preserve leading zeros; they're codes, not numbers. |
| `ON_ERROR = 'ABORT_STATEMENT'` | A failed row should stop the load, not be silently skipped. |
| TRUNCATE before each COPY | Re-running the load never creates duplicates. |
| X-Small warehouse, 60-second auto-suspend | Keeps trial credits low. |
| PK constraints declared but tested in SQL | Snowflake doesn't enforce them, so the duplicate checks do the enforcing. |

### How to run Sprint 1 (step by step)

#### Step 0 — Prerequisites
- A Snowflake account (a free 30-day trial at https://signup.snowflake.com is fine; any edition/cloud).
- A Kaggle account to download the data.
- Python 3.10+ and Git installed locally.

#### Step 1 — Get the data *(manual)*
Download the dataset from Kaggle and unzip the 9 CSVs into `data/raw/`. See [data/README.md](../data/README.md).

#### Step 2 — Inspect the data locally
```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python python/inspect_dataset.py
```
✅ Expect `All files present and all columns match`. Read the generated `docs/dataset_profile.md`.
If any row counts differ from the defaults in `05_row_count_validation.sql`, update that file.

#### Step 3 — Create warehouse, database, schema *(Snowsight)*
1. Log in to Snowsight → **Projects » Worksheets** (in some UI versions just **Worksheets**) → **+ SQL Worksheet**.
2. Paste `snowflake/01_setup/01_create_warehouse_database_schema.sql`, then click the **▼ next to the blue ▶ button → Run All**.
   Use the menu: plain ▶ (and in some UI versions the keyboard shortcut) runs only part of the script.
3. ✅ You should see `CRI_WH` and the `RAW` schema in the results.

#### Step 4 — Create tables, file format and stage *(Snowsight)*
Run, in order, with **Run All**:
1. `snowflake/02_ddl/02_create_raw_tables.sql` → ✅ 9 tables listed
2. `snowflake/03_load/03_create_file_format_and_stage.sql` → ✅ `FF_OLIST_CSV` and `OLIST_STAGE` exist

#### Step 5 — Upload the CSVs to the stage *(manual, pick ONE option)*
**Option A — Snowsight UI (easiest):**
1. Left menu → **Data » Databases** (called **Catalog » Database Explorer** in newer UIs) → `CRI_DB` → `RAW` → **Stages** → `OLIST_STAGE`.
2. Click **+ Files** (top right), select all 9 CSVs from `data/raw/`, click **Upload**.

**Option B — Python (repeatable):**
```bash
cp .env.example .env     # then edit .env with your account details
python python/upload_to_stage.py
```

✅ In a worksheet, `LIST @CRI_DB.RAW.OLIST_STAGE;` shows 9 files.

#### Step 6 — Load the tables *(Snowsight)*
Run `snowflake/03_load/04_load_raw_tables.sql` with **Run All**.
✅ Every COPY result shows `status = LOADED` and `errors_seen = 0`. The final query lists 9 loaded files.
If a COPY fails, read the error message: it names the file, line and column. Fix it, then re-run the file.

#### Step 7 — Validate *(Snowsight)*
Run each file in `snowflake/04_validation/` in order. Look at the `status` column:

| Status | Meaning | Action |
|---|---|---|
| `PASS` | Check succeeded | — |
| `FAIL` | Data broke a hard rule | **Stop.** Fix before Sprint 2. |
| `WARN` / `INFO` | Known real-world messiness in the source | Note the count in `docs/data_dictionary.md`. It will be handled in dbt. |

Expected `WARN`/`INFO` rows (normal for this dataset): nulls in delivery dates, product categories and
review comments; repeat `customer_unique_id`s; shared `review_id`s; duplicate geolocation rows; a few
untranslated categories; orders without items.

#### Step 8 — Commit to Git and push to GitHub
```bash
git add .
git commit -m "Sprint 1: Snowflake data foundation"
```
Then create an **empty** repo on github.com (no README or .gitignore) and push to it:
```bash
git remote add origin https://github.com/<your-username>/customer-retention-intelligence-platform.git
git push -u origin main
```

### Sprint 1 completion checklist
- [x] 9 CSVs in `data/raw/` and **not** showing in `git status`
- [x] `python python/inspect_dataset.py` reports all columns match
- [x] `CRI_WH`, `CRI_DB`, `CRI_DB.RAW` exist
- [x] 9 RAW tables created, file format and stage created
- [x] `LIST @OLIST_STAGE` shows 9 files
- [x] All 9 COPY INTO commands report `LOADED` with 0 errors
- [x] `05_row_count_validation` → all PASS
- [x] `06_null_checks` → no FAIL
- [x] `07_duplicate_checks` (Section A) → no FAIL
- [x] `08_data_type_validation` → no FAIL
- [x] `09_relationship_checks` → no FAIL
- [x] WARN/INFO counts recorded in `docs/data_dictionary.md`
- [x] No secrets committed (`.env` ignored), pushed to GitHub
