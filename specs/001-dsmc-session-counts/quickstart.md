# Quickstart: DSMC Session Counts

**Date**: 2026-02-10
**Spec**: /home/zak/work/hbc/boost/act/specs/001-dsmc-session-counts/spec.md

## Purpose

Generate a DSMC session-level counts report without invoking the main pipeline
loop. The report scans observational and intervention datasets, compares to
expected counts, and writes a CSV summary.

## Prerequisites

- Python 3.11 environment
- Dependencies installed from `/home/zak/work/hbc/boost/act/code/requirements.txt`
- Access to the intervention and observational dataset roots
- Optional: expected counts CSV with headers `ses-1, ses-2, ...`

## Inputs

- **Intervention root**: absolute path to INT_DIR
- **Observational root**: absolute path to OBS_DIR
- **Expected counts CSV** (optional): absolute path to manual CSV
- **Output CSV** (optional): defaults to `/home/zak/work/hbc/boost/act/dsmc_session_counts.csv`

## Run (standalone)

```bash
python /home/zak/work/hbc/boost/act/code/dsmc_counts.py \
  --int-dir /path/to/INT_DIR \
  --obs-dir /path/to/OBS_DIR \
  --expected /path/to/expected_counts.csv \
  --out /home/zak/work/hbc/boost/act/dsmc_session_counts.csv
```

## Expected Output

- CSV with columns: `session, actual_count, expected_count, proportion`
- Logs follow the same formatting rules as `/home/zak/work/hbc/boost/act/code/main.py`
- Skipped files (pattern mismatches, `accel/all`) are logged and ignored

## Tests

Run DSMC tests with:

```bash
pytest /home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py
```

Last run: 2026-02-10 (all tests passed).
