# READ.md - Recruitment Data Pipeline: OfferZen Job Board Analytics
ZenHarmony is an automated, end-to-end ETL pipeline that demonstrates practical data engineering, analytics modeling, ingestion and orchestration pipelines.  This stack is built entirely with Python, PostgreSQL, and SQLAlchemy.

---

## Project Overview
ZenHarmony allows for a modular data pipeline that:
1. **Installs** all required packages if non existant.
2. **Creates** all required database schemas (Bronze Layer, Silver Layer, Gold Layer) if non existant.  
3. **Ingests** raw CSV and API data into the Bronze layer.  
4. **Transforms** and **cleans** data through Silver normalization logic.  
5. **Aggregates** into Gold-layer analytics views.  
6. **Runs end-to-end orchestration** using a single Python command.
7. **Logs** and **tracks** source data quality anomalies for resolution.

ZenHarmony Utilizes:
- Modern layered architecture (Bronze/Silver/Gold)
- Data quality checks and normalization
- Idempotent orchestration (safe to rerun)
- Python + SQLAlchemy integration with PostgreSQL
- Full automation via one script

---

## PostgreSQL Setup (via Docker)

Create PostgreSQL Container (If not installed locally):

```bash
docker run -d --name zen-postgres -e POSTGRES_USER=zenuser -e POSTGRES_PASSWORD=zenpassword -e POSTGRES_DB=zenharmony_BI -p 5432:5432 postgres:16
```

Once the container is running:

0. Duplicate `.env.example` → rename it to `.env.zenharmony`

1. Ensure the connection details, example:
  
   ```
   PG_HOST=localhost
   PG_PORT=5432
   PG_DB=zenharmony_BI
   PG_USER=zenuser
   PG_PASSWORD=zenpassword
   ```
2. Proceed with the orchestration steps below.

[Note] To stop or clean up the container:
```bash
docker stop zenharmony_db
docker rm zenharmony_db
```

---

## Project Structure

```
ZENHARMONY_PROJECT/
│
├── .venv
│
├── zen-reqruitment-pipeline/
│ │
│ ├── zen_data/
│ │ └── raw/
│ │ └── offerzen_jobs_history_raw.csv
│ │
│ ├── zen_db/
│ │ └── sql/
│ │ ├── 01_schema_setup.sql
│ │ ├── 02_bronze_layer_setup.sql
│ │ ├── 03_silver_layer_setup.sql
│ │ └── 04_gold_layer_setup.sql
│ │
│ ├── zen_dbt/
│ │
│ ├── zen_orchestration/
│ │ └── zharmony_automation.py
│ │
│ └── zen_source/
│ ├── zharmonyingest_csv.py
│ └── zharmonyingest_api.py
│
├── .env.zenharmony
├── README.md
├── requirements.txt
└── SOLUTION.md
```
---

## How to Run the Pipeline

### 1. Create (If Not Exists) & Activate Virtual Environment

If .venv does not exist in the project, create it with:
```bash
python -m venv .venv
```
Before running the orchestration, activate the virtual environment with:
```bash
.\.venv\Scripts\Activate
```
⚠️ If receiving a policy warning when running the activation script above on VSCode PowerShell, run the following command and retry running the activate command:
```bash
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 2. Install Dependencies (Optional, the Orchestration Tool will do this Automatically)
```bash
pip install -r requirements.txt
```

> ⚠️ The orchestration script will auto-check and install these if missing.

---

### 3. Run Full Orchestration Automation Tool (ZenHarmony)
From the project root:
```bash
python .\zen-reqruitment-pipeline\zen_orchestration\zharmony_automation.py
```

This script will:
- Verify package dependencies  
- Build all schemas (Bronze, Silver, Gold)  
- Apply all SQL transformations  
- Ingest the CSV and API data  
- Confirm successful orchestration

You’ll see console logs like:
```
[2025-10-29 03:54:44] Starting ZenHarmony Orchestration ...
[2025-10-29 03:54:45] ZenHarmony Packages Initialized: Installation Not Required ...
[2025-10-29 03:54:45] Running ZenHarmony DB Setup Scripts ...
[2025-10-29 03:54:45] Applying SQL: 01_schema_setup.sql Successful.
[2025-10-29 03:54:45] Applying SQL: 02_bronze_layer_setup.sql Successful.
[2025-10-29 03:54:45] Applying SQL: 03_silver_layer_setup.sql Successful.
[2025-10-29 03:54:45] Applying SQL: 04_gold_layer_setup.sql Successful.
[2025-10-29 03:54:45] ZenHarmony Database Structure Successfully Initialized.

$ python "C:\Users\kevin\Desktop\ZenHarmony_Project\zen-reqruitment-pipeline\zen_source\zharmonyingest_csv.py"
Loaded 316 rows into zen_bronze.raw_history

$ python "C:\Users\kevin\Desktop\ZenHarmony_Project\zen-reqruitment-pipeline\zen_source\zharmonyingest_api.py"
Loaded 6 rows into zen_bronze.raw_current
[2025-10-29 03:54:49] ZenHarmony Environment Orchestration Successful.
```

---

## Validation Checks

Once orchestration completes, open DBeaver or psql and run:

```sql
--1.1 Confirm Bronze has data (Sanity Check)
SELECT COUNT(*) FROM zen_bronze.raw_history;
SELECT COUNT(*) FROM zen_bronze.raw_current;
--1.2 Full Samples
SELECT * FROM zen_bronze.raw_history;
SELECT * FROM zen_bronze.raw_current;

--2.1 Confirm Silver layer cleaned data (Sanity Check)
SELECT COUNT(*) FROM zen_silver.datacombined_clean;
--2.2 Full Samples
SELECT * FROM zen_silver.datacombined_clean;

--3.1 Confirm Gold analytical outputs (Sanity Check)
SELECT COUNT(*) FROM zen_gold.jobview_current_open;
SELECT COUNT(*) FROM zen_gold.jobview_filling_time;
SELECT COUNT(*) FROM zen_gold.jobview_openings_monthly;
SELECT COUNT(*) FROM zen_gold.jobview_overview;
--3.2 Confirm Gold analytical outputs (Sanity Check)
SELECT * FROM zen_gold.jobview_current_open;
SELECT * FROM zen_gold.jobview_filling_time;
SELECT * FROM zen_gold.jobview_openings_monthly;
SELECT * FROM zen_gold.jobview_overview;

--4.1 Confirm Data Quality Checks (Sanity Check)
SELECT COUNT(*) FROM zen_silver.jobview_dq_anomalies;
--4.2 View All Data Quality Anomalies (Missing Source Data)
SELECT * FROM zen_silver.jobview_dq_anomalies;
```

All tables and views should return data with no errors.

---

## Technologies Used
| Layer | Technology | Purpose |
|-------|-------------|----------|
| Ingestion | Python (Pandas, SQLAlchemy, pg8000) | Raw CSV + API ingestion |
| Transformation | PostgreSQL (SQL Views) | Cleaning, normalization, Quality Checks |
| Orchestration | Python Automation | Schema creation + pipeline execution |
| Environment | Docker (optional) | Reproducible local PostgreSQL environment |

---

## Troubleshooting
| Symptom | Likely Cause | Fix |
|----------|---------------|-----|
| `cannot connect to database` | Docker container not running | `docker start zenharmony_db` |
| `permission denied for schema` | wrong user/password | Check `.env.zenharmony` credentials |
| `ModuleNotFoundError` | missing packages | run `pip install -r requirements.txt` |
| `cannot run .\.venv\Scripts\Activate` | MS local machine policy issue | run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |

---

## Output Example
| job_id | title | department | location | company_name | open_date | close_date |
|--------|--------|-------------|-----------|---------------|------------|-------------|
| 6351072002 | Content Marketing Manager | Marketing | Cape Town | OfferZen | 2025-10-08 | NULL |

## Replicating my Exact Steps:

1. Open ZenHarmony_Project Folder in VS Code.
2. Open Docker. 
3. Open Powershell Terminal in VS Code, ensure you are in the ZenHarmony_Project root directory.
4. Create your Postgres DB container for Docker in your terminal:
   ```bash
   docker run -d --name zen-postgres -e POSTGRES_USER=zenuser -e POSTGRES_PASSWORD=zenpassword -e POSTGRES_DB=zenharmony_BI -p 5432:5432 postgres:16
   ```
5. Activate your virtual environment in your terminal (See Troubleshooting if you run into an error): 
   ```bash
   First Run:
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   
   Then Run:
   .\.venv\Scripts\Activate 
   ```
6. Run your Orchestration Tool:
   ```bash
   python .\zen-reqruitment-pipeline\zen_source\zharmony_automation.py
   ```
8.  Perform your data validation checks in DBeaver or psql.

---

## Author
**kevlarcode**  
*Create Harmony, Orchestrate Symphony.*
