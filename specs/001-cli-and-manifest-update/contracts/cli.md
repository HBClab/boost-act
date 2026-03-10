# CLI Contract: Manifest Reconciliation

## Command

```bash
python -m act.main --token "$BOOST_TOKEN" --daysago 1 --system vosslnx --reconcile-manifest-only
```

## Flags

- `--token` (required): RedCap API token.
- `--daysago` (required): integer days back for RDSS discovery; used for regular
  ingest and may be ignored by reconcile-only mode except for logging.
- `--system` (required): `vosslnx`, `vosslnxft`, `local`, or `argon`.
- `--rebuild-manifest-only` (optional): existing rebuild mode (no ingest).
- `--reconcile-manifest-only` (new): run reconciliation using existing
  `/home/zak/work/hbc/boost/act/act/res/data.json` and RDSS sources.

## Behavior

- Reconcile-only mode MUST NOT run GGIR, plotting, or copy new RDSS matches.
- Reconcile-only mode verifies each manifest record by comparing destination
  files to RDSS sources (size + SHA-256 when sizes match).
- On mismatch, the destination file is replaced with the RDSS source and logged.
- If RDSS source is missing, if destination is missing, or if a session
  directory contains multiple `_accel.csv` candidates, the run fails.

## Exit Codes

- `0`: all records verified or repaired successfully.
- `1`: one or more records failed verification or repair.

## Logging

- Each mismatch logs `subject`, `run`, `source`, and `destination` paths.
- Summary logs include counts of repaired/missing/mismatched records.
