# ZHARMONY INGESTION 1/2: INGESTION OF RAW CSV DATA (Population of zen_bronze.raw_history)

# IMPORT PACKAGES
import os
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# LOAD ZENHARMONY ENVIRONMENT
ENV_PATH = ".env.zenharmony"
if not os.path.exists(ENV_PATH):
    raise FileNotFoundError(f"Missing {ENV_PATH} in project root")
load_dotenv(ENV_PATH)

# ZENHARMONY ENVIRONMENT CONFIG
PG_USER = os.getenv("PG_USER")
PG_PASSWORD = os.getenv("PG_PASSWORD")
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DB = os.getenv("PG_DB")

CSV_PATH = "zen-reqruitment-pipeline/zen_data/raw/offerzen_jobs_history_raw.csv"
ENGINE_URL = f"postgresql+pg8000://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"

def main():
    # 1. READ CSV AS STRINGS AND COERCE DATES
    df = pd.read_csv(CSV_PATH, dtype=str).fillna("")
    for c in ("open_date", "close_date"):
        if c in df.columns:
            df[c] = pd.to_datetime(df[c], errors="coerce").dt.date

    # 2. AVOID ERRORS WHEN INSERTING POTENTIAL LARGE NUMBERS AS IDS, CHANGE '' TO NULL
    for col in ("job_id", "internal_job_id"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

    # 3. CONNECT TABLE, ALLOW FOR MULTIPLE RERUNS WITHOUT ERROR/DUPLICATION
    engine = create_engine(ENGINE_URL, future=True)
    ddl = """
    CREATE SCHEMA IF NOT EXISTS zen_bronze;
    CREATE TABLE IF NOT EXISTS zen_bronze.raw_history (
      job_id           BIGINT,
      internal_job_id  BIGINT,
      absolute_url     TEXT,
      title            TEXT,
      department       TEXT,
      location         TEXT,
      company_name     TEXT,
      open_date        DATE,
      close_date       DATE
    );
    """
    with engine.begin() as conn:
        conn.execute(text(ddl))
        conn.execute(text("TRUNCATE zen_bronze.raw_history"))

    # 4. LOAD DATA TO TABLE
    df.to_sql(
        "raw_history",
        con=engine,
        schema="zen_bronze",
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000,
    )
    print(f"Loaded {len(df)} rows into zen_bronze.raw_history")

if __name__ == "__main__":
    main()
