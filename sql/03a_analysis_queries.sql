USE HealthcareAnalytics;
GO
 
 
-- ════════════════════════════════════════════════════════════
-- BUSINESS QUESTION 1
-- Which hospital TYPES have the highest 30-day readmission rates?
-- ════════════════════════════════════════════════════════════
 
SELECT
    h.hospital_type,
    h.ownership_group,
    COUNT(DISTINCT f.facility_id)                               AS hospital_count,
    SUM(f.num_discharges)                                       AS total_discharges,
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS avg_err,
    ROUND(
        100.0 * SUM(f.num_readmissions) /
        NULLIF(SUM(f.num_discharges), 0), 2
    )                                                           AS readmit_rate_pct,
    COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
          THEN f.facility_id END)                               AS penalized_hospitals,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
                      THEN f.facility_id END) /
        NULLIF(COUNT(DISTINCT f.facility_id), 0), 1
    )                                                           AS penalty_rate_pct,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS est_excess_cost_millions
FROM fact_readmissions f
JOIN dim_hospital h ON f.facility_id = h.facility_id
WHERE f.data_suppressed = 0
GROUP BY h.hospital_type, h.ownership_group
ORDER BY avg_err DESC;
GO
 
 
-- ════════════════════════════════════════════════════════════
-- BUSINESS QUESTION 2
-- What CONDITIONS drive readmissions most?
-- ════════════════════════════════════════════════════════════
 
SELECT
    f.condition,
    f.condition_code,
    COUNT(DISTINCT f.facility_id)                               AS hospitals_reporting,
    SUM(f.num_discharges)                                       AS total_discharges,
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(
        100.0 * SUM(f.num_readmissions) /
        NULLIF(SUM(f.num_discharges), 0), 2
    )                                                           AS readmit_rate_pct,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS avg_err,
    ROUND(MIN(f.excess_readmit_ratio), 4)                       AS min_err,
    ROUND(MAX(f.excess_readmit_ratio), 4)                       AS max_err,
    COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
          THEN f.facility_id END)                               AS penalized_hospitals,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
                      THEN f.facility_id END) /
        NULLIF(COUNT(DISTINCT f.facility_id), 0), 1
    )                                                           AS penalty_rate_pct,
    SUM(f.excess_readmissions_pos)                              AS total_excess_readmissions,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS est_excess_cost_millions
FROM fact_readmissions f
WHERE f.data_suppressed = 0
GROUP BY f.condition, f.condition_code
ORDER BY total_readmissions DESC;
GO
 
 
-- ════════════════════════════════════════════════════════════
-- BUSINESS QUESTION 3
-- Which STATES are above/below national average ERR?
-- ════════════════════════════════════════════════════════════
 
WITH national_stats AS (
    -- Pre-calculated from Step 2 validation
    SELECT
        ROUND(AVG(excess_readmit_ratio), 4)  AS national_avg_err,
        ROUND(STDEV(excess_readmit_ratio), 4) AS national_std_dev
    FROM fact_readmissions
    WHERE data_suppressed = 0
),
state_metrics AS (
    SELECT
        f.state,
        COUNT(DISTINCT f.facility_id)                           AS hospital_count,
        SUM(f.num_discharges)                                   AS total_discharges,
        SUM(f.num_readmissions)                                 AS total_readmissions,
        ROUND(AVG(f.excess_readmit_ratio), 4)                   AS state_avg_err,
        ROUND(
            100.0 * SUM(f.num_readmissions) /
            NULLIF(SUM(f.num_discharges), 0), 2
        )                                                       AS readmit_rate_pct,
        COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
              THEN f.facility_id END)                           AS penalized_hospitals,
        ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
                          THEN f.facility_id END) /
            NULLIF(COUNT(DISTINCT f.facility_id), 0), 1
        )                                                       AS penalty_rate_pct,
        ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)       AS est_excess_cost_millions
    FROM fact_readmissions f
    WHERE f.data_suppressed = 0
    GROUP BY f.state
)
SELECT
    s.state,
    s.hospital_count,
    s.total_discharges,
    s.total_readmissions,
    s.state_avg_err,
    n.national_avg_err,
    ROUND(s.state_avg_err - n.national_avg_err, 4)              AS err_vs_national,
 
    -- Performance band for Power BI color coding
    CASE
        WHEN s.state_avg_err > n.national_avg_err + n.national_std_dev
             THEN 'High Risk'               -- > 1 std dev above national
        WHEN s.state_avg_err > n.national_avg_err
             THEN 'Above Average'
        WHEN s.state_avg_err < n.national_avg_err - n.national_std_dev
             THEN 'Top Performer'           -- > 1 std dev below national
        ELSE 'Below Average'
    END                                                         AS performance_band,
 
    s.readmit_rate_pct,
    s.penalized_hospitals,
    s.penalty_rate_pct,
    s.est_excess_cost_millions
FROM state_metrics s
CROSS JOIN national_stats n
ORDER BY s.state_avg_err DESC;
GO
 
 
-- ════════════════════════════════════════════════════════════
-- BUSINESS QUESTION 4
-- What is the COST IMPACT of excess readmissions?
-- ════════════════════════════════════════════════════════════
 
-- 4A: Total national cost impact
SELECT
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(SUM(f.expected_readmit_rate * f.num_discharges), 0)   AS total_expected_readmissions,
    ROUND(SUM(f.excess_readmissions_pos), 0)                    AS total_excess_readmissions,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000000.0, 3)         AS total_excess_cost_billions,
    ROUND(AVG(f.est_excess_cost_usd), 0)                        AS avg_cost_per_hosp_condition
FROM fact_readmissions f
WHERE f.data_suppressed = 0
  AND f.penalty_flag = 1;
GO
 
-- 4B: Cost breakdown by condition
SELECT
    f.condition,
    SUM(f.num_readmissions)                                     AS actual_readmissions,
    ROUND(SUM(f.expected_readmit_rate * f.num_discharges), 0)   AS expected_readmissions,
    ROUND(SUM(f.excess_readmissions_pos), 0)                    AS excess_readmissions,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS excess_cost_millions,
    ROUND(
        100.0 * SUM(f.est_excess_cost_usd) /
        NULLIF(SUM(SUM(f.est_excess_cost_usd)) OVER (), 0), 1
    )                                                           AS pct_of_total_cost
FROM fact_readmissions f
WHERE f.data_suppressed = 0
  AND f.penalty_flag = 1
GROUP BY f.condition
ORDER BY excess_cost_millions DESC;
GO
 
-- 4C: Top 20 hospitals by estimated excess cost
SELECT TOP 20
    f.facility_name,
    f.state,
    h.hospital_type,
    h.ownership_group,
    SUM(f.num_discharges)                                       AS total_discharges,
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS avg_err,
    ROUND(SUM(f.excess_readmissions_pos), 0)                    AS total_excess_readmissions,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 3)           AS est_excess_cost_millions,
    COUNT(DISTINCT f.condition)                                 AS conditions_penalized
FROM fact_readmissions f
JOIN dim_hospital h ON f.facility_id = h.facility_id
WHERE f.data_suppressed = 0
  AND f.penalty_flag = 1
GROUP BY f.facility_name, f.facility_id, f.state,
         h.hospital_type, h.ownership_group
ORDER BY est_excess_cost_millions DESC;
GO
 
 
