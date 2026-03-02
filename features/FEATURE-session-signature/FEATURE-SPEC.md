# Feature Spec -> Manifest-Only Session Reindexing

## Goal
Use `res/data.json` as the single source of truth for run assignment so transfers and backfills keep subject sessions dense, chronological, and deterministic.

## Problem recap (current behavior)
- `Save._determine_run` in `act/utils/save.py` currently assigns `run=1..n` from incoming batch dates only.
- It does not preload existing subject history from `res/data.json` before assigning runs.
- When a backfilled older session arrives after newer sessions were already transferred, the current logic can place it at the wrong run or skip movement due to path collisions.

## Scope and source of truth
- Canonical run history is manifest-only: `res/data.json`.
- No content signatures are used.
- Filesystem state is operational output; run ordering decisions are made from manifest + incoming RDSS rows.
- The ingest process must update manifest and filesystem together in one ordered reindex flow.

## Final conflict-resolution rules (resolved)

### 1) Per-subject canonical ordering
- Build candidate session list for each subject from:
  1. Existing subject entries in `res/data.json`.
  2. Newly discovered RDSS entries for that subject.
- Deduplicate exact repeats by key `(labID, date, filename)`.
- Sort strictly by `date` ascending.
- Date tie policy: if two or more sessions for the same subject have the same date, **emit warning and skip the entire subject for this ingest run** (no renames, no copies, no manifest mutation for that subject).

### 2) Run assignment and default behavior
- After sort, assign dense runs `1..n`.
- If a subject is entirely new (no manifest entries), first valid incoming session defaults to `run=1`.
- If incoming date is later than existing latest date, it receives the next run (`last_run + 1`) after canonical reindex.
- If incoming date is earlier than one or more existing dates, insert into chronological position and shift later runs by +1 through full reindex.

### 3) Backfill rename mechanism (required)
- Reindexing that changes any existing run must rename paths in both studies as needed.
- Use **two-phase temp renames** to avoid collision:
  1. Move all impacted existing files/directories from final names to temporary names.
  2. Move temporary names to final `ses-*` names for new run indices.
- Only after rename phase succeeds for subject, place any newly copied RDSS file(s).
- If rename fails at any step, abort that subject and do not mutate its manifest entries.

### 4) Manifest update guarantees
- Update `res/data.json` only after subject filesystem operations succeed.
- Subject-level atomicity target:
  - Success: filesystem and manifest both reflect new run map.
  - Failure: neither is partially advanced for that subject.
- Persist deterministic ordering in manifest arrays by run ascending.

### 5) Determinism and idempotence
- Re-running ingest with the same RDSS payload must not create duplicate manifest entries.
- Re-running ingest with no new sessions must produce no renames and no run drift.

## Algorithm (manifest-only)
For each subject in union(manifest subjects, incoming subjects):
1. Load existing manifest entries for subject.
2. Normalize incoming date values to ISO-compatible datetime.
3. Build deduped union by `(labID, date, filename)`.
4. If same-date collision exists within subject, warn and skip subject.
5. Produce new canonical run map by date order.
6. Compute run delta against existing manifest map.
7. If delta affects existing files, execute two-phase temp rename plan.
8. Copy newly added RDSS sessions into final session locations.
9. Write updated subject entries back to in-memory manifest.
10. After all subjects processed, persist `res/data.json`.

## Required code changes (exact files)

### Primary implementation
- `act/utils/save.py`
  - Replace date-only `_determine_run` behavior with manifest-aware reindex logic.
  - Add helpers:
    - `_load_manifest(path)` / `_save_manifest(path)`
    - `_subject_sort_key(record)`
    - `_detect_same_date_conflict(records)`
    - `_reindex_subject_records(existing_records, incoming_records)`
    - `_plan_subject_renames(subject_id, study, old_records, new_records)`
    - `_apply_two_phase_renames(rename_plan)`
  - Update save flow so run determination happens after manifest load and before location finalization.
  - Ensure `_determine_location` uses reconciled `run` values from canonical reindex.

### Optional logging enhancements
- `act/utils/save.py`
  - Emit structured logs for subject actions: `append_latest`, `backfill_reindex`, `skip_tie_date`, `noop_duplicate`, `rename_failed`.

## Tests and fixtures (exact files)

### Update fixtures
- `act/tests/conftest.py`
  - Add `manifest_factory` fixture to seed per-test `res/data.json` payloads.
  - Add `rdss_record_factory` fixture to generate incoming session rows.
  - Add `subject_tree_factory` fixture to create existing `sub-*/accel/ses-*` files for rename tests.

### Add new test module
- `act/tests/test_save_manifest_reindex.py`
  - `test_new_subject_defaults_to_run_one`
  - `test_later_date_appends_next_run`
  - `test_earlier_date_backfill_reindexes_and_shifts_runs`
  - `test_two_phase_rename_avoids_collision`
  - `test_exact_duplicate_key_noop`
  - `test_same_date_conflict_warns_and_skips_subject`
  - `test_subject_failure_does_not_mutate_manifest`
  - `test_idempotent_rerun_no_session_drift`

### Extend existing edge-case tests
- `act/tests/test_save_edge_cases.py`
  - Add assertions for manifest-driven run stability.
  - Add subject skip assertion for same-date conflicts.

## Acceptance criteria
- Incoming later-date session for existing subject is assigned next run and copied to new `ses-(n+1)` path.
- Incoming earlier-date session inserts into correct position; later sessions are renamed upward and manifest is rewritten with dense chronological runs.
- New subject with first session gets `run=1`.
- Same-date per-subject conflicts are warned and skipped with no side effects.
- Duplicate ingest events (same `(labID, date, filename)`) do not create extra runs.
- Manifest and filesystem remain aligned after each successful subject update.

## Out of scope
- Signature/content hashing.
- Reconciling manual filesystem edits not represented in manifest.
- Cross-subject conflict handling.

## Implementation notes
- This design assumes single-writer ingest semantics for `res/data.json`.
- If concurrent writers are introduced later, add file locking around manifest read/write and subject transactions.
