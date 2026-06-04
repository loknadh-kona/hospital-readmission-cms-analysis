USE HealthcareAnalytics;
GO

-- Quick sense-check first — confirm the rate scale
SELECT TOP 5
    facility_name,
    condition,
    num_readmissions,
    num_discharges,
    expected_readmit_rate,
    -- Wrong (what was happening):
    ROUND(expected_readmit_rate * num_discharges, 2)          AS expected_wrong,
    -- Correct (divide by 100):
    ROUND((expected_readmit_rate / 100.0) * num_discharges, 2) AS expected_correct,
    -- Correct excess:
    ROUND(num_readmissions -
          (expected_readmit_rate / 100.0) * num_discharges, 2) AS excess_correct
FROM fact_readmissions
WHERE data_suppressed = 0
  AND num_discharges IS NOT NULL
  AND num_readmissions IS NOT NULL
ORDER BY num_readmissions DESC;
GO


-- ── FIX: Recalculate with rate ÷ 100 ─────────────────────────
UPDATE fact_readmissions
SET
    excess_readmissions =
        ROUND(
            CAST(num_readmissions AS DECIMAL(10,2)) -
            ((expected_readmit_rate / 100.0) * CAST(num_discharges AS DECIMAL(10,2))),
        2),

    excess_readmissions_pos =
        CASE
            WHEN CAST(num_readmissions AS DECIMAL(10,2)) >
                 ((expected_readmit_rate / 100.0) * CAST(num_discharges AS DECIMAL(10,2)))
            THEN ROUND(
                    CAST(num_readmissions AS DECIMAL(10,2)) -
                    ((expected_readmit_rate / 100.0) * CAST(num_discharges AS DECIMAL(10,2))),
                 2)
            ELSE 0
        END,

    est_excess_cost_usd =
        CASE
            WHEN CAST(num_readmissions AS DECIMAL(10,2)) >
                 ((expected_readmit_rate / 100.0) * CAST(num_discharges AS DECIMAL(10,2)))
            THEN ROUND(
                    (CAST(num_readmissions AS DECIMAL(10,2)) -
                    ((expected_readmit_rate / 100.0) * CAST(num_discharges AS DECIMAL(10,2))))
                    * 15200,
                 2)
            ELSE 0
        END

WHERE data_suppressed = 0
  AND num_discharges     IS NOT NULL
  AND num_readmissions   IS NOT NULL
  AND expected_readmit_rate IS NOT NULL;
GO

PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' rows updated — excess & cost columns corrected';
GO


-- ── FINAL VALIDATION ─────────────────────────────────────────

-- Headline KPIs — total_excess_cost_billions should now be a real number
SELECT * FROM vw_executive_kpis;
GO

-- Condition breakdown — your 4 Key Insights live here
SELECT
    condition,
    hospitals_reporting,
    total_discharges,
    total_readmissions,
    ROUND(readmit_rate_pct, 2)      AS readmit_rate_pct,
    avg_err,
    penalized_hospitals,
    ROUND(excess_cost_millions, 2)  AS excess_cost_millions
FROM vw_condition_summary
ORDER BY total_readmissions DESC;
GO

-- State top/bottom 5 — your map insight
SELECT TOP 5
    state, hospital_count, state_avg_err,
    err_vs_national, performance_band,
    penalized_hospitals, penalty_rate_pct,
    ROUND(excess_cost_millions, 2) AS excess_cost_millions
FROM vw_state_summary
ORDER BY state_avg_err DESC;
GO

SELECT TOP 5
    state, hospital_count, state_avg_err,
    err_vs_national, performance_band,
    penalized_hospitals, penalty_rate_pct,
    ROUND(excess_cost_millions, 2) AS excess_cost_millions
FROM vw_state_summary
ORDER BY state_avg_err ASC;
GO

