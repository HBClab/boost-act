---

description: "Task list for manifest reconciliation fix"
---

# Tasks: Manifest Reconciliation for Canonical Session Files

**Input**: Design documents from `/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- Paths shown below are adapted to `/home/zak/work/hbc/boost/act/act/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Minimal scaffolding to support reconciliation work

- [ ] T001 Add CLI flag placeholder and help text for `--reconcile-manifest-only` in `/home/zak/work/hbc/boost/act/act/main.py`
- [ ] T002 Document reconciliation mode usage and constraints in `/home/zak/work/hbc/boost/act/README.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities required before any story work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Add file identity helpers (size + SHA-256) in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T004 Add session directory CSV candidate validation helper in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T005 Define reconcile report structure and aggregation helpers in `/home/zak/work/hbc/boost/act/act/utils/save.py`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Reconcile manifest vs disk (Priority: P1) 🎯 MVP

**Goal**: As an operator, I can run a reconcile-only mode that verifies and
repairs on-disk `ses-*` files to match canonical manifest records.

**Independent Test**: Run `python -m act.main --reconcile-manifest-only` against
fixtures or a sandbox mount and verify summary logs + exit code behavior.

### Implementation for User Story 1

- [ ] T006 [US1] Implement manifest reconciliation pass using `res/data.json` in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T007 [US1] Replace mismatched destination files with RDSS sources using atomic copy in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T008 [US1] Surface reconcile summary and exit code handling in `/home/zak/work/hbc/boost/act/act/main.py`
- [ ] T009 [US1] Route reconcile-only mode through the pipeline in `/home/zak/work/hbc/boost/act/act/utils/pipe.py`

**Checkpoint**: User Story 1 is functional and can run as a standalone
operator command

---

## Phase 4: User Story 2 - Harden rename/reindex against ambiguous sessions (Priority: P2)

**Goal**: As an operator, I can trust reindex operations to fail fast when
session folders are ambiguous or destination files do not match expected
identity.

**Independent Test**: Run reindex flows that contain multiple `_accel.csv` files
per session and verify the operation fails with clear logs.

### Implementation for User Story 2

- [ ] T010 [US2] Fail fast when multiple `_accel.csv` files exist in a session directory in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T011 [US2] Verify destination file identity before skip/rename in `/home/zak/work/hbc/boost/act/act/utils/save.py`
- [ ] T012 [US2] Update log messages to include subject/run/source/destination identifiers in `/home/zak/work/hbc/boost/act/act/utils/save.py`

**Checkpoint**: User Stories 1 AND 2 work independently with explicit failure
signals for ambiguous session contents

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final alignment and documentation

- [ ] T013 Update operator runbook and examples for reconcile-only mode in `/home/zak/work/hbc/boost/act/README.md`
- [ ] T014 Ensure quickstart reflects reconcile-only usage in `/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/quickstart.md`
- [ ] T015 Run E2E validation after full implementation (documented command) in `/home/zak/work/hbc/boost/act/specs/001-cli-and-manifest-update/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational phase completion
- **User Story 2 (P2)**: Depends on Foundational phase completion and benefits from US1 helpers

### Within Each User Story

- Core helpers before reconcile/rename behavior changes
- CLI routing after reconciliation logic is in place
- Story complete before moving to next priority

### Parallel Opportunities

- T001 and T002 can run in parallel
- T003, T004, and T005 can run in parallel (same file but separable functions)
- T010 and T011 can run in parallel (independent edits in `/home/zak/work/hbc/boost/act/act/utils/save.py`)

---

## Parallel Example: User Story 1

```bash
Task: "Implement manifest reconciliation pass in /home/zak/work/hbc/boost/act/act/utils/save.py"
Task: "Replace mismatched destination files with RDSS sources in /home/zak/work/hbc/boost/act/act/utils/save.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run reconcile-only mode and confirm exit behavior

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Validate reconcile-only mode
3. Add User Story 2 → Validate reindex behavior
4. Final polish and runbook updates
