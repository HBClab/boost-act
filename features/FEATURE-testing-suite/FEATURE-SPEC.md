# Feature Spec -> Testing Suite
---

## Goal
Create a reliable, Python-first testing and linting suite that protects the core BOOST pipeline behaviors (ingest, save/session ordering, and signatures) while keeping GGIR/R validation lightweight and out of primary CI gating.

## Project Intent (Constitution Alignment)
- Prioritize logic in `act/` Python modules (`main.py`, `utils/`, `core/gg.py`) as the main automation surface.
- Preserve deterministic output conventions (for example `sub-####_ses-#_accel.csv`) and session ordering behavior enforced by save logic.
- Keep tests safe for CI by avoiding hard dependencies on production mounts (`/mnt`) and live secrets.
- Use repo-standard tooling and style guidance (pytest for tests, flake8 linting, PEP 8 conventions).

## Scope
### In scope
- `pytest`-based suite for Python code across pipeline orchestration and utility modules.
- `flake8` lint checks for the Python codebase, explicitly excluding `E502`.
- Robust unit/integration tests for save/session edge cases.
- Reusable fixtures for signature logic and filesystem-heavy behaviors.
- GitHub Actions workflow on pull requests targeting `main`.

### Out of scope
- Full GGIR/R correctness validation as a required CI gate.
- Any CI trigger other than pull requests to `main`.
- Production filesystem writes or use of real REDCap tokens in CI.
- Do not write code that relies on mounts, these will not be available in CI - can be used for local testing, however.

## Functional Requirements
### 1) Test framework and layout
- Use `pytest` as the canonical test runner.
- Place tests under `act/tests/` using `test_*.py` naming.
- Organize by module concern (for example: `tests/utils/`, `tests/pipeline/`, `tests/save/`) while preserving existing repo patterns.

### 2) Python-first coverage
- Tests must primarily cover Python code paths.
- R scripts and GGIR internals are not required for high coverage and should be mocked/stubbed where invoked from Python.
- CI must enforce a minimum **90% Python coverage** for scoped, testable Python modules.

### 3) Save/session edge-case behavior
The suite must explicitly validate the save logic around session/date ordering, including at minimum:
- **Earlier-date insertion case**: if a newly discovered session date is earlier than current `ses-1`, existing sessions are renamed/re-indexed so ordering remains chronological.
- Session labels remain contiguous and deterministic after re-indexing.
- Output filenames and target paths preserve required naming conventions after renaming.
- Behavior is validated for both intervention and observational-style paths where applicable.

### 4) Signature fixtures
- Provide reusable fixtures for signature-related logic (input signatures, identity matching, or equivalent pipeline signature checks used in this repo).
- Fixtures must support both “known-good” and mismatch/edge scenarios.
- Fixture design should minimize duplication and be shareable across multiple test modules.

### 5) Linting
- Add/standardize `flake8` linting for project Python files.
- Configure lint checks to ignore `E502`.
- Linting failures block PR workflow success.

## CI/CD Requirements (GitHub Actions)
### Trigger policy
- Run CI on `pull_request` events targeting `main` only.

### Required PR checks
- Install dependencies and run `flake8` (with `E502` excluded).
- Run `pytest` with coverage and fail if below 90%.
- Run a **PR smoke e2e** test that exercises pipeline flow with mocked/local test inputs (no real mounts/secrets).

### E2E interpretation
- Within PR-only workflow policy, e2e is defined as a lightweight smoke integration path.
- A heavier full e2e may exist as non-required local/manual process, but it is not a required GitHub Actions trigger in this feature.

## Non-Functional Requirements
- Tests should be deterministic, parallel-safe where possible, and not depend on wall-clock timing.
- Use temporary directories and mocks rather than writing to real `/mnt` targets.
- Keep runtime practical for PR feedback (fast unit tests + one smoke e2e path).

## Acceptance Criteria
- A contributor can run lint + tests locally with documented commands and get identical pass/fail behavior to CI.
- PR to `main` fails when:
  - flake8 fails (except `E502`),
  - pytest fails,
  - coverage is `< 90%`, or
  - smoke e2e check fails.
- Save/session tests demonstrate verified renaming/re-indexing for earlier-date insertion.
- Signature fixtures are present and used by multiple tests.

## Suggested Local Commands
- `pytest -q --cov=act --cov-report=term-missing --cov-fail-under=90`

## Implementation Plan

***Checkpoint 1: Testing Scaffolding & Config***
- [x] Add/standardize pytest configuration in `pyproject.toml` for discovery under `act/tests/` and `test_*.py` patterns.
- [x] Add/standardize flake8 configuration in `pyproject.toml` (or `.flake8`) for project linting with `E501` ignored.
- [x] Add baseline test dependencies to `act/requirements.txt` (or documented dev install path) for `pytest`, coverage plugin, and linting tools.
- [x] A test: run local command parity check (`flake8` + `pytest --collect-only`) to confirm discovery/lint wiring works end-to-end.

***Checkpoint 2: Shared Fixtures & Test Utilities***
- [x] Create reusable fixtures in `act/tests/conftest.py` for temporary filesystem roots (no `/mnt` dependency).
- [x] Add fixture factories for representative subject/session file naming and path generation (`sub-####_ses-#_accel.csv`).
- [x] Add signature-oriented fixtures for known-good and mismatch edge cases, reusable across modules.
- [x] A test: add fixture sanity tests in `act/tests/test_fixtures.py` validating fixture outputs, determinism, and reuse.

***SKIPPING CHECKPOINT 3***

***Checkpoint 4: Additional Save Edge Cases***
- [x] Add tests for observational/intervention-style directory variants used by current save logic.
- [x] Add tests for duplicate-date/no-op behavior to ensure deterministic handling without accidental session drift.
- [x] Add error-path tests for partial write/rename failures using mocks to verify safe failure semantics.
- [x] A test: implement `test_save_edge_cases_matrix()` parameterized across path style and edge-case scenarios.

***Checkpoint 5: Pipeline Smoke Integration (Python-first e2e)***
- [ ] Add lightweight integration test(s) targeting Python orchestration path (`act/main.py` + `act/utils/pipe.py`) with external systems mocked.
- [ ] Stub GGIR/R boundaries (`act/core/gg.py` calls) so CI validates orchestration flow without full GGIR execution.
- [ ] Validate key outputs/logical side effects (manifest write, expected calls, and no mount dependence).
- [ ] A test: implement `test_pipeline_smoke_mocked_dependencies()` as PR smoke e2e gate.

***Checkpoint 6: CI Workflow on PR to main***
- [ ] Add GitHub Actions workflow under `.github/workflows/` triggered on `pull_request` to `main` only.
- [ ] Configure workflow jobs for lint (`flake8` with `E502` excluded), tests, and coverage fail-under 90%.
- [ ] Include smoke e2e test execution in required PR checks and keep runtime bounded for fast feedback.
- [ ] A test: validate workflow config with a PR dry run by intentionally failing/passing lint and test stages in separate commits.

***Checkpoint 7: Documentation & Contributor UX***
- [ ] Update `README.md` Testing & QA section with exact local commands and CI expectations.
- [ ] Document where fixtures live, how to add save-edge cases, and smoke e2e constraints (no real mounts/secrets).
- [ ] Add short contributor notes in `AGENTS.md`-aligned style for test naming and commit granularity.
- [ ] A test: run documented commands from a clean environment to confirm docs are executable and accurate.


