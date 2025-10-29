# ZenHarmony Technical Solution

## 1. Overview
ZenHarmony is an end-to-end data engineering solution designed to automate the ingestion, transformation, and orchestration of OfferZen job data from both historical (CSV) and live (API) sources.  

It applies the Medallion Architecture (Bronze, Silver, Gold) to ensure clear data lineage, modular transformation, and consistent analytical output.

All of this is managed through a single Python orchestration script (zharmony_automation).

---

## 2. Architecture Summary

| Layer | Purpose | Schema | Objects |
|:------|:---------|:--------|:-------------|
| Bronze | Raw data ingestion | `zen_bronze` | `raw_history`, `raw_current` |
| Silver | Data cleaning, normalization, and quality checks | `zen_silver` | `datacombined_clean`, `jobview_dq_anomalies` |
| Gold | Analytical & reporting layer (ready for BI tools) | `zen_gold` | `jobview_current_open`, `jobview_filling_time`, `jobview_openings_monthly`, `jobview_overview` |

Bronze = preserves
Silver = clarifies
Gold = communicates

---

## 3. Data Modeling Approach

- Bronze: Stores raw data exactly as received, no transformations.  
- Silver: Cleans column values, normalizes data, fixes date logic, and performs deduplication.  
- Gold: Aggregates data into analytical summaries following a star schema pattern (fact = job listings [datacombined_clean], dimensions = department, location, month).  

All transformations are implemented using PostgreSQL views, ensuring data is always fresh and pipeline runs remain idempotent.

---

## 4. Orchestration Workflow

**`zharmony_automation.py`** is the control script that performs all major actions automatically:

1. Checks dependencies: Installs missing Python packages.  
2. Initializes schemas: Creates all DB layers and objects from SQL scripts.  
3. Ingests data: Runs both CSV and API ingestion scripts.  
4. Validates results: Prints progress and record counts in real time.  

Because each step uses “create if not exists” logic and truncates before inserts, the pipeline is safe to rerun indefinitely/indempotently.

---

## 5. Technology Choices & Design Decisions

| Component | Choice | Reason |
|:-----------|:--------|:--------|
| Database | PostgreSQL (Dockerized) | Lightweight, ideal for analytical SQL views and smaller data sets |
| Language | Python | Versatile and readable for ETL and orchestration |
| ORMEngine | SQLAlchemy, pg8000 | Safe parameterized DB connection handling |
| Environment Management** | dotenv | Secure separation of credentials |
| Containerization** | Docker | Fully reproducible, independant of platform |
| IDE & Query Tools** | VS Code,  DBeaver | Simple development and validation environment |

---

## 6. Using Views Instead of Tables

- Keeps transformations live and transparent.  
- Reduces duplication and dependency on ETL jobs.  
- Maintains a clean lineage, any upstream correction instantly reflects downstream.  
- Makes the entire pipeline idempotent, i.e. you can rerun without any side effects.

> Tables = history. 
> Views = truth.

---

## 7. Error Handling & Data Quality Strategy

- All ingestion and orchestration scripts include `try/except` blocks with clear exit codes.  
- The automation script stops on any non-zero return value to prevent partial/incorrect loads.  
- Silver layer introduces `jobview_dq_anomalies`, flagging missing IDs, dates, and logical inconsistencies (for example, close date before open date).  
- Null or blank values are surfaced, not hidden, preserving data truth for audit and QA visibility.

---

## 8. Trade-offs & Alternatives

| Decision | Adopted | Trade-off |
|:----------|:--------|:-----------|
| Tables vs Views | Views | Non materialized (better for smaller datasets) |
| DBT vs Direct SQL | Direct SQL | Less modular, but faster setup and no external tooling |
| Airflow vs Python Script | Python Script | Simpler, self-contained orchestration |
| Data Quality Fixes | Anomaly View | Exposes errors instead of overwriting them (better data governance/quality) |

---

## 9. Potential for Future Enhancements

- Migrate transformations to DBT for lineage tracking and modular reusability in case of larger data sets.  
- Integrate visualization tools like Power BI for Gold-layer dashboards.  
- Implement scheduling or refreshes.  
- Add unit tests (pytest) for ingestion and validation logic.  
- Introduce data versioning for historical auditability.
- Implement Materialized Views for larger data sets.
- Implement a QA Sandbox Environment.

---

## 10. Conclusion

ZenHarmony achieves a fully operational data pipeline architecture.  I enjoyed this exercise so much, thank you!

## Author
**kevlarkitsune**  
*Create Harmony, Orchestrate Symphony.*
