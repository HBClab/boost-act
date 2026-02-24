# Feature Implementation Plan -> Manifest-Only Session Reindexing

> AGENTS:
> Complete each step one at a time and run tests before completion. Upon completion, mark each checkbox as complete and add small notes for future checkpoints only if needed.

***Checkpoint 1: Manifest IO Foundation***
- [x] Add manifest path handling in `act/utils/save.py` (default to `res/data.json`) with `_load_manifest(path)` and `_save_manifest(path)` helpers.
- [x] Normalize loaded payload structure to `dict[str, list[dict]]` and guard missing/corrupt file with safe fallback to `{}` + warning log.
- [x] Wire manifest load into `Save.save()` before run assignment and keep in-memory manifest state for the ingest cycle.
- [x] A test: add `test_load_manifest_missing_file_returns_empty` and `test_load_manifest_roundtrip` in `act/tests/test_save_manifest_reindex.py`.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (7 passed).

***Checkpoint 2: Subject Merge + Dedup Core***
- [x] Implement `_reindex_subject_records(existing_records, incoming_records)` in `act/utils/save.py` to merge by subject and dedupe by `(labID, date, filename)`.
- [x] Add datetime normalization helper for incoming/existing date values (including ISO strings currently stored in manifest).
- [x] Ensure dedupe is idempotent so repeated ingest of the same RDSS rows produces no new logical sessions.
- [x] A test: add `test_exact_duplicate_key_noop` and `test_idempotent_rerun_no_session_drift` in `act/tests/test_save_manifest_reindex.py`.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (9 passed).

***Checkpoint 3: Chronological Ordering + Tie Conflict Policy***
- [x] Add `_subject_sort_key(record)` and strict ordering by date ascending for each subject.
- [x] Implement `_detect_same_date_conflict(records)` to detect duplicate dates within a subject across merged records.
- [x] Enforce skip policy on tie-date conflict (`warning` + no filesystem operations + no manifest mutation for that subject).
- [x] A test: add `test_same_date_conflict_warns_and_skips_subject` in `act/tests/test_save_manifest_reindex.py` and extend `act/tests/test_save_edge_cases.py` with a subject-skip assertion.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (10 passed).

***Checkpoint 4: Run Reindex Assignment Engine***
- [x] Replace date-only `_determine_run` logic with manifest-aware subject reindex that assigns dense runs `1..n` after canonical sort.
- [x] Handle three required flows: new subject defaults to `run=1`, later-date append behavior, and earlier-date insertion with run shifts.
- [x] Propagate reconciled runs to downstream location generation so `_determine_location` reflects final run mapping.
- [x] A test: add `test_new_subject_defaults_to_run_one`, `test_later_date_appends_next_run`, and `test_earlier_date_backfill_reindexes_and_shifts_runs` in `act/tests/test_save_manifest_reindex.py`.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (13 passed).

***Checkpoint 5: Two-Phase Rename Planning***
- [x] Add `_plan_subject_renames(subject_id, study, old_records, new_records)` to compute impacted `ses-*` file/directory moves.
- [x] Add `_apply_two_phase_renames(rename_plan)` using temporary paths to avoid name collisions during upward/downward session shifts.
- [x] Ensure rename plan is no-op when runs are unchanged and only touches subject/session paths in that subject’s study tree.
- [x] A test: add `test_two_phase_rename_avoids_collision` in `act/tests/test_save_manifest_reindex.py` using on-disk fixtures under temp roots.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (14 passed).

***Checkpoint 6: Subject Transaction Safety***
- [x] Execute per-subject flow as transaction-like sequence: compute plan -> rename -> copy new files -> in-memory manifest update.
- [x] On rename/copy failure, roll back temporary moves where possible and skip manifest mutation for that subject.
- [x] Emit structured logs (`append_latest`, `backfill_reindex`, `skip_tie_date`, `noop_duplicate`, `rename_failed`) via `logging` in `act/utils/save.py`.
- [x] A test: add `test_subject_failure_does_not_mutate_manifest` in `act/tests/test_save_manifest_reindex.py` with monkeypatched rename/copy failure.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py act/tests/test_pipeline_smoke.py` (17 passed).

***Checkpoint 7: Save Flow Integration + Regression Coverage***
- [x] Integrate manifest reindex output into existing `Save.save()` flow without breaking `_determine_study`, `_determine_location`, and `_move_files` behavior.
- [x] Update or extend fixtures in `act/tests/conftest.py`: `manifest_factory`, `rdss_record_factory`, and `subject_tree_factory`.
- [x] Extend `act/tests/test_save_edge_cases.py` for manifest-driven run stability and gap-shift behavior in both `int` and `obs` study roots.
- [x] A test: run targeted suite `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` and confirm all new checkpoints are covered.

Checkpoint note: Completed on 2026-02-24 with targeted verification via `pytest -q act/tests/test_save_manifest_reindex.py act/tests/test_save_edge_cases.py` (19 passed).

***Checkpoint 8: Documentation + Operator Guidance***
- [ ] Update `act/docs/TESTING.md` with manifest-only reindex test commands and expected behaviors (append, backfill, tie-date skip).
- [ ] Add a short operational note on single-writer assumption and the impact of manual edits to `res/data.json`.
- [ ] Document where checkpoint tests live and how to run only manifest-reindex tests during development.
- [ ] A test: validate docs commands from a clean venv using `pytest --collect-only` for the new module and targeted test run for updated modules.
