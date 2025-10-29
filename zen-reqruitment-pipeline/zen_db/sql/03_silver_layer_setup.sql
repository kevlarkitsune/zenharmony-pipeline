--ZHARMONY PHASE 3: CREATE SILVER LAYER VIEWS, NORMALIZATION AND DATA QUALITY
--===========================================================================

CREATE SCHEMA IF NOT EXISTS zen_silver;

--PRIMARY CLEANED/COMBINED VIEW
CREATE OR REPLACE VIEW zen_silver.datacombined_clean AS
WITH unified AS
(
    SELECT
        CAST(job_id AS BIGINT)                       AS job_id,
        CAST(internal_job_id AS BIGINT)              AS internal_job_id,
        NULLIF(TRIM(absolute_url), '')               AS absolute_url,
        NULLIF(TRIM(title), '')                      AS title,
        NULLIF(TRIM(department), '')                 AS department_raw,
        NULLIF(TRIM(location), '')                   AS location_raw,
        NULLIF(TRIM(company_name), '')               AS company_name,
        open_date,
        close_date

    FROM zen_bronze.raw_history

    UNION ALL

    SELECT
        CAST(job_id AS BIGINT)          AS job_id,
        CAST(internal_job_id AS BIGINT) AS internal_job_id,
        NULLIF(TRIM(absolute_url), '')  AS absolute_url,
        NULLIF(TRIM(title), '')         AS title,
        NULLIF(TRIM(department), '')    AS department_raw,
        NULLIF(TRIM(location), '')      AS location_raw,
        NULLIF(TRIM(company_name), '')  AS company_name,
        open_date,
        close_date

    FROM zen_bronze.raw_current
),
normalized AS 
(
    SELECT
        job_id,
        internal_job_id,
        absolute_url,
        title,

        --1. NORMALIZE DEPARTMENTS
        CASE
            WHEN department_raw ILIKE 'data%'        THEN 'Data'
            WHEN department_raw ILIKE 'engineering%' THEN 'Engineering'
            WHEN department_raw ILIKE 'product%'     THEN 'Product'
            WHEN department_raw ILIKE 'marketing%'   THEN 'Marketing'
            WHEN department_raw ILIKE 'sales%'       THEN 'Sales'
            WHEN department_raw ILIKE 'operations%'  THEN 'Operations'
            ELSE department_raw
        END AS department,

        --2. NORMALIZE LOCATIONS
        CASE
            WHEN location_raw ILIKE '%south africa%' THEN 'South Africa'
            WHEN location_raw ILIKE '%netherlands%'  THEN 'Netherlands'
            ELSE location_raw
        END AS location,

        company_name,

        --3. PREVENT BAD DATE ORDERS
        open_date,
        CASE
            WHEN close_date IS NOT NULL AND open_date IS NOT NULL AND close_date < open_date
                THEN NULL
            ELSE close_date
        END AS close_date_fixed\

    FROM unified

    --FUTURE CHECK: TITLE NORMALIZATION (NOT CURRENTLY NEEDED)
    --FUTURE CHECK: URL NORMALIZATION (NOT CURRENTLY NEEDED)
    --FUTURE CHECK: COMPANY NAME NORMALIZATION (NOT CURRENTLY NEEDED)
    --FUTURE CHECK: ABSOLUTE URL NORMALIZATION (NOT CURRENTLY NEEDED)
    -- -> All accounted for in SELECT COUNT(*) FROM zen_silver.jobview_dq_anomalies;

)

--DE-DUPLICATION
SELECT DISTINCT
    job_id,
    internal_job_id,
    absolute_url,
    title,
    department,
    location,
    company_name,
    open_date,
    close_date_fixed AS close_date

FROM normalized;

--=========================
--BI VIEWS 
--=========================

--1. CURRENT OPEN JOBS, TAKES CARE OF NULLS
CREATE OR REPLACE VIEW zen_silver.jobview_current_open AS
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
)
SELECT
  job_id,
  internal_job_id,
  absolute_url,
  title,
  department,
  location,
  company_name,
  open_date_filled AS open_date,
  close_date

FROM src
WHERE close_date IS NULL OR close_date >= CURRENT_DATE;

--2. TIME TO FILL, ONLY FOR CLOSED ROLES
CREATE OR REPLACE VIEW zen_silver.jobview_filling_time AS
SELECT
    job_id,
    title,
    department,
    location,
    open_date,
    close_date,
    (close_date - open_date) AS days_to_fill

FROM zen_silver.datacombined_clean
WHERE open_date IS NOT NULL
  AND close_date IS NOT NULL
  AND close_date >= open_date;

--3. MONTHLY OPENINGS, USING THE SAME FILLED DATE SO NULLS STILL COUNT
CREATE OR REPLACE VIEW zen_silver.jobview_openings_monthly AS
WITH src AS 
(
  SELECT
    COALESCE
    (
      dc.open_date,
      MIN(dc.open_date) OVER (PARTITION BY dc.job_id),
      CURRENT_DATE
    ) AS open_date_filled,
    dc.department,
    dc.location,
    dc.job_id

  FROM zen_silver.datacombined_clean dc
)
SELECT
  DATE_TRUNC('month', open_date_filled)::date AS month_start,
  department,
  location,
  COUNT(DISTINCT job_id) AS jobs_opened

FROM src
GROUP BY 1, 2, 3;

-- =============================================================================
-- ZENHARMONY SILVER QUALITY CHECKS: SOURCE DATA ANOMALY FLAGS FOR DQ VISIBILITY
-- =============================================================================
CREATE OR REPLACE VIEW zen_silver.jobview_dq_anomalies AS
WITH src AS 
(
    SELECT
        job_id,
        internal_job_id,
        absolute_url,
        title,
        department,
        location,
        company_name,
        open_date,
        close_date,
        --CATER FOR RESOLVABLE MISSING OPEN_DATES
        COALESCE
        (
            open_date,
            MIN(open_date) OVER (PARTITION BY job_id),
            CURRENT_DATE
        ) AS open_date_filled

    FROM zen_silver.datacombined_clean
),
flags AS 
(
    SELECT
        *,
        --MISSING/BLANK CHECKS
        (job_id IS NULL)                                      AS is_missing_job_id,
        (internal_job_id IS NULL)                             AS is_missing_internal_id,
        (absolute_url IS NULL OR TRIM(absolute_url) = '')     AS is_missing_absolute_url,
        (title IS NULL OR TRIM(title) = '')                   AS is_missing_title,
        (department IS NULL OR TRIM(department) = '')         AS is_missing_department,
        (location IS NULL OR TRIM(location) = '')             AS is_missing_location,
        (company_name IS NULL OR TRIM(company_name) = '')     AS is_missing_company_name,

        --DATE CHECKS
        (open_date IS NULL AND close_date IS NULL)            AS is_missing_both_dates,
        (open_date IS NOT NULL AND close_date IS NOT NULL
            AND close_date < open_date)                       AS is_close_before_open,
        (open_date IS NULL AND close_date IS NOT NULL)        AS is_missing_open,

        --SANITY CHECKS
        (job_id IS NOT NULL AND job_id < 0)                   AS is_negative_job_id,
        (internal_job_id IS NOT NULL AND internal_job_id < 0) AS is_negative_internal_id

    FROM src
)
SELECT
    job_id,
    internal_job_id,
    absolute_url,
    title,
    department,
    location,
    company_name,
    open_date,
    close_date,
    open_date_filled,
    --ALLOW FOR INDIVIDUAL FILTERING FLAGS
    is_missing_job_id,
    is_missing_internal_id,
    is_missing_absolute_url,
    is_missing_title,
    is_missing_department,
    is_missing_location,
    is_missing_company_name,
    is_missing_both_dates,
    is_close_before_open,
    is_missing_open,
    is_negative_job_id,
    is_negative_internal_id,

    --ISSUE SUMMARY FOR DQ VISIBILITY IN SELECT COUNT(*) FROM zen_silver.jobview_dq_anomalies;
    CONCAT_WS
    (', ',
        CASE WHEN is_missing_job_id          THEN 'missing job_id' END,
        CASE WHEN is_missing_internal_id     THEN 'missing internal_job_id' END,
        CASE WHEN is_missing_absolute_url    THEN 'missing absolute_url' END,
        CASE WHEN is_missing_title           THEN 'missing title' END,
        CASE WHEN is_missing_department      THEN 'missing department' END,
        CASE WHEN is_missing_location        THEN 'missing location' END,
        CASE WHEN is_missing_company_name    THEN 'missing company_name' END,
        CASE WHEN is_missing_both_dates      THEN 'missing both dates' END,
        CASE WHEN is_close_before_open       THEN 'close before open' END,
        CASE WHEN is_missing_open            THEN 'missing open date (has close date)' END,
        CASE WHEN is_negative_job_id         THEN 'negative job_id' END,
        CASE WHEN is_negative_internal_id    THEN 'negative internal_job_id' END
    ) AS issues
    
FROM flags
WHERE
       is_missing_job_id
    OR is_missing_internal_id
    OR is_missing_absolute_url
    OR is_missing_title
    OR is_missing_department
    OR is_missing_location
    OR is_missing_company_name
    OR is_missing_both_dates
    OR is_close_before_open
    OR is_missing_open
    OR is_negative_job_id
    OR is_negative_internal_id;


--END OF SILVER LAYER SETUP======================================
