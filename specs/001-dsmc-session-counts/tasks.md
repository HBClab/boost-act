---

description: "Task list for DSMC Session Counts feature implementation"
---

# Tasks: DSMC Session Counts

**Input**: Design documents from `/home/zak/work/hbc/boost/act/specs/001-dsmc-session-counts/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for any new or modified functions and must be
planned alongside implementation tasks.

**Organization**: Tasks are grouped by user story to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create DSMC module scaffold in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py` with module docstring and CLI entry point placeholder
- [X] T002 [P] Add DSMC test file scaffold in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`
- [X] T003 [P] Confirm pytest invocation documented in `/home/zak/work/hbc/boost/act/specs/001-dsmc-session-counts/quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Implement shared path/session parsing helpers in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T005 Implement logging setup aligned with `/home/zak/work/hbc/boost/act/code/main.py` in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T006 Implement CLI argument parsing (`--expected`, `--int-dir`, `--obs-dir`, `--out`) in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Generate session counts report (Priority: P1) 🎯 MVP

**Goal**: Produce actual session counts by scanning intervention and observational datasets

**Independent Test**: Run the report on a fixture dataset and confirm session counts match known totals, with skipped paths logged.

### Tests for User Story 1 (REQUIRED when adding or modifying functions) ⚠️

- [X] T007 [P] [US1] Add pytest fixtures for INT/OBS directory trees in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`
- [X] T008 [P] [US1] Add test for counting `_accel.csv` sessions and ignoring `accel/all` in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`
- [X] T009 [P] [US1] Add test for skipping pattern mismatches with logged warnings in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`

### Implementation for User Story 1

- [X] T010 [US1] Implement filesystem walk for actual counts across INT/OBS in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T011 [US1] Implement skip-and-log behavior for `accel/all` and pattern mismatches in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`

**Checkpoint**: User Story 1 is functional and testable independently

---

## Phase 4: User Story 2 - Compare actual to expected counts (Priority: P2)

**Goal**: Parse expected counts and compute proportions in the report

**Independent Test**: Provide an expected-counts CSV and verify expected values and proportions are correct, with missing/zero expected values left blank.

### Tests for User Story 2 (REQUIRED when adding or modifying functions) ⚠️

- [X] T012 [P] [US2] Add test for parsing single-row expected counts with valid headers in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`
- [X] T013 [P] [US2] Add test for skipping malformed/negative expected values with warnings in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`
- [X] T014 [P] [US2] Add test for missing/zero expected counts yielding blank proportions in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`

### Implementation for User Story 2

- [X] T015 [US2] Implement expected-counts CSV parsing in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T016 [US2] Implement report aggregation and proportion calculation in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T017 [US2] Implement missing expected/actual logging in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`

**Checkpoint**: User Stories 1 and 2 both work independently

---

## Phase 5: User Story 3 - Run as a standalone reporting utility (Priority: P3)

**Goal**: Run DSMC report independently of the main pipeline loop

**Independent Test**: Execute the module with CLI arguments and confirm it writes the CSV output without invoking pipeline steps.

### Tests for User Story 3 (REQUIRED when adding or modifying functions) ⚠️

- [X] T018 [P] [US3] Add test for CLI invocation writing output CSV in `/home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py`

### Implementation for User Story 3

- [X] T019 [US3] Implement CLI execution path in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`
- [X] T020 [US3] Implement default output path handling and overwrite behavior in `/home/zak/work/hbc/boost/act/code/dsmc_counts.py`

**Checkpoint**: All user stories are independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T021 [P] Update DSMC usage notes in `/home/zak/work/hbc/boost/act/specs/001-dsmc-session-counts/quickstart.md`
- [X] T022 Run pytest for DSMC tests and record command in `/home/zak/work/hbc/boost/act/specs/001-dsmc-session-counts/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Depends on actual counts from US1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Depends on CLI scaffolding from Phase 2

### Within Each User Story

- Tests MUST be written and fail before implementation
- Core parsing before aggregation
- Core implementation before CLI integration
- Story complete before moving to next priority

### Parallel Opportunities

- Setup tasks marked [P] can run in parallel
- Foundational tasks are sequential due to shared module edits
- Within each user story, [P] test tasks can run in parallel
- US2 and US3 can start after US1 if separate owners are available

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Add pytest fixtures for INT/OBS directory trees in /home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py"
Task: "Add test for counting _accel.csv sessions and ignoring accel/all in /home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py"
Task: "Add test for skipping pattern mismatches with logged warnings in /home/zak/work/hbc/boost/act/code/tests/test_dsmc_counts.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deliver MVP
3. Add User Story 2 → Test independently → Deliver
4. Add User Story 3 → Test independently → Deliver
5. Each story adds value without breaking previous stories
