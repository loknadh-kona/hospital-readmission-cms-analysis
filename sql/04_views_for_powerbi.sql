-- ════════════════════════════════════════════════════════════
-- POWER BI VIEWS — Pre-aggregated for fast dashboard loads
-- ════════════════════════════════════════════════════════════
 
-- VIEW 1: State-level summary (feeds the choropleth map + bar charts)
CREATE OR ALTER VIEW vw_state_summary AS
WITH nat AS (
    SELECT
        ROUND(AVG(excess_readmit_ratio), 4)   AS national_avg_err,
        ROUND(STDEV(excess_readmit_ratio), 4) AS national_std_dev
    FROM fact_readmissions
    WHERE data_suppressed = 0
)
SELECT
    f.state,
    COUNT(DISTINCT f.facility_id)                               AS hospital_count,
    SUM(f.num_discharges)                                       AS total_discharges,
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS state_avg_err,
    n.national_avg_err,
    ROUND(AVG(f.excess_readmit_ratio) - n.national_avg_err, 4) AS err_vs_national,
    CASE
        WHEN AVG(f.excess_readmit_ratio) > n.national_avg_err + n.national_std_dev
             THEN 'High Risk'
        WHEN AVG(f.excess_readmit_ratio) > n.national_avg_err
             THEN 'Above Average'
        WHEN AVG(f.excess_readmit_ratio) < n.national_avg_err - n.national_std_dev
             THEN 'Top Performer'
        ELSE 'Below Average'
    END                                                         AS performance_band,
    COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
          THEN f.facility_id END)                               AS penalized_hospitals,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
                      THEN f.facility_id END) /
        NULLIF(COUNT(DISTINCT f.facility_id), 0), 1
    )                                                           AS penalty_rate_pct,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS excess_cost_millions
FROM fact_readmissions f
CROSS JOIN nat n
WHERE f.data_suppressed = 0
GROUP BY f.state, n.national_avg_err, n.national_std_dev;
GO
 
 
-- VIEW 2: Condition summary (feeds bar/donut charts)
CREATE OR ALTER VIEW vw_condition_summary AS
SELECT
    f.condition,
    COUNT(DISTINCT f.facility_id)                               AS hospitals_reporting,
    SUM(f.num_discharges)                                       AS total_discharges,
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(
        100.0 * SUM(f.num_readmissions) /
        NULLIF(SUM(f.num_discharges), 0), 2
    )                                                           AS readmit_rate_pct,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS avg_err,
    COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
          THEN f.facility_id END)                               AS penalized_hospitals,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS excess_cost_millions
FROM fact_readmissions f
WHERE f.data_suppressed = 0
GROUP BY f.condition;
GO
 
 
-- VIEW 3: Hospital detail (feeds drillthrough + Top N tables)
CREATE OR ALTER VIEW vw_hospital_detail AS
SELECT
    f.facility_id,
    f.facility_name,
    f.state,
    h.city_town,
    h.county_parish,
    h.hospital_type,
    h.ownership_group,
    h.hospital_ownership,
    f.condition,
    f.num_discharges,
    f.num_readmissions,
    f.excess_readmit_ratio,
    f.predicted_readmit_rate,
    f.expected_readmit_rate,
    f.penalty_flag,
    f.excess_readmissions,
    f.excess_readmissions_pos,
    f.est_excess_cost_usd,
    f.data_suppressed,
    f.period_start,
    f.period_end
FROM fact_readmissions f
JOIN dim_hospital h ON f.facility_id = h.facility_id;
GO
 
 
-- VIEW 4: KPI card values (feeds the executive overview page)
CREATE OR ALTER VIEW vw_executive_kpis AS
SELECT
    COUNT(DISTINCT f.facility_id)                               AS total_hospitals_analyzed,
    COUNT(DISTINCT f.state)                                     AS states_covered,
    ROUND(AVG(f.excess_readmit_ratio), 4)                       AS national_avg_err,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
                      THEN f.facility_id END) /
        NULLIF(COUNT(DISTINCT f.facility_id), 0), 1
    )                                                           AS pct_hospitals_penalized,
    SUM(f.num_readmissions)                                     AS total_readmissions_national,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000000.0, 3)        AS total_excess_cost_billions,
    COUNT(DISTINCT CASE WHEN f.penalty_flag = 1
          THEN f.facility_id END)                               AS penalized_hospital_count,
    ROUND(SUM(f.excess_readmissions_pos), 0)                    AS total_excess_readmissions
FROM fact_readmissions f
WHERE f.data_suppressed = 0;
GO
 
 
-- ── FINAL CHECK — Preview all 4 views ────────────────────────
SELECT * FROM vw_executive_kpis;
GO
 
SELECT TOP 5 * FROM vw_state_summary ORDER BY state_avg_err DESC;
GO
 
SELECT * FROM vw_condition_summary ORDER BY total_readmissions DESC;
GO
 
SELECT TOP 5 * FROM vw_hospital_detail ORDER BY est_excess_cost_usd DESC;
GO