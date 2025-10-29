# ZENHARMONY ENVIRONMENT AUTOMATION

import os, subprocess, sys
from datetime import datetime

# ENVIRONMENT CONFIG

ROOT = os.path.dirname(os.path.dirname(__file__))          
SRC  = os.path.join(ROOT, "zen_source")
DBF  = os.path.join(ROOT, "zen_db", "sql")                 
PRJ  = os.path.dirname(ROOT)                               
ENV  = os.path.join(PRJ, ".env.zenharmony")
REQ  = os.path.join(PRJ, "requirements.txt")

if not os.path.exists(ENV):
    sys.exit(f"Missing env file: {ENV}")

def log(msg: str):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def run(cmd: str):
    print(f"\n$ {cmd}")
    r = subprocess.run(cmd, shell=True)
    if r.returncode != 0:
        sys.exit(r.returncode)

# CHECKS FOR REQUIRED PACKAGES AND INSTALLS IF NOT PRESENT
def ensure_requirements():
    missing = []
    try:
        import pandas  # noqa
    except Exception:
        missing.append("pandas")
    try:
        import sqlalchemy  # noqa
    except Exception:
        missing.append("SQLAlchemy")
    try:
        import pg8000  # noqa
    except Exception:
        missing.append("pg8000")
    try:
        import dotenv  # noqa
    except Exception:
        missing.append("python-dotenv")

    if not missing:
        log("ZenHarmony Packages Initialized: Installation Not Required ...")
        return

    log(f"ZenHarmony Packages missing: {', '.join(missing)}")
    if os.path.exists(REQ):
        log("Installing from requirements.txt ...")
        run(f'python -m pip install -r "{REQ}"')
    else:
        log("... requirements.txt not found: installing minimal ZenHarmony package set ...")
        run("python -m pip install pandas SQLAlchemy pg8000 python-dotenv")
    # IMPORT SANITY CHECK
    import pandas, sqlalchemy, pg8000, dotenv  # noqa

# ZENHARMONY DB CONFIGURATION
def get_engine():
    from dotenv import load_dotenv
    load_dotenv(ENV)

    PG_USER = os.getenv("PG_USER")
    PG_PASSWORD = os.getenv("PG_PASSWORD")
    PG_HOST = os.getenv("PG_HOST", "localhost")
    PG_PORT = os.getenv("PG_PORT", "5432")
    PG_DB = os.getenv("PG_DB")

    if not all([PG_USER, PG_PASSWORD, PG_HOST, PG_PORT, PG_DB]):
        sys.exit("Missing one or more ZenHarmony DB environment variables in .env.zenharmony")

    from sqlalchemy import create_engine
    url = f"postgresql+pg8000://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"
    return create_engine(url, future=True)

def schema_exists(engine, schema_name: str) -> bool:
    from sqlalchemy import text
    sql = """
        SELECT 1
        FROM information_schema.schemata
        WHERE schema_name = :s
        LIMIT 1
    """
    with engine.connect() as conn:
        return bool(conn.execute(text(sql), {"s": schema_name}).scalar())

def run_sql_file(engine, path: str):
    if not os.path.exists(path):
        sys.exit(f"Missing SQL file: {path}")

    from sqlalchemy import text
    with open(path, "r", encoding="utf-8") as f:
        sql_text = f.read()

    statements = [s.strip() for s in sql_text.split(';') if s.strip()]
    if not statements:
        return

    log(f"Applying SQL: {os.path.basename(path)} ...")
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))

def ensure_db_structure():
    engine = get_engine()

    bronze = schema_exists(engine, "zen_bronze")
    silver = schema_exists(engine, "zen_silver")
    gold   = schema_exists(engine, "zen_gold")

    if bronze and silver and gold:
        log("ZenHarmony Schemas Initialized: DB Structure Creation Not Required ...")
        return

    log("Running ZenHarmony DB Setup Scripts ...")

    # RUN ALL FOUR REQUIRED ZENHARMONY ENVIRONMENT SETUP SCRIPTS
    preferred = [
        os.path.join(DBF, "01_schema_setup.sql"),
        os.path.join(DBF, "02_bronze_layer_setup.sql"),
        os.path.join(DBF, "03_silver_layer_setup.sql"),
        os.path.join(DBF, "04_gold_layer_setup.sql"),
    ]

    # IN CASE OF SCRIPTS MOVED TO ROOT FOLDER
    fallback = [
        os.path.join(PRJ, "01_schema_setup.sql"),
        os.path.join(PRJ, "02_bronze_layer_setup.sql"),
        os.path.join(PRJ, "03_silver_layer_setup.sql"),
        os.path.join(PRJ, "04_gold_layer_setup.sql"),
    ]

    for p, alt in zip(preferred, fallback):
        run_sql_file(engine, p if os.path.exists(p) else alt)

    log("ZenHarmony Database Structure Successfully Initialized.")

# DATA INGESTIONS
def run_ingestions():
    run(f'python "{os.path.join(SRC, "zharmonyingest_csv.py")}"')
    run(f'python "{os.path.join(SRC, "zharmonyingest_api.py")}"')

# ZENHARMONY ORCHESTRATION
if __name__ == "__main__":
    log("Starting ZenHarmony Orchestration ...")
    ensure_requirements()
    ensure_db_structure()
    run_ingestions()
    log("ZenHarmony Environment Orchestration Successful.")
