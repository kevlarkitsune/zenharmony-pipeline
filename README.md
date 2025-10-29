# **ZenHarmony Data Pipeline**
ZenHarmony is an automated, end-to-end ETL pipeline that utilizing practical data engineering, analytics modeling, ingestion and orchestration pipelines.  This stack is built entirely with Python, PostgreSQL, and SQLAlchemy.

---

## **Project Structure**

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
│ ├── zen_orchestration/
│ │ └── zharmony_automation.py
│ │
│ └── zen_source/
│ ├── zharmonyingest_csv.py
│ └── zharmonyingest_api.py
│
├── .env.example (update name to .env.zenharmony)
├── .gitignore
├── README.md
├── requirements.txt
└── SOLUTION.md
```

---

## **Project Overview**

ZenHarmony enables a fully automated data pipeline that:
1. Installs all required Python dependencies automatically.
2. Creates PostgreSQL database schemas (**Bronze**, **Silver**, **Gold**) if not present.
3. Ingests both raw CSV and live API data into the Bronze layer.
4. Cleans and normalizes data through Silver-layer transformations.
5. Aggregates and enriches data in Gold-layer analytical views.
6. Runs the full ETL and orchestration pipeline with a single Python command.
7. Tracks and exposes data quality anomalies for transparency.

**Core Features**
- Modern layered ETL architecture (Bronze / Silver / Gold)
- Idempotent automation (safe to rerun anytime)
- Automated dependency and schema management
- Clear separation between ingestion, transformation, and presentation

---

## **PostgreSQL Setup (via Docker)**

To replicate the project locally with Dockerized PostgreSQL:

### **Create PostgreSQL Container**

Run this command from your project root in PowerShell or terminal:

```bash
docker run -d --name zen-postgres -e POSTGRES_USER=zenuser -e POSTGRES_PASSWORD=zenpassword -e POSTGRES_DB=zenharmony_BI -p 5432:5432 postgres:16
```

Once the container is running, create your environment file:

1. Rename `.env.example` to `.env.zenharmony`
2. Update the values:

   ```bash
   PG_HOST=localhost
   PG_PORT=5432
   PG_DB=zenharmony_BI
   PG_USER=zenuser
   PG_PASSWORD=zenpassword
   ```

To verify your container is active:
```bash
docker ps
```

To stop or remove the container:
```bash
docker stop zen-postgres
docker rm zen-postgres
```

---

## **How to Run the Pipeline**

### **1. Create & Activate the Virtual Environment**

If `.venv` doesn’t exist, create one:
```bash
python -m venv .venv
```

Activate it:
```bash
.\.venv\Scripts\Activate
```

If PowerShell blocks activation, run the below, followed by rerunning the activation script above:
```bash
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

### **2. Install Dependencies (Optional)**

You can run this manually, but the orchestration tool will install missing packages automatically:

```bash
pip install -r requirements.txt
```

---

### **3. Run Full ZenHarmony Orchestration**
From the project root:
```bash
python .\zen-reqruitment-pipeline\zen_orchestration\zharmony_automation.py
```

This script:
- Installs dependencies (if needed)
- Builds the PostgreSQL schemas
- Applies all SQL scripts in order
- Ingests CSV and API data
- Confirms successful orchestration in console logs

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

## **Validation Checks**

Once orchestration completes, open DBeaver or psql and verify:

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

## **Technologies Used**

| Layer | Technology | Purpose |
|-------|-------------|----------|
| Ingestion | Python (Pandas, SQLAlchemy, pg8000) | CSV + API ingestion |
| Transformation | PostgreSQL Views | Cleaning, normalization, DQ checks |
| Orchestration | Python Automation | Schema + pipeline execution |
| Environment | Docker | Local PostgreSQL instance |

---

## **Troubleshooting**

| Error | Probable Cause | Fix |
|----------|---------------|-----|
| `cannot connect to database` | Docker not running | `docker start zen-postgres` |
| `permission denied for schema` | Wrong credentials | Check `.env.zenharmony` |
| `ModuleNotFoundError` | Missing dependency | `pip install -r requirements.txt` |
| PowerShell activation blocked | Policy restriction | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |

---

## **Replicating This Project**

1. Clone the repository  
   ```bash
   git clone https://github.com/kevlarkitsune/zenharmony-pipeline.git
   cd zenharmony-pipeline
   ```

2. Start PostgreSQL (Docker)
   ```bash
   docker run -d --name zen-postgres -e POSTGRES_USER=zenuser -e POSTGRES_PASSWORD=zenpassword -e POSTGRES_DB=zenharmony_BI -p 5432:5432 postgres:16
   ```

3. Activate Virtual Environment  
   ```bash
   .\.venv\Scripts\Activate
   ```

4. Run Orchestration Tool  
   ```bash
   python .\zen-reqruitment-pipeline\zen_orchestration\zharmony_automation.py
   ```

5. Validate the data in DBeaver or psql

---

## Author
**kevlarkitsune**  
*Create Harmony, Orchestrate Symphony.*
