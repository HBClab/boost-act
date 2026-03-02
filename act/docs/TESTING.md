# TESTING.md

Testing guidance for BOOST Actigraphy Python changes.

## Scope
- Primary automated coverage targets Python orchestration and utility paths in `act/`.
- GGIR/R is not required for PR smoke checks and should be mocked/stubbed in tests.
- CI-safe tests must avoid live mounts, production data paths, and real API tokens.

## Local Commands
Run these from repo root:

```bash
flake8 act/tests act/main.py act/utils/pipe.py act/utils/comparison_utils.py
pytest -q --cov=act.utils.pipe --cov-report=term-missing --cov-fail-under=90
pytest -q act/tests/test_pipeline_smoke.py::test_pipeline_smoke_mocked_dependencies
```

If you use the local nix environment:

```bash
nix develop
flake8 act/tests act/main.py act/utils/pipe.py act/utils/comparison_utils.py
pytest -q --cov=act.utils.pipe --cov-report=term-missing --cov-fail-under=90
pytest -q act/tests/test_pipeline_smoke.py::test_pipeline_smoke_mocked_dependencies
```

## CI Expectations
- Workflow file: `.github/workflows/pr-testing-suite.yml`.
- Trigger: `pull_request` to `main` only.
- Required jobs:
  - `lint`
  - `test` (coverage fail-under 90 on scoped modules)
  - `smoke-e2e`

## Test Layout
- Put tests in `act/tests/` and name files `test_*.py`.
- Prefer deterministic unit/integration tests over notebook-driven checks for CI.
- Keep test data small and explicit.

## Shared Fixtures
- Shared fixtures live in `act/tests/conftest.py`.
- Current fixture groups:
  - Temporary roots for `int`, `obs`, and `rdss` paths.
  - Filename/path factories for `sub-####_ses-#_accel.csv`.
  - Signature example fixtures for known-good and mismatch cases.
- Reuse existing fixtures before creating new ones to reduce duplication.

## Save Edge Cases
When adding save logic tests:
- Use temporary directories (`tmp_path`) and local fixture roots.
- Cover both path styles:
  - intervention (`int`)
  - observational (`obs`)
- Validate deterministic session outputs:
  - session numbers stay contiguous for the tested scenario
  - generated file names follow `sub-####_ses-#_accel.csv`
  - destination paths include expected `accel/ses-#` structure
- For error paths, mock file operations (for example `shutil.copy`) and assert graceful continuation or expected failure semantics.

## Manifest Reindex Testing
Manifest-only session reindex tests live in:
- `act/tests/test_save_manifest_reindex.py`
- `act/tests/test_save_edge_cases.py`

Use these focused commands during development:

```bash
pytest --collect-only -q act/tests/test_save_manifest_reindex.py
pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py
```

Expected behaviors covered by this suite:
- append: incoming session later than existing history receives the next dense run.
- backfill: incoming earlier session inserts chronologically and shifts later runs.
- tie-date skip: same-date subject conflicts are skipped with no manifest/filesystem mutation.
- duplicate noop: repeat ingest of the same `(labID, date, filename)` does not drift runs.

## Operator Guidance
- `res/data.json` is the canonical source of truth for session run ordering.
- Current design assumes single-writer ingest semantics for `res/data.json`.
- Manual edits to `res/data.json` can force session reindex/rename behavior on the next run.
- If manual edits are necessary, run the manifest-focused tests above before production ingest.

### Manifest Rebuild-Only Operations
- CLI mode: `--rebuild-manifest-only`.
- Rebuild mode skips ingest copy/rename, GGIR, and plotting.
- Rebuild mode still requires a valid RedCap token because subject→lab mapping is enforced.
- Rebuild exits non-zero on strict failures:
  - multi-candidate session CSVs in a single `ses-*` folder,
  - missing RedCap subject mapping,
  - missing RDSS metadata for any discovered LSS session.

Linux (venv) example:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r act/requirements.txt
python -m act.main --daysago 1 --token "$BOOST_TOKEN" --system local --rebuild-manifest-only
```

NixOS example:

```bash
nix develop
python -m act.main --daysago 1 --token "$BOOST_TOKEN" --system vosslnx --rebuild-manifest-only
```

Checkpoint-8 validation commands:

```bash
pytest --collect-only -q act/tests/test_manifest_rebuild_from_lss.py
pytest -q act/tests/test_manifest_rebuild_from_lss.py act/tests/test_pipeline_smoke.py
```

## Smoke E2E Constraints
- Smoke tests must stay Python-only and fast.
- Mock external boundaries:
  - REDCap-dependent ingest calls
  - GGIR/R invocation paths
  - filesystem cleanup paths when needed
- Do not require:
  - `/mnt` or network storage mounts
  - real REDCap tokens
  - full GGIR execution

## Contributor Notes
AGENTS-aligned expectations:
- Keep commit subjects short and present tense.
- Keep test commits focused by checkpoint or behavior slice.
- Name tests by behavior (`test_<unit>_<expected_outcome>`).
- Add one clear assertion group per behavior being guarded.
- Run local lint/tests before opening a PR to keep CI feedback focused on regressions.
