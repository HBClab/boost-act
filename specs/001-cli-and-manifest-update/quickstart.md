# Quickstart: Manifest Reconciliation

## Prereqs

- Python 3.11 with dependencies from
  `/home/zak/work/hbc/boost/act/act/requirements.txt`.
- RDSS mount available at the configured system path.
- `BOOST_TOKEN` in environment.

## Reconcile manifest against disk

```bash
export BOOST_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
python -m act.main --daysago 1 --token "$BOOST_TOKEN" --system vosslnx --reconcile-manifest-only
```

## Expected outcomes

- Logs indicate per-subject repairs or mismatches.
- Exit code `0` when all records verify or are repaired.
- Exit code `1` when reconciliation cannot complete due to missing sources,
  missing destinations, or ambiguous session contents.

## E2E validation (after full implementation)

```bash
pytest -q /home/zak/work/hbc/boost/act/act/tests/test_manifest_reconcile.py \
  /home/zak/work/hbc/boost/act/act/tests/test_save_manifest_reindex.py \
  /home/zak/work/hbc/boost/act/act/tests/test_pipeline_smoke.py
```
