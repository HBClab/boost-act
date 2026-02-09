# DSMC Feature Implementation Roadmap
---

## Goals
---
- Need to quantify how many participants have data for each session - quantifying the number of participants with data for each session.
    - this should be reported in a csv by session with counts
- Need to quantify proportion of expected by obtaining expected counts for each session (manual procedure outputted into a csv) and then cross ref with returned counts of existing data

## Implementation Plan
---
- Build standalone module `code/dsmc_counts.py`; no integration into the main pipeline; share directory conventions used in `code/utils/save.py`.
- Expected input: manual CSV with headers `ses-1, ses-2, ...` and a single numeric row; parse to `{session: expected_count}`, skipping malformed/negative values with warnings.
- Actual counts: walk `INT_DIR` and `OBS_DIR` trees; count subjects per session when `_accel.csv` exists under `sub-####/accel/ses-#/sub-####_ses-#_accel.csv`; ignore `accel/all` and pattern mismatches, log skips.
- Aggregation: union of sessions; emit `session, actual_count, expected_count, proportion` (blank if expected missing/zero) plus log flags for missing expected/actual.
- Output: write CSV to repo root (`./dsmc_session_counts.csv` by default); overwrite allowed; logging uses the same style as `code/main.py`; follow “skip and log” error policy.
- CLI: argparse entry in module (`--expected`, `--int-dir`, `--obs-dir`, `--out`) to run independently.
- Tests: add `code/tests/test_dsmc_counts.py` with temp dirs to cover expected parsing, ignoring `accel/all`, proportion with missing expected, and malformed header handling.

