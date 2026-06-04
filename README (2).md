# 🏥 Hospital Readmission Rate Analysis — CMS Medicare Data (FY2026)

[![SQL Server](https://img.shields.io/badge/SQL-Server%20T--SQL-CC2927?logo=microsoftsqlserver&logoColor=white)](.)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](.)
[![Power BI](https://img.shields.io/badge/Power%20BI-5%20Page%20Dashboard-F2C811?logo=powerbi&logoColor=black)](.)
[![CMS Data](https://img.shields.io/badge/Data-CMS%20HRRP%20FY2026-005A9C)](https://data.cms.gov/provider-data/dataset/9n3s-kdb3)
[![HIPAA](https://img.shields.io/badge/HIPAA-Trained-2E86AB)](.)

![Dashboard Hero](assets/dashboard_hero.png)

---

## 📌 Project Overview

End-to-end healthcare analytics project analyzing **30-day hospital readmission rates** across **3,055 U.S. hospitals** using CMS Hospital Readmissions Reduction Program (HRRP) FY2026 data. Hospitals face Medicare payment reductions of up to 3% for excess readmissions — this project identifies the clinical conditions, hospital types, and states driving the highest penalty exposure and translates CMS penalty data into actionable operational recommendations.

**This project replicates the exact analytical workflow used by hospital quality improvement teams and healthcare payers managing HRRP compliance.**

---

## 🎯 4 Business Questions Answered

| # | Business Question | Method | Output |
|---|---|---|---|
| 1 | Which hospital types have highest 30-day readmission rates? | T-SQL aggregation + Power BI | Ownership group ERR comparison |
| 2 | What conditions drive readmissions most? | Python EDA + statistical analysis | Volume vs ERR contrast |
| 3 | Which states are above/below national average? | SQL CTEs + Power BI map | State performance bands |
| 4 | What is the cost impact of high-readmission hospitals? | Python financial modeling + Power BI | $402.2M excess cost estimate |

---

## 📊 Dashboard Preview

### Page 1 — Executive Overview
![Executive Overview](assets/dashboard_page1_executive_overview.png)

### Page 2 — Condition Analysis
![Condition Analysis](assets/dashboard_page2_condition_analysis.png)

### Page 3 — Hospital Type Analysis
![Hospital Type](assets/dashboard_page3_hospital_type.png)

### Page 4 — Cost Impact
![Cost Impact](assets/dashboard_page4_cost_impact.png)

### Page 5 — State Benchmarking Tool (Interactive)
![State Benchmarking MA](assets/dashboard_page5_state_benchmarking_MA.png)
![State Benchmarking ND](assets/dashboard_page5_state_benchmarking_ND.png)

---

## 🔑 4 Key Findings

### Finding 1 — Heart Failure is the #1 national readmission burden
Heart Failure accounts for **164,544 readmissions nationally** at a **19.7% readmission rate** — the highest volume of any condition. Estimated excess cost: **$140.9M**. Despite not having the highest Excess Readmission Ratio (ERR), Heart Failure's sheer patient volume makes it the primary operational and financial target for health systems.

> **Recommendation:** Health systems should implement structured post-discharge follow-up protocols (Day 3 and Day 7 phone calls, medication reconciliation, care coordinator visits) specifically for Heart Failure patients. Evidence shows these interventions reduce 30-day readmissions by 20–25%.

### Finding 2 — Pneumonia is the underappreciated #2 burden at $134.9M
Pneumonia accounts for **128,137 readmissions** and **$134.9M** in estimated excess cost — nearly equal to Heart Failure in financial impact but receives significantly less operational attention in most health systems. Heart Failure and Pneumonia together account for **69%** of all excess readmission cost nationally.

> **Recommendation:** Clinical quality teams should include Pneumonia in care transitions programs alongside Heart Failure — the combined ROI of targeting both conditions significantly exceeds targeting either alone.

### Finding 3 — Massachusetts, New Jersey, and Florida are the highest-risk states
Massachusetts leads nationally with an average ERR of **1.035** and **90.2%** of hospitals penalized. Florida hospitals collectively generate **$41.7M** in excess readmission cost — the highest of any state. North Dakota performs best nationally with an average ERR of **0.947** — 5.5% below the national average of **1.002**.

> **Recommendation:** State health departments and ACOs in high-readmission states should invest in community health worker programs targeting underserved ZIP codes. Geographic clustering of high-ERR states in the Northeast and Southeast suggests systemic access and social determinant factors beyond individual hospital quality.

### Finding 4 — $402.2M in estimated avoidable excess readmission cost nationally
Applying the CMS average Medicare readmission cost of **$15,200 per event**, excess readmissions at penalized hospitals represent an estimated **$402.2M in avoidable expenditure** — driven by **26,460 excess readmission events** across **2,284 penalized hospitals**. For-Profit hospitals show the highest average ERR (**1.0169**) compared to Government hospitals (**0.9999**).

> **Recommendation:** Payer organizations should develop predictive risk stratification models flagging patients at discharge for high readmission risk, and tie care management resource allocation to model outputs rather than diagnosis alone.

---

## 🛠️ Tech Stack

| Tool | Purpose |
|---|---|
| **SQL Server (T-SQL)** | Data staging, cleaning, transformation, analytical views |
| **Python** (Pandas, NumPy, Matplotlib, Seaborn, SciPy) | EDA, statistical analysis, publication-quality visualizations |
| **Power BI** (DAX) | 5-page interactive dashboard with cross-filtering and drillthrough |
| **CMS HRRP FY2026** | Primary dataset — data.cms.gov |
| **CMS Hospital General Information** | Dimension data — hospital type, ownership, location |

---

## 📈 Key Metrics at a Glance

| Metric | Value |
|---|---|
| Hospitals Analyzed | 3,055 |
| States Covered | 51 |
| Clinical Conditions Tracked | 6 |
| Total Readmissions (National) | 381,794 |
| National Average ERR | 1.002 |
| % Hospitals Penalized | 83.1% |
| Total Excess Readmissions | 26,460 |
| Estimated Excess Cost | $402.2M |
| Highest-Risk State | Massachusetts (ERR 1.035) |
| Top Performer State | North Dakota (ERR 0.947) |
| Highest-Cost Hospital | AdventHealth Orlando, FL |
| Highest-Burden Condition | Heart Failure (164,544 readmissions) |

---

## 📁 Repository Structure

```
hospital-readmission-cms-analysis/
│
├── README.md
│
├── sql/
│   ├── 01_create_and_load.sql          # Database creation, staging tables, BULK INSERT
│   ├── 02_clean_and_transform.sql      # Type casting, condition mapping, derived columns
│   ├── 03_analysis_and_views.sql       # 4 business question queries + Power BI views
│   └── 03b_fix_null_columns.sql        # Data quality fix — float-to-int casting
│
├── python/
│   ├── 01_eda_and_cleaning.ipynb       # Data loading, column mapping, derived flags
│   ├── 02_statistical_analysis.ipynb  # 4 business questions, t-tests, key findings
│   └── 03_visualizations.ipynb        # 6 publication-quality charts
│
├── powerbi/
│   └── HealthCare_Analytics_Dashboard.pbix
│
├── data/
│   ├── raw/                            # Original CMS files (not committed — see .gitignore)
│   └── processed/                      # Cleaned CSVs generated by Python notebooks
│       ├── readmission_clean.csv
│       ├── condition_summary.csv
│       ├── state_summary.csv
│       ├── hospital_type_summary.csv
│       └── cost_by_condition.csv
│
├── assets/
│   ├── dashboard_hero.png
│   ├── dashboard_page1_executive_overview.png
│   ├── dashboard_page2_condition_analysis.png
│   ├── dashboard_page3_hospital_type.png
│   ├── dashboard_page4_cost_impact.png
│   ├── dashboard_page5_state_benchmarking_MA.png
│   ├── dashboard_page5_state_benchmarking_ND.png
│   ├── chart1_err_by_condition.png
│   ├── chart2_state_performance.png
│   ├── chart3_condition_bubble.png
│   ├── chart4_excess_cost_by_condition.png
│   ├── chart5_penalty_by_ownership.png
│   └── chart6_top_bottom_states.png
│
└── .gitignore
```

---

## 🚀 How to Reproduce

### Prerequisites
- SQL Server (any edition including Express)
- Python 3.11+ with: `pandas numpy matplotlib seaborn scipy`
- Power BI Desktop (free)

### Step 1 — Download CMS Data
- HRRP FY2026: [data.cms.gov/provider-data/dataset/9n3s-kdb3](https://data.cms.gov/provider-data/dataset/9n3s-kdb3)
- Hospital General Information: [data.cms.gov/provider-data/dataset/xubh-q36u](https://data.cms.gov/provider-data/dataset/xubh-q36u)

### Step 2 — SQL Pipeline
```sql
-- Run in order in SSMS:
sql/01_create_and_load.sql       -- creates DB, loads data
sql/02_clean_and_transform.sql   -- builds fact + dimension tables
sql/03_analysis_and_views.sql    -- creates 4 Power BI views
sql/03b_fix_null_columns.sql     -- fixes float-to-int casting issue
```

### Step 3 — Python Notebooks
```bash
pip install pandas numpy matplotlib seaborn scipy
# Run notebooks in order from the python/ directory:
# 01 → 02 → 03
```

### Step 4 — Power BI Dashboard
1. Open `powerbi/HealthCare_Analytics_Dashboard.pbix`
2. Home → Transform data → Data source settings
3. Update server name to your SQL Server instance
4. Click **Refresh**

---

## 📊 Python Visualizations

### ERR Distribution by Condition
![Chart 1](assets/chart1_err_by_condition.png)

### State Performance vs National Average
![Chart 2](assets/chart2_state_performance.png)

### Readmission Rate vs ERR Bubble Chart
![Chart 3](assets/chart3_condition_bubble.png)

### Excess Cost by Condition
![Chart 4](assets/chart4_excess_cost_by_condition.png)

### Penalty Rate by Hospital Ownership
![Chart 5](assets/chart5_penalty_by_ownership.png)

### Top 10 vs Bottom 10 States
![Chart 6](assets/chart6_top_bottom_states.png)

---

## 🏥 Clinical Context

**What is the Excess Readmission Ratio (ERR)?**
ERR is the core CMS metric. An ERR > 1.0 means a hospital has more readmissions than expected given its patient population. CMS calculates the expected rate using risk-adjustment models accounting for patient demographics and comorbidities. Hospitals with ERR > 1.0 on any of the 6 tracked conditions receive a Medicare payment reduction of up to 3%.

**6 Conditions Tracked by CMS HRRP:**
- Acute Myocardial Infarction (AMI)
- Coronary Artery Bypass Graft (CABG)
- Chronic Obstructive Pulmonary Disease (COPD)
- Heart Failure (HF)
- Hip/Knee Arthroplasty
- Pneumonia (PN)

**Data Suppression:** CMS suppresses data for hospitals with fewer than 25 cases in a condition to protect patient privacy. These records are excluded from analysis (6,987 of 18,330 records). All findings are based on the 11,343 complete records.

---

## 🔗 Connect

**Loknadh Venkata Krishna Sai Kona**
MS Data Science — University of Memphis (GPA 3.81)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lvkrishna3-0077B5?logo=linkedin)](https://linkedin.com/in/lvkrishna3)
[![GitHub](https://img.shields.io/badge/GitHub-KrishnaSai315-181717?logo=github)](https://github.com/KrishnaSai315)

---

*Data Source: CMS Hospital Readmissions Reduction Program FY2026 — publicly available at data.cms.gov*
*Cost estimates use $15,200 per readmission (CMS Medicare average). Estimates are illustrative and not official CMS financial figures.*
