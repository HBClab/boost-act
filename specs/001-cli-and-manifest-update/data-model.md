# Data Model: Manifest Reconciliation

## Entity: Manifest
- **Type**: `dict[str, list[ManifestRecord]]`
- **Description**: Canonical subject records loaded from
  `/home/zak/work/hbc/boost/act/act/res/data.json`.

## Entity: ManifestRecord
- **Fields**:
  - `subject_id` (str) — subject key, derived from manifest key.
  - `run` (int) — canonical session/run index.
  - `study` (str) — `int` or `obs`.
  - `filename` (str) — RDSS source filename (e.g., `1330 (2025-05-28)RAW.csv`).
  - `date` (str) — normalized date string (`YYYY-MM-DD`).
  - `labID` (str) — lab identifier from RedCap/RDSS.
  - `file_path` (str) — canonical LSS destination path for the session CSV.
- **Validation rules**:
  - `run` must be an integer >= 1.
  - `study` must be `int` or `obs`.
  - `filename` and `file_path` must be non-empty strings.

## Entity: ReconcileItem
- **Fields**:
  - `subject_id` (str)
  - `run` (int)
  - `expected_source` (str) — absolute RDSS path derived from `filename`.
  - `destination` (str) — canonical LSS path from `file_path`.
  - `size_match` (bool)
  - `hash_match` (bool)
  - `status` (str) — `ok`, `repaired`, `missing_source`, `missing_dest`,
    `ambiguous_dest`, or `mismatch_failed`.

## Entity: ReconcileReport
- **Fields**:
  - `total_records` (int)
  - `repaired` (int)
  - `mismatched` (int)
  - `missing_source` (int)
  - `missing_dest` (int)
  - `ambiguous_dest` (int)
  - `errors` (list[str]) — human-readable failure summaries.
- **Notes**: Returned by the reconciliation pass and used to determine exit code.
