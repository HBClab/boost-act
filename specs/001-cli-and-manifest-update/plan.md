# Implementation Plan: Manifest Reconciliation for Canonical Session Files

**Branch**: `001-cli-and-manifest-update` | **Date**: 2026-03-10 | **Spec**: `/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/spec.md`
**Input**: Feature specification from `/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/spec.md` and `/home/zak/work/hbc/boost/act/features/FEATURE-cli-and-manifest-update/FIXES.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `/home/zak/work/hbc/boost/act/.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a manifest-driven reconciliation mode that verifies and repairs on-disk
`ses-*` CSV contents against canonical manifest records, addressing cases where
`res/data.json` is correct but disk contents are stale or mismatched. Harden the
rename/reindex path to fail on ambiguous session contents, add identity checks
for destination files, and expose a CLI entrypoint for reconciliation without
new RDSS matches. Tests must cover pre-existing drift, destination mismatch,
multi-candidate session folders, and idempotency.

## Technical Context

**Language/Version**: Python 3.11  
**Primary Dependencies**: pandas, requests, pytest, pytest-cov, flake8 (no new deps)  
**Storage**: Filesystem (RDSS/LSS), JSON manifest at `/home/zak/work/hbc/boost/act/act/res/data.json`  
**Testing**: pytest (plus pytest-cov), flake8  
**Target Platform**: Headless Linux (vosslnx/vosslnxft/local/argon)  
**Project Type**: CLI-driven data pipeline  
**Performance Goals**: Correctness-first batch processing; acceptable runtime for
per-subject reconciliation in operator runs  
**Constraints**: No new heavy dependencies; avoid `/mnt` writes in tests; use
`logging`; preserve canonical file naming  
**Scale/Scope**: Single-repo pipeline; per-subject operations over hundreds to
low-thousands of sessions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Confirm checkpoint plan is commit-sized, independently unit-testable, and will
  run the current test suite at each checkpoint.
- Ensure test strategy reflects real data shapes/workflows and includes edge
  cases likely to occur in production.
- Schedule E2E validation after full implementation of the change set.
- Justify any new dependencies; prefer existing libraries and stdlib.

**Gate Status**: PASS. Plan includes unit tests per checkpoint, no new
dependencies, and E2E validation after implementation.

## Project Structure

### Documentation (this feature)

```text
/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

### Source Code (repository root)

```text
/home/zak/work/hbc/boost/act/act/
├── main.py
├── utils/
│   ├── pipe.py
│   ├── save.py
│   └── (optional) reconcile.py
└── tests/
    ├── test_manifest_rebuild_from_lss.py
    ├── test_save_manifest_reindex.py
    └── (new) test_manifest_reconcile.py
```

**Structure Decision**: Single Python package under `/home/zak/work/hbc/boost/act/act/`
with tests in `/home/zak/work/hbc/boost/act/act/tests/`.

## Constitution Check (Post-Design)

**Status**: PASS. Design keeps dependencies unchanged, adds unit tests for edge
cases, and schedules E2E validation after full implementation.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A
