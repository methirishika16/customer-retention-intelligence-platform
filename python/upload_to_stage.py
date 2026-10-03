"""
OPTIONAL — Upload the 9 CSV files from data/raw/ to the Snowflake internal stage
@CRI_DB.RAW.OLIST_STAGE using PUT.

You can skip this script and upload through the Snowsight UI instead
(see README, Sprint 1, step 5). Use it if you want the upload to be repeatable.

Setup:
    cp .env.example .env      # then fill in your account details
    pip install -r requirements.txt
    python python/upload_to_stage.py

PUT gzips each file (olist_customers_dataset.csv -> .csv.gz). That is fine:
the COPY INTO patterns in 04_load_raw_tables.sql match both .csv and .csv.gz.
"""

import os
import sys
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv

from inspect_dataset import EXPECTED

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "raw"
STAGE = "@CRI_DB.RAW.OLIST_STAGE"


def connect():
    load_dotenv(PROJECT_ROOT / ".env")
    params = {
        "account": os.environ["SNOWFLAKE_ACCOUNT"],
        "user": os.environ["SNOWFLAKE_USER"],
        "password": os.environ.get("SNOWFLAKE_PASSWORD"),
        "role": os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "CRI_WH"),
        "database": os.environ.get("SNOWFLAKE_DATABASE", "CRI_DB"),
        "schema": os.environ.get("SNOWFLAKE_SCHEMA", "RAW"),
    }
    if os.environ.get("SNOWFLAKE_AUTHENTICATOR"):
        params["authenticator"] = os.environ["SNOWFLAKE_AUTHENTICATOR"]
    return snowflake.connector.connect(**params)


def main() -> int:
    missing = [f for f in EXPECTED if not (DATA_DIR / f).exists()]
    if missing:
        print(f"❌ Missing files in {DATA_DIR}: {missing}")
        return 1

    with connect() as conn, conn.cursor() as cur:
        for file_name in EXPECTED:
            # Forward slashes + quotes so paths with spaces work on every OS.
            local = (DATA_DIR / file_name).as_posix()
            cur.execute(f"PUT 'file://{local}' {STAGE} AUTO_COMPRESS=TRUE OVERWRITE=TRUE")
            source, target, *_, status, _ = cur.fetchone()
            print(f"{status:<10} {source} -> {target}")

        cur.execute(f"LIST {STAGE}")
        print(f"\n✅ {len(cur.fetchall())} files now in {STAGE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
