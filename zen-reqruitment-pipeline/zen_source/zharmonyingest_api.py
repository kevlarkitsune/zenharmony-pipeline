# ZHARMONY INGESTION 2/2: INGESTION OF LIVE API DATA (POPULATE zen_bronze.raw_current)

import os
import requests
import pandas as pd
from datetime import datetime, timezone
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# ZENHARMONY ENVIRONMENT LOAD
ENV_PATH = ".env.zenharmony"
if not os.path.exists(ENV_PATH):
    raise FileNotFoundError(f"Missing {ENV_PATH} in project root")
load_dotenv(ENV_PATH)

PG_USER = os.getenv("PG_USER")
PG_PASSWORD = os.getenv("PG_PASSWORD")
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DB = os.getenv("PG_DB")

ENGINE_URL = f"postgresql+pg8000://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"
API_URL = "https://api.greenhouse.io/v1/boards/offerzen/jobs?content=true"


def main():
    # 1. FETCH DATA FROM GREENHOUSE API
    r = requests.get(API_URL, timeout=30)
    r.raise_for_status()
    jobs = r.json().get("jobs", [])
    if not jobs:
        print("No current jobs found.")
        return

    # 2. FLATTON JSON INTO REQUIRED DATAFRAME
    rows = []
    for j in jobs:
        dept = None
        if isinstance(j.get("departments"), list) and j["departments"]:
            first = j["departments"][0]
            dept = first.get("name") if isinstance(first, dict) else str(first)
        elif isinstance(j.get("departments"), str):
            dept = j["departments"]

        loc = None
        if isinstance(j.get("offices"), list) and j["offices"]:
            first = j["offices"][0]
            if isinstance(first, dict):
                locinfo = first.get("location")
                if isinstance(locinfo, dict):
                    loc = locinfo.get("name")
                elif isinstance(locinfo, str):
                    loc = locinfo
            else:
                loc = str(first)
        elif isinstance(j.get("offices"), str):
            loc = j["offices"]

        rows.append({
            "job_id": j.get("id"),
            "internal_job_id": j.get("internal_job_id"),
            "absolute_url": j.get("absolute_url"),
            "title": j.get("title"),
            "department": dept,
            "location": loc,
            "company_name": "OfferZen",
            "open_date": j.get("updated_at"),
            "close_date": None
        })

    df = pd.DataFrame(rows).fillna("")

    # 3. NORMALIZE DATA TYPES (TO MATCH THE CSV INGEST)
    for c in ("open_date", "close_date"):
        if c in df.columns:
            df[c] = pd.to_datetime(df[c], errors="coerce").dt.date

    for col in ("job_id", "internal_job_id"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

    # 4. CONNECT TO TABLES AND ENSURE THEY EXIST
    engine = create_engine(ENGINE_URL, future=True)
    ddl = """
    CREATE SCHEMA IF NOT EXISTS zen_bronze;
    CREATE TABLE IF NOT EXISTS zen_bronze.raw_current (
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
        conn.execute(text("TRUNCATE zen_bronze.raw_current"))

    # 5. LOAD DATA INTO DATABASE
    df.to_sql(
        "raw_current",
        con=engine,
        schema="zen_bronze",
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000,
    )

    print(f"Loaded {len(df)} rows into zen_bronze.raw_current")


if __name__ == "__main__":
    main()
