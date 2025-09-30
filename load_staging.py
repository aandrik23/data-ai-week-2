import os
from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+psycopg2://postgres:postgres@localhost:5432/cosmofone")
INPUT_DIR = Path("./cleaned")
SCHEMA = "cosmofone"

FILES = {
    "stg_customers": INPUT_DIR / "customers_cleaned.csv",
    "stg_billing" : INPUT_DIR / "billing_cleaned.csv",
    "stg_usage"  : INPUT_DIR / "usage_cleaned.csv",
    "stg_support_tickets" : INPUT_DIR / "support_tickets_cleaned.csv",
}

engine = create_engine(DATABASE_URL, future=True)

# Create schema if it doesn't exist and set search path
with engine.begin() as conn:
    conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA};"))
    conn.execute(text(f"SET search_path TO {SCHEMA};"))

for table_name, csv_path in FILES.items():
    if not csv_path.exists():
        print(f"[skip] {csv_path} not found")
        continue
    df = pd.read_csv(csv_path)
    df.to_sql(table_name, engine, schema=SCHEMA, if_exists="replace", index=False)
    print(f"[ok] loaded {csv_path.name} -> {SCHEMA}.{table_name}")