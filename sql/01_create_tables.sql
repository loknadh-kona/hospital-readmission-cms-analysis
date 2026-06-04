-- ============================================================
-- STEP 1 (FINAL): Create Database + Load CMS FY2026 Data
-- Fix: Using pipe-delimited (|) files — bypasses all CSV
--      quoting issues. Hospital names with commas load cleanly.
-- Author  : Loknadh V K S Kona
-- ============================================================
-- BEFORE RUNNING:
--   1. Save hrrp_pipe.csv     → D:\AG\Health Care Project\hrrp_pipe.csv
--   2. Save hospital_pipe.csv → D:\AG\Health Care Project\hospital_pipe.csv
-- ============================================================
 
 
-- ── CLEAN RESET ──────────────────────────────────────────────
USE master;
GO
 
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'HealthcareAnalytics')
BEGIN
    ALTER DATABASE HealthcareAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HealthcareAnalytics;
    PRINT 'Old database dropped.';
END
GO
 
CREATE DATABASE HealthcareAnalytics;
PRINT 'Database created.';
GO
 
USE HealthcareAnalytics;
GO
 
 
-- ── TABLE 1: HRRP Readmissions ────────────────────────────────
CREATE TABLE stg_readmissions (
    facility_name           VARCHAR(300),
    facility_id             VARCHAR(20),
    state                   VARCHAR(10),
    measure_name            VARCHAR(300),
    number_of_discharges    VARCHAR(20),
    footnote                VARCHAR(200),
    excess_readmit_ratio    VARCHAR(20),
    predicted_readmit_rate  VARCHAR(20),
    expected_readmit_rate   VARCHAR(20),
    number_of_readmissions  VARCHAR(20),
    start_date              VARCHAR(20),
    end_date                VARCHAR(20)
);
GO
 
 
-- ── TABLE 2: Hospital Info (all 38 columns) ───────────────────
CREATE TABLE stg_hospital_info_raw (
    facility_id                             VARCHAR(20),
    facility_name                           VARCHAR(300),
    address                                 VARCHAR(300),
    city_town                               VARCHAR(150),
    state                                   VARCHAR(10),
    zip_code                                VARCHAR(20),
    county_parish                           VARCHAR(150),
    telephone_number                        VARCHAR(30),
    hospital_type                           VARCHAR(200),
    hospital_ownership                      VARCHAR(200),
    emergency_services                      VARCHAR(20),
    birthing_friendly                       VARCHAR(20),
    hospital_overall_rating                 VARCHAR(100),
    hospital_overall_rating_footnote        VARCHAR(500),
    mort_group_measure_count                VARCHAR(50),
    count_facility_mort_measures            VARCHAR(50),
    count_mort_measures_better              VARCHAR(50),
    count_mort_measures_no_different        VARCHAR(50),
    count_mort_measures_worse               VARCHAR(50),
    mort_group_footnote                     VARCHAR(500),
    safety_group_measure_count              VARCHAR(50),
    count_facility_safety_measures          VARCHAR(50),
    count_safety_measures_better            VARCHAR(50),
    count_safety_measures_no_different      VARCHAR(50),
    count_safety_measures_worse             VARCHAR(50),
    safety_group_footnote                   VARCHAR(500),
    readm_group_measure_count               VARCHAR(50),
    count_facility_readm_measures           VARCHAR(50),
    count_readm_measures_better             VARCHAR(50),
    count_readm_measures_no_different       VARCHAR(50),
    count_readm_measures_worse              VARCHAR(50),
    readm_group_footnote                    VARCHAR(500),
    pt_exp_group_measure_count              VARCHAR(50),
    count_facility_pt_exp_measures          VARCHAR(50),
    pt_exp_group_footnote                   VARCHAR(500),
    te_group_measure_count                  VARCHAR(50),
    count_facility_te_measures              VARCHAR(50),
    te_group_footnote                       VARCHAR(500)
);
GO
 
 
-- ── LOAD 1: HRRP Pipe-Delimited File ─────────────────────────
BULK INSERT stg_readmissions
FROM 'D:\AG\Health Care Project\hrrp_pipe.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '0x0d0a',     -- explicit CRLF (Windows line endings)
    TABLOCK
);
GO
 
PRINT 'HRRP load complete.';
 
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT facility_id)     AS unique_hospitals,
    COUNT(DISTINCT state)           AS unique_states,
    COUNT(DISTINCT measure_name)    AS unique_conditions
FROM stg_readmissions;
GO
 
 
-- ── LOAD 2: Hospital Info Pipe-Delimited File ─────────────────
BULK INSERT stg_hospital_info_raw
FROM 'D:\AG\Health Care Project\hospital_pipe.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '0x0d0a',
    TABLOCK
);
GO
 
PRINT 'Hospital info load complete.';
 
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT facility_id)     AS unique_hospitals,
    COUNT(DISTINCT state)           AS unique_states,
    COUNT(DISTINCT hospital_type)   AS hospital_types
FROM stg_hospital_info_raw;
GO
 
 
-- ── NARROW HOSPITAL TABLE (only the columns we need) ─────────
CREATE TABLE stg_hospital_info (
    facility_id         VARCHAR(20),
    facility_name       VARCHAR(300),
    address             VARCHAR(300),
    city_town           VARCHAR(150),
    state               VARCHAR(10),
    zip_code            VARCHAR(20),
    county_parish       VARCHAR(150),
    hospital_type       VARCHAR(200),
    hospital_ownership  VARCHAR(200),
    emergency_services  VARCHAR(20)
);
GO
 
INSERT INTO stg_hospital_info
SELECT
    facility_id, facility_name, address, city_town, state,
    zip_code, county_parish, hospital_type,
    hospital_ownership, emergency_services
FROM stg_hospital_info_raw;
GO
 
SELECT COUNT(*) AS hospital_info_rows FROM stg_hospital_info;
GO
 
 
-- ── FINAL VALIDATION — Share these 3 results ─────────────────
 
-- CHECK 1: Row counts
SELECT 'stg_readmissions'   AS table_name, COUNT(*) AS row_count FROM stg_readmissions
UNION ALL
SELECT 'stg_hospital_info'  AS table_name, COUNT(*) AS row_count FROM stg_hospital_info;
GO
 
-- CHECK 2: Join match rate (should be 85%+)
SELECT
    COUNT(DISTINCT r.facility_id)                           AS hrrp_facilities,
    COUNT(DISTINCT h.facility_id)                           AS matched_to_hosp_info,
    COUNT(DISTINCT r.facility_id) -
        COUNT(DISTINCT h.facility_id)                       AS unmatched,
    ROUND(
        100.0 * COUNT(DISTINCT h.facility_id) /
        NULLIF(COUNT(DISTINCT r.facility_id), 0), 1
    )                                                       AS match_rate_pct
FROM stg_readmissions r
LEFT JOIN stg_hospital_info h ON r.facility_id = h.facility_id;
GO
 
-- CHECK 3: Exact condition labels in YOUR file
--          (needed to build Step 2 CASE mapping)
SELECT DISTINCT measure_name
FROM stg_readmissions
ORDER BY measure_name;
GO
 
-- CHECK 4: Sample rows — verify hospital names loaded correctly
SELECT TOP 5 facility_name, facility_id, state, measure_name
FROM stg_readmissions
WHERE facility_name LIKE '%,%';
GO