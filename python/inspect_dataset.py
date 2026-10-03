"""
Sprint 1 — Inspect the raw Olist CSV files BEFORE loading them into Snowflake.

What it does
  1. Confirms all 9 expected files exist in data/raw/.
  2. Confirms each file has exactly the columns our Snowflake tables expect
     (same names, same order — COPY INTO maps columns by position).
  3. Profiles every column: nulls, distinct values, an example value.
  4. Checks the candidate primary key of each file for duplicates.
  5. Writes a Markdown report to docs/dataset_profile.md.

Usage (from the project root):
    python python/inspect_dataset.py
    python python/inspect_dataset.py --data-dir path/to/csvs

Exit code is 1 if a file is missing or its columns don't match, so you know
not to continue to the Snowflake load yet.
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# The contract between the CSV files and the Snowflake RAW tables.
# Column lists are in file order. Keys are the grain we expect (None = no unique key).
EXPECTED = {
    "olist_customers_dataset.csv": {
        "table": "CUSTOMERS",
        "key": ["customer_id"],
        "columns": [
            "customer_id", "customer_unique_id", "customer_zip_code_prefix",
            "customer_city", "customer_state",
        ],
    },
    "olist_orders_dataset.csv": {
        "table": "ORDERS",
        "key": ["order_id"],
        "columns": [
            "order_id", "customer_id", "order_status", "order_purchase_timestamp",
            "order_approved_at", "order_delivered_carrier_date",
            "order_delivered_customer_date", "order_estimated_delivery_date",
        ],
    },
    "olist_order_items_dataset.csv": {
        "table": "ORDER_ITEMS",
        "key": ["order_id", "order_item_id"],
        "columns": [
            "order_id", "order_item_id", "product_id", "seller_id",
            "shipping_limit_date", "price", "freight_value",
        ],
    },
    "olist_order_payments_dataset.csv": {
        "table": "ORDER_PAYMENTS",
        "key": ["order_id", "payment_sequential"],
        "columns": [
            "order_id", "payment_sequential", "payment_type",
            "payment_installments", "payment_value",
        ],
    },
    "olist_order_reviews_dataset.csv": {
        "table": "ORDER_REVIEWS",
        "key": ["review_id", "order_id"],
        "columns": [
            "review_id", "order_id", "review_score", "review_comment_title",
            "review_comment_message", "review_creation_date", "review_answer_timestamp",
        ],
    },
    "olist_products_dataset.csv": {
        "table": "PRODUCTS",
        "key": ["product_id"],
        # NB: "lenght" is misspelled in the source file. We keep it as-is in RAW.
        "columns": [
            "product_id", "product_category_name", "product_name_lenght",
            "product_description_lenght", "product_photos_qty", "product_weight_g",
            "product_length_cm", "product_height_cm", "product_width_cm",
        ],
    },
    "olist_sellers_dataset.csv": {
        "table": "SELLERS",
        "key": ["seller_id"],
        "columns": ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"],
    },
    "olist_geolocation_dataset.csv": {
        "table": "GEOLOCATION",
        "key": None,  # many rows per zip prefix — no unique key
        "columns": [
            "geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng",
            "geolocation_city", "geolocation_state",
        ],
    },
    "product_category_name_translation.csv": {
        "table": "PRODUCT_CATEGORY_TRANSLATION",
        "key": ["product_category_name"],
        "columns": ["product_category_name", "product_category_name_english"],
    },
}


def read_csv(path: Path) -> pd.DataFrame:
    # dtype=str keeps values exactly as written (e.g. zip prefixes keep leading zeros).
    # Only truly empty fields count as null — the same rule as our Snowflake file format.
    # utf-8-sig strips a byte-order mark from the header if one is present.
    return pd.read_csv(
        path, dtype=str, keep_default_na=False, na_values=[""], encoding="utf-8-sig"
    )


def profile_file(file_name: str, spec: dict, df: pd.DataFrame) -> tuple[list[str], bool]:
    lines = [f"## `{file_name}` → `RAW.{spec['table']}`", ""]
    actual_cols = list(df.columns)
    columns_ok = actual_cols == spec["columns"]

    lines.append(f"- **Rows:** {len(df):,}")
    lines.append(f"- **Columns:** {len(actual_cols)} (expected {len(spec['columns'])})")
    if columns_ok:
        lines.append("- **Column check:** ✅ names and order match the Snowflake table")
    else:
        missing = [c for c in spec["columns"] if c not in actual_cols]
        extra = [c for c in actual_cols if c not in spec["columns"]]
        lines.append("- **Column check:** ❌ MISMATCH")
        lines.append(f"  - missing: {missing or 'none'}")
        lines.append(f"  - unexpected: {extra or 'none'}")
        if not missing and not extra:
            lines.append(f"  - same columns, different order: {actual_cols}")

    key = spec["key"]
    if key and all(k in df.columns for k in key):
        dupes = int(df.duplicated(subset=key).sum())
        mark = "✅" if dupes == 0 else "⚠️"
        lines.append(f"- **Duplicate keys on ({', '.join(key)}):** {mark} {dupes:,}")
        if file_name == "olist_order_reviews_dataset.csv":
            review_id_dupes = int(df.duplicated(subset=["review_id"]).sum())
            lines.append(f"- **Duplicate `review_id` alone (known quirk):** {review_id_dupes:,}")
    else:
        lines.append("- **Key:** none expected (not unique by design)")
    lines.append(f"- **Fully duplicated rows:** {int(df.duplicated().sum()):,}")

    lines += ["", "| Column | Nulls | Null % | Distinct | Example |", "|---|---:|---:|---:|---|"]
    for col in actual_cols:
        series = df[col]
        nulls = int(series.isna().sum())
        pct = 100 * nulls / len(df) if len(df) else 0
        example = series.dropna().iloc[0] if series.notna().any() else ""
        example = str(example).replace("|", "/").replace("\n", " ")[:40]
        lines.append(f"| `{col}` | {nulls:,} | {pct:.2f}% | {series.nunique():,} | {example} |")
    lines.append("")
    return lines, columns_ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--data-dir", default=PROJECT_ROOT / "data" / "raw", type=Path)
    parser.add_argument("--report", default=PROJECT_ROOT / "docs" / "dataset_profile.md", type=Path)
    args = parser.parse_args()

    report = ["# Dataset Profile (generated)", "",
              "Generated by `python/inspect_dataset.py`. Re-run it after re-downloading the data.", ""]
    summary = ["| File | Rows | Columns OK |", "|---|---:|:---:|"]
    all_ok = True

    for file_name, spec in EXPECTED.items():
        path = args.data_dir / file_name
        if not path.exists():
            print(f"❌ MISSING  {file_name}")
            summary.append(f"| `{file_name}` | — | ❌ missing |")
            all_ok = False
            continue

        df = read_csv(path)
        lines, columns_ok = profile_file(file_name, spec, df)
        report += lines
        summary.append(f"| `{file_name}` | {len(df):,} | {'✅' if columns_ok else '❌'} |")
        all_ok &= columns_ok
        print(f"{'✅' if columns_ok else '❌'} {file_name:<42} {len(df):>10,} rows  {df.shape[1]} cols")

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text("\n".join(report[:4] + ["## Summary", ""] + summary + [""] + report[4:]))
    print(f"\nReport written to {args.report.relative_to(PROJECT_ROOT) if args.report.is_relative_to(PROJECT_ROOT) else args.report}")

    if not all_ok:
        print("\n❌ Fix the problems above before loading into Snowflake.")
        return 1
    print("\n✅ All files present and all columns match. Copy the row counts above into "
          "snowflake/04_validation/05_row_count_validation.sql if they differ from the defaults.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
