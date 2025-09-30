import pandas as pd
from sqlalchemy import create_engine
import os

# Get database connection from environment variable (same style as before)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://andreasrafailandrikopoulos@localhost:5432/cosmofone"
)

# Output folder
OUTPUT_DIR = "./exports"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Connect to Postgres
engine = create_engine(DATABASE_URL)

# Views to export
views = [
    "customer_summary",
    "monthly_kpis",
    "churn_risk_indicators"
]

for view in views:
    query = f"SELECT * FROM cosmofone.{view};"
    df = pd.read_sql(query, engine)
    out_path = f"{OUTPUT_DIR}/{view}.csv"
    df.to_csv(out_path, index=False)
    print(f"[ok] exported {view} -> {out_path}")