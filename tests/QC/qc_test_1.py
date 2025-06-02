import pandas as pd

# ─────────────────────────────────────────────────────────────
# #1: Load Test File & Extract Relevant Metrics
# ─────────────────────────────────────────────────────────────

# load the files as vars first - should me all MM
test_df_qc = pd.read_csv('/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/derivatives/GGIR-3.2.6-test/sub-7016/accel/output_accel/results/QC/data_quality_report.csv')
test_df_p5_person = pd.read_csv('/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/derivatives/GGIR-3.2.6-test/sub-7016/accel/output_accel/results/part5_personsummary_MM_L40M100V400_T5A5.csv')
test_df_p5_day = pd.read_csv('/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/derivatives/GGIR-3.2.6-test/sub-7016/accel/output_accel/results/part5_daysummary_MM_L40M100V400_T5A5.csv')

dfs = [test_df_qc,test_df_p5_person,test_df_p5_day]

for df in dfs:
    print(df.head())


# ─────────────────────────────────────────────────────────────
# #2 QC Criteria
# 1. Calibration Error      → Should be below 0.03g ~~ van Hees, V.T. et al. (2014)
# 2. Hours Considered       → Within ±5 hours of days worn (TBD with HBC) 2 WD / 1 WE
# 3. Cleaning Codes         → If code ≠ 0 or 1, log subject ID and day to a CSV of errors
# 4. Valid Days Threshold   → Never fewer than total days worn
# ─────────────────────────────────────────────────────────────

# Shorten the name cuz im lazy
qc = test_df_qc
person = test_df_p5_person
day = test_df_p5_day
del test_df_qc
del test_df_p5_person
del test_df_p5_day


# ─────────────────────────────────────────────────────────────
# Create variables from loaded dataframes
# ─────────────────────────────────────────────────────────────
# Extract first value if Series has only one value
cal_err = qc['cal.error.end'].iloc[0]
h_considered = qc['n.hours.considered'].iloc[0]
valid_days = person['Nvaliddays'].iloc[0]
clean_code = day['cleaningcode']  # remains a Series for inspection
n_days_worn = 7
print(f"""
  Calibration Error:  {cal_err} 
  Hours Considered:   {h_considered} 
  Cleaning Code:      {clean_code} 
  Valid Days:         {valid_days} 
""")

# ─────────────────────────────────────────────────────────────
# #3 Quality Control Algorithms
# ─────────────────────────────────────────────────────────────

def cal_error_check(cal_error, threshold=0.03):
    """
    Returns:
      0 → OK
      1 → Calibration error exceeds threshold
    """
    return 1 if cal_error > threshold else 0

def h_considered_check(h_considered, n_days_worn, tolerance=5):
    """
    Returns:
      0 → OK
      1 → Too few hours considered relative to days worn
      2 → More hours than expected (possibly incorrect n_days_worn)
    """
    expected_hours = n_days_worn * 24
    if h_considered < (expected_hours - tolerance):
        return 1
    elif h_considered > expected_hours:
        return 2
    return 0

def cleaning_code_check(clean_code):
    """
    Returns:
      0 → All codes valid (0 or 1)
      1 → Found invalid code (not 0 or 1)
      2 → Only NaNs, no invalid codes
    """
    if ((~clean_code.isin([0, 1])) & clean_code.notna()).any():
        return 1
    elif clean_code.isna().any():
        return 2
    return 0

def valid_days_check(valid_days, n_days_worn):
    """
    Returns:
      0 → OK
      1 → Too few valid days
      2 → Too many valid days (likely error in counting)
    """
    if valid_days < n_days_worn:
        return 1
    elif valid_days > n_days_worn:
        return 2
    return 0

# ─────────────────────────────────────────────────────────────
# #4 QC Runner: Returns status codes + human-readable meanings
# ─────────────────────────────────────────────────────────────

def run_qc_checks(cal_err, h_considered, clean_code, valid_days, n_days_worn):
    checks = {
        "Calibration Error": cal_error_check(cal_err),
        "Hours Considered": h_considered_check(h_considered, n_days_worn),
        "Cleaning Code": cleaning_code_check(clean_code),
        "Valid Days": valid_days_check(valid_days, n_days_worn),
    }

    meanings = {
        "Calibration Error": {
            0: "Pass",
            1: "ERROR: Calibration error too high"
        },
        "Hours Considered": {
            0: "Pass",
            1: "ERROR: Too few hours considered",
            2: "WARNING: Exceeds expected hours (possible worn-day mismatch)"
        },
        "Cleaning Code": {
            0: "Pass",
            1: "ERROR: Invalid cleaning code found",
            2: "WARNING: Missing (NaN) cleaning codes present"
        },
        "Valid Days": {
            0: "Pass",
            1: "ERROR: Fewer valid days than worn days",
            2: "WARNING: More valid days than worn days"
        }
    }

    for check, code in checks.items():
        print(f"{check}: Code {code} → {meanings[check][code]}")

    return checks

qc_results = run_qc_checks(cal_err, h_considered, clean_code, valid_days, n_days_worn)
















