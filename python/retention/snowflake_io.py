"""
Read from and write to Snowflake using the key-pair login set up in Sprint 2.
Connection details come from the git-ignored .env file (see .env.example).
"""

import os

import pandas as pd
import snowflake.connector
from cryptography.hazmat.primitives import serialization
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

from .config import PROJECT_ROOT


def connect():
    load_dotenv(PROJECT_ROOT / ".env")
    key_path = os.path.expanduser(os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"])
    with open(key_path, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=private_key.private_bytes(
            serialization.Encoding.DER,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        ),
        role=os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "CRI_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "CRI_DB"),
    )


def read_sql(conn, sql: str) -> pd.DataFrame:
    """Run a query and return a DataFrame with lower-case column names."""
    df = conn.cursor().execute(sql).fetch_pandas_all()
    df.columns = df.columns.str.lower()
    return df


def write_table(conn, df: pd.DataFrame, table: str, schema: str) -> int:
    """Replace CRI_DB.<schema>.<table> with the DataFrame. Returns rows written."""
    conn.cursor().execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
    out = df.copy()
    out.columns = [c.upper() for c in out.columns]
    # Store datetime columns as plain dates so they land in Snowflake as DATE.
    for col in out.columns:
        if pd.api.types.is_datetime64_any_dtype(out[col]):
            out[col] = out[col].dt.date
    success, _, n_rows, _ = write_pandas(
        conn, out, table_name=table.upper(), schema=schema.upper(),
        auto_create_table=True, overwrite=True, quote_identifiers=False,
    )
    if not success:
        raise RuntimeError(f"Writing {schema}.{table} failed")
    return n_rows
