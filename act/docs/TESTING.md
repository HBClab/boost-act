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
