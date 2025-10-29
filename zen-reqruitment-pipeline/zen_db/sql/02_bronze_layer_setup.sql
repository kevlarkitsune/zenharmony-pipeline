--ZHARMONY PHASE 2: CREATE BRONZE LAYER LANDING TABLES FOR CSV AND API
--=====================================================================

--CHECK SCHEMA EXIST
CREATE SCHEMA IF NOT EXISTS zen_bronze;

--HISTORICAL CSV LANDING
CREATE TABLE IF NOT EXISTS zen_bronze.raw_history
(
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

--LATEST GREENHOUSE API DATA LANDING
CREATE TABLE IF NOT EXISTS zen_bronze.raw_current
(
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

--INDEXING
CREATE INDEX IF NOT EXISTS ix_jobs_history_open_date  ON zen_bronze.raw_history (open_date);
CREATE INDEX IF NOT EXISTS ix_jobs_history_close_date ON zen_bronze.raw_history (close_date);
CREATE INDEX IF NOT EXISTS ix_jobs_latest_job_id      ON zen_bronze.raw_current (job_id);
CREATE INDEX IF NOT EXISTS ix_jobs_latest_open_date   ON zen_bronze.raw_current (open_date);

--END OF BRONZE LAYER SETUP
