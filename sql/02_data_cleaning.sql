USE HealthcareAnalytics;
GO
 
 
-- ── 2A. DIMENSION TABLE — Hospital Attributes ─────────────────
-- One row per hospital with type, ownership, location
 
CREATE TABLE dim_hospital (
    facility_id         VARCHAR(20)     PRIMARY KEY,
    facility_name       VARCHAR(300),
    city_town           VARCHAR(150),
    state               VARCHAR(10),
    zip_code            VARCHAR(20),
    county_parish       VARCHAR(150),
    hospital_type       VARCHAR(200),
    hospital_ownership  VARCHAR(200),
    emergency_services  VARCHAR(20),
 
    -- Derived groupings for dashboard slicers
    ownership_group     AS (
        CASE
            WHEN hospital_ownership LIKE '%Government%'       THEN 'Government'
            WHEN hospital_ownership LIKE '%Non-profit%'
              OR hospital_ownership LIKE '%Voluntary%'        THEN 'Non-Profit'
            WHEN hospital_ownership LIKE '%Proprietary%'
              OR hospital_ownership LIKE '%For profit%'       THEN 'For-Profit'
            ELSE 'Other / Unknown'
        END
    ) PERSISTED
);
GO
 
INSERT INTO dim_hospital (
    facility_id, facility_name, city_town, state, zip_code,
    county_parish, hospital_type, hospital_ownership, emergency_services
)
SELECT DISTINCT
    LTRIM(RTRIM(facility_id))           AS facility_id,
    LTRIM(RTRIM(facility_name))         AS facility_name,
    LTRIM(RTRIM(city_town))             AS city_town,
    LTRIM(RTRIM(state))                 AS state,
    LTRIM(RTRIM(zip_code))              AS zip_code,
    LTRIM(RTRIM(county_parish))         AS county_parish,
    ISNULL(LTRIM(RTRIM(hospital_type)),      'Unknown') AS hospital_type,
    ISNULL(LTRIM(RTRIM(hospital_ownership)), 'Unknown') AS hospital_ownership,
    LTRIM(RTRIM(emergency_services))    AS emergency_services
FROM stg_hospital_info
WHERE LTRIM(RTRIM(facility_id)) != '';
GO
 
-- Validation
SELECT
    COUNT(*)                        AS total_hospitals,
    COUNT(DISTINCT state)           AS states,
    COUNT(DISTINCT hospital_type)   AS hospital_types,
    COUNT(DISTINCT hospital_ownership) AS ownership_types,
    COUNT(DISTINCT ownership_group) AS ownership_groups
FROM dim_hospital;
GO
 
SELECT hospital_type, COUNT(*) AS cnt
FROM dim_hospital
GROUP BY hospital_type
ORDER BY cnt DESC;
GO
 
 
-- ── 2B. FACT TABLE — Readmission Metrics ─────────────────────
-- One row per hospital × condition combination
-- All numeric columns safely type-cast; invalid = NULL
 
CREATE TABLE fact_readmissions (
    -- Keys
    facility_id             VARCHAR(20),
    facility_name           VARCHAR(300),
    state                   VARCHAR(10),
 
    -- Condition (cleaned from CMS measure codes)
    condition_code          VARCHAR(30),        -- original CMS code
    condition               VARCHAR(50),        -- readable label
 
    -- Core CMS metrics (numeric; NULL where CMS suppressed data)
    num_discharges          INT,
    excess_readmit_ratio    DECIMAL(8,4),       -- ERR: the headline metric
    predicted_readmit_rate  DECIMAL(8,4),       -- model-predicted %
    expected_readmit_rate   DECIMAL(8,4),       -- national benchmark %
    num_readmissions        INT,
 
    -- Date range
    period_start            DATE,
    period_end              DATE,
 
    -- Derived flags and calculations
    penalty_flag            TINYINT,            -- 1 = ERR > 1.0 (CMS penalizes)
    data_suppressed         TINYINT,            -- 1 = CMS suppressed (too few cases)
    footnote                VARCHAR(200),
 
    -- Excess readmissions (actual vs what was expected at that hospital's rate)
    excess_readmissions     DECIMAL(10,2),      -- can be negative (better than expected)
    excess_readmissions_pos DECIMAL(10,2),      -- floor at 0 (only count overages)
 
    -- Estimated financial impact @ $15,200 per readmission (CMS 2024 avg)
    est_excess_cost_usd     DECIMAL(14,2)
);
GO
 
INSERT INTO fact_readmissions
SELECT
    -- Keys
    LTRIM(RTRIM(r.facility_id))                         AS facility_id,
    LTRIM(RTRIM(r.facility_name))                       AS facility_name,
    LTRIM(RTRIM(r.state))                               AS state,
 
    -- Condition mapping — exact FY2026 CMS measure codes
    LTRIM(RTRIM(r.measure_name))                        AS condition_code,
    CASE LTRIM(RTRIM(r.measure_name))
        WHEN 'READM-30-AMI-HRRP'      THEN 'Acute MI'
        WHEN 'READM-30-CABG-HRRP'     THEN 'CABG'
        WHEN 'READM-30-COPD-HRRP'     THEN 'COPD'
        WHEN 'READM-30-HF-HRRP'       THEN 'Heart Failure'
        WHEN 'READM-30-HIP-KNEE-HRRP' THEN 'Hip/Knee Arthroplasty'
        WHEN 'READM-30-PN-HRRP'       THEN 'Pneumonia'
        ELSE 'Other'
    END                                                 AS condition,
 
    -- Safe type casting — CMS uses 'N/A', blanks, and 'Too Few to Report'
    TRY_CAST(r.number_of_discharges  AS INT)            AS num_discharges,
    TRY_CAST(r.excess_readmit_ratio  AS DECIMAL(8,4))   AS excess_readmit_ratio,
    TRY_CAST(r.predicted_readmit_rate AS DECIMAL(8,4))  AS predicted_readmit_rate,
    TRY_CAST(r.expected_readmit_rate  AS DECIMAL(8,4))  AS expected_readmit_rate,
    TRY_CAST(r.number_of_readmissions AS INT)           AS num_readmissions,
 
    -- Dates
    TRY_CAST(r.start_date AS DATE)                      AS period_start,
    TRY_CAST(r.end_date   AS DATE)                      AS period_end,
 
    -- Penalty flag: ERR above 1.0 = hospital gets Medicare payment reduction
    CASE
        WHEN TRY_CAST(r.excess_readmit_ratio AS DECIMAL(8,4)) > 1.0 THEN 1
        ELSE 0
    END                                                 AS penalty_flag,
 
    -- Suppression flag: footnote present = CMS hid data (volume too small)
    CASE
        WHEN LTRIM(RTRIM(ISNULL(r.footnote,''))) != '' THEN 1
        ELSE 0
    END                                                 AS data_suppressed,
 
    LTRIM(RTRIM(ISNULL(r.footnote,'')))                 AS footnote,
 
    -- Excess readmissions: actual minus what was expected given patient mix
    -- Negative = performing BETTER than benchmark
    ROUND(
        TRY_CAST(r.number_of_readmissions AS DECIMAL(10,2)) -
        (TRY_CAST(r.expected_readmit_rate AS DECIMAL(8,4)) *
         TRY_CAST(r.number_of_discharges  AS DECIMAL(10,2))),
    2)                                                  AS excess_readmissions,
 
    -- Positive-only excess (used in cost calculations)
    ROUND(
        CASE
            WHEN TRY_CAST(r.number_of_readmissions AS DECIMAL(10,2)) >
                 (TRY_CAST(r.expected_readmit_rate AS DECIMAL(8,4)) *
                  TRY_CAST(r.number_of_discharges  AS DECIMAL(10,2)))
            THEN TRY_CAST(r.number_of_readmissions AS DECIMAL(10,2)) -
                 (TRY_CAST(r.expected_readmit_rate AS DECIMAL(8,4)) *
                  TRY_CAST(r.number_of_discharges  AS DECIMAL(10,2)))
            ELSE 0
        END,
    2)                                                  AS excess_readmissions_pos,
 
    -- Cost impact @ $15,200 per readmission (CMS Medicare average FY2024)
    ROUND(
        CASE
            WHEN TRY_CAST(r.number_of_readmissions AS DECIMAL(10,2)) >
                 (TRY_CAST(r.expected_readmit_rate AS DECIMAL(8,4)) *
                  TRY_CAST(r.number_of_discharges  AS DECIMAL(10,2)))
            THEN (TRY_CAST(r.number_of_readmissions AS DECIMAL(10,2)) -
                 (TRY_CAST(r.expected_readmit_rate AS DECIMAL(8,4)) *
                  TRY_CAST(r.number_of_discharges  AS DECIMAL(10,2)))) * 15200
            ELSE 0
        END,
    2)                                                  AS est_excess_cost_usd
 
FROM stg_readmissions r;
GO
 
PRINT 'fact_readmissions loaded.';
GO
 
 
-- ── 2C. VALIDATION ────────────────────────────────────────────
 
-- Overall counts
SELECT
    COUNT(*)                                            AS total_records,
    COUNT(DISTINCT facility_id)                         AS unique_hospitals,
    COUNT(DISTINCT state)                               AS unique_states,
    COUNT(DISTINCT condition)                           AS unique_conditions,
    SUM(CASE WHEN data_suppressed = 0 THEN 1 ELSE 0 END) AS complete_records,
    SUM(CASE WHEN data_suppressed = 1 THEN 1 ELSE 0 END) AS suppressed_records,
    SUM(CASE WHEN penalty_flag = 1    THEN 1 ELSE 0 END) AS penalized_records
FROM fact_readmissions;
GO
 
-- Condition summary — quick sense-check
SELECT
    condition,
    COUNT(DISTINCT facility_id)                         AS hospitals_reporting,
    SUM(CASE WHEN data_suppressed = 0 THEN 1 ELSE 0 END) AS complete_records,
    ROUND(AVG(CASE WHEN data_suppressed = 0
              THEN excess_readmit_ratio END), 4)        AS avg_err,
    SUM(CASE WHEN penalty_flag = 1 THEN 1 ELSE 0 END)  AS penalized_count,
    SUM(num_readmissions)                               AS total_readmissions
FROM fact_readmissions
GROUP BY condition
ORDER BY avg_err DESC;
GO
 
-- Penalty summary
SELECT
    SUM(CASE WHEN penalty_flag = 1 THEN 1 ELSE 0 END)  AS penalized_hospital_conditions,
    COUNT(DISTINCT CASE WHEN penalty_flag = 1
          THEN facility_id END)                         AS penalized_unique_hospitals,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN penalty_flag = 1
                      THEN facility_id END) /
        COUNT(DISTINCT facility_id), 1
    )                                                   AS pct_hospitals_penalized
FROM fact_readmissions
WHERE data_suppressed = 0;
GO
 
-- National average ERR (the benchmark for all state comparisons)
SELECT
    ROUND(AVG(excess_readmit_ratio), 4)                 AS national_avg_err,
    ROUND(MIN(excess_readmit_ratio), 4)                 AS min_err,
    ROUND(MAX(excess_readmit_ratio), 4)                 AS max_err,
    ROUND(STDEV(excess_readmit_ratio), 4)               AS std_dev_err
FROM fact_readmissions
WHERE data_suppressed = 0;
GO