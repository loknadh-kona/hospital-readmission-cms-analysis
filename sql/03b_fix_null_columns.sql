-- ============================================================
-- STEP 3 FIX: Correct NULL num_discharges & num_readmissions
-- Root cause: pandas exported integers as floats (104 → 104.0)
--             TRY_CAST('104.0' AS INT) = NULL in SQL Server
-- Fix: two-step cast — VARCHAR → FLOAT → INT
-- Author  : Loknadh V K S Kona
-- ============================================================

USE HealthcareAnalytics;
GO

-- ── BEFORE: confirm the problem ───────────────────────────────
SELECT
    COUNT(*)                                        AS total_rows,
    SUM(CASE WHEN num_discharges   IS NULL THEN 1 ELSE 0 END) AS null_discharges,
    SUM(CASE WHEN num_readmissions IS NULL THEN 1 ELSE 0 END) AS null_readmissions
FROM fact_readmissions;
GO


-- ── FIX 1: Update num_discharges and num_readmissions ─────────
-- Join back to staging to get the raw strings, then double-cast
UPDATE f
SET
    f.num_discharges   = TRY_CAST(TRY_CAST(LTRIM(RTRIM(s.number_of_discharges))
                                            AS FLOAT) AS INT),
    f.num_readmissions = TRY_CAST(TRY_CAST(LTRIM(RTRIM(s.number_of_readmissions))
                                            AS FLOAT) AS INT)
FROM fact_readmissions f
JOIN stg_readmissions s
    ON  f.facility_id    = s.facility_id
    AND f.condition_code = s.measure_name;
GO

PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' rows updated — num_discharges & num_readmissions';
GO


-- ── FIX 2: Recalculate all derived columns ────────────────────
-- Now that num_discharges and num_readmissions are correct,
-- recompute excess readmissions and cost estimates

UPDATE fact_readmissions
SET
    -- Excess readmissions: actual − (expected rate × discharges)
    -- Negative = outperforming the benchmark
    excess_readmissions =
        CASE
            WHEN num_readmissions   IS NOT NULL
             AND expected_readmit_rate IS NOT NULL
             AND num_discharges     IS NOT NULL
            THEN ROUND(
                    CAST(num_readmissions AS DECIMAL(10,2)) -
                    (expected_readmit_rate * CAST(num_discharges AS DECIMAL(10,2))),
                 2)
            ELSE NULL
        END,

    -- Positive-only excess (floor at 0 — only count overages for cost)
    excess_readmissions_pos =
        CASE
            WHEN num_readmissions   IS NOT NULL
             AND expected_readmit_rate IS NOT NULL
             AND num_discharges     IS NOT NULL
             AND CAST(num_readmissions AS DECIMAL(10,2)) >
                 (expected_readmit_rate * CAST(num_discharges AS DECIMAL(10,2)))
            THEN ROUND(
                    CAST(num_readmissions AS DECIMAL(10,2)) -
                    (expected_readmit_rate * CAST(num_discharges AS DECIMAL(10,2))),
                 2)
            ELSE 0
        END,

    -- Estimated cost @ $15,200 per excess readmission
    est_excess_cost_usd =
        CASE
            WHEN num_readmissions   IS NOT NULL
             AND expected_readmit_rate IS NOT NULL
             AND num_discharges     IS NOT NULL
             AND CAST(num_readmissions AS DECIMAL(10,2)) >
                 (expected_readmit_rate * CAST(num_discharges AS DECIMAL(10,2)))
            THEN ROUND(
                    (CAST(num_readmissions AS DECIMAL(10,2)) -
                    (expected_readmit_rate * CAST(num_discharges AS DECIMAL(10,2))))
                    * 15200,
                 2)
            ELSE 0
        END
WHERE data_suppressed = 0;
GO

PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' rows updated — derived cost columns';
GO


-- ── VALIDATION: confirm fix worked ────────────────────────────

-- Should show 0 NULLs for complete (non-suppressed) rows
SELECT
    COUNT(*)                                                    AS total_rows,
    SUM(CASE WHEN data_suppressed = 0
              AND num_discharges IS NULL THEN 1 ELSE 0 END)     AS null_discharges_complete,
    SUM(CASE WHEN data_suppressed = 0
              AND num_readmissions IS NULL THEN 1 ELSE 0 END)   AS null_readmissions_complete,
    SUM(CASE WHEN data_suppressed = 1 THEN 1 ELSE 0 END)        AS suppressed_rows_ok_to_be_null
FROM fact_readmissions;
GO

-- Re-run Q1: Hospital type summary — should now show real numbers
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
    ROUND(SUM(f.est_excess_cost_usd) / 1000000.0, 2)           AS est_excess_cost_millions
FROM fact_readmissions f
JOIN dim_hospital h ON f.facility_id = h.facility_id
WHERE f.data_suppressed = 0
GROUP BY h.hospital_type, h.ownership_group
ORDER BY avg_err DESC;
GO

-- Re-run Q4 headline: Total national cost
SELECT
    SUM(f.num_readmissions)                                     AS total_readmissions,
    ROUND(SUM(f.excess_readmissions_pos), 0)                    AS total_excess_readmissions,
    ROUND(SUM(f.est_excess_cost_usd) / 1000000000.0, 3)        AS total_excess_cost_billions
FROM fact_readmissions f
WHERE f.data_suppressed = 0;
GO

-- Re-run KPI view
SELECT * FROM vw_executive_kpis;
GO

-- Condition view — readmit_rate_pct and excess_cost_millions should now populate
SELECT * FROM vw_condition_summary ORDER BY total_readmissions DESC;
GO

