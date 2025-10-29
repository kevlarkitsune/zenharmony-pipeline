--ZHARMONY PHASE 4: BUILD ANALYTICS READY ZEN_GOLD LAYER
--======================================================

CREATE SCHEMA IF NOT EXISTS zen_gold;

--1. JOB SUMMARY OVERVIEW
CREATE OR REPLACE VIEW zen_gold.jobview_overview    AS
SELECT
    COALESCE(department, 'Unknown Department')         AS department,
    COALESCE(location,   'Unknown Location')           AS location,
    COUNT(*)                                           AS total_roles,
    COUNT(CASE WHEN close_date IS NULL THEN 1 END)     AS currently_open,
    COUNT(CASE WHEN close_date IS NOT NULL THEN 1 END) AS closed_roles

FROM zen_silver.datacombined_clean
GROUP BY 1, 2
ORDER BY department, location;

--2. MONTHLY ACTIVITY SUMMARY, NULL SAFE ON OPEN DATE
CREATE OR REPLACE VIEW zen_gold.jobview_openings_monthly     AS
WITH src AS 
(
  SELECT
    COALESCE
    (
      dc.open_date,
      MIN(dc.open_date) OVER (PARTITION BY dc.job_id),
      CURRENT_DATE
    ) AS open_date_filled,
    dc.close_date,
    dc.job_id

  FROM zen_silver.datacombined_clean dc
)

SELECT
    DATE_TRUNC('month', open_date_filled)::date                       AS month_start,
    COUNT(DISTINCT job_id)                                            AS roles_opened,
    COUNT(DISTINCT CASE WHEN close_date IS NOT NULL THEN job_id END)  AS roles_closed

FROM src
GROUP BY 1
ORDER BY month_start DESC;

--3. TIME TO FILL JOBS (AVG DAYS)
CREATE OR REPLACE VIEW zen_gold.jobview_filling_time AS
SELECT
    COALESCE(department, 'Unknown Department')          AS department,
    ROUND(AVG((close_date - open_date)))::int           AS avg_days_to_fill,
    COUNT(*)                                            AS roles_closed

FROM zen_silver.datacombined_clean
WHERE close_date IS NOT NULL AND open_date IS NOT NULL
GROUP BY 1
ORDER BY avg_days_to_fill;

--4. OPEN ROLES DETAIL, MAKING USE OF FILLED OPEN DATE SO IT'S NEVER NULL
CREATE OR REPLACE VIEW zen_gold.jobview_current_open   AS
WITH src AS 
(
  SELECT
    dc.*,
    COALESCE
    (
      dc.open_date,
      MIN(dc.open_date) OVER (PARTITION BY dc.job_id),
      CURRENT_DATE
    ) AS open_date_filled

  FROM zen_silver.datacombined_clean dc
  WHERE dc.close_date IS NULL
)
SELECT
    job_id,
    COALESCE(title,      'Untitled Role')      AS title,
    COALESCE(department, 'Unknown Department') AS department,
    COALESCE(location,   'Unknown Location')   AS location,
    company_name,
    open_date_filled                           AS open_date

FROM src
ORDER BY open_date_filled DESC;


--END OF GOLD LAYER SETUP======================================
