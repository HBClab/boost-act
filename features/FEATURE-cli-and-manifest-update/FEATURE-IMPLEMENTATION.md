# Feature Implementation Plan -> CLI Modernization + Rebuild Manifest from LSS

> AGENTS:
> Complete each step one at a time and run tests before completion. Upon completion, mark each checkbox as complete and add small notes for future checkpoints only if needed.

***Checkpoint 1: CLI Parser Foundation (`argparse`)***
- [x] Replace ad-hoc `sys.argv` parsing in `act/main.py` with a typed `argparse` parser.
- [x] Preserve required inputs (`token`, `daysago`, `system`) with explicit validation and help text.
- [x] Add new mode flag plumbing for `--rebuild-manifest-only` (parse-only wiring; no behavior switch yet).
- [x] A test: extend `act/tests/test_pipeline_smoke.py` with parser/entrypoint argument validation cases (valid + invalid invocations).

Checkpoint note: CLI now uses explicit required flags (`--token`, `--daysago`, `--system`) and carries `--rebuild-manifest-only` into `Pipe` without mode switching yet.

***Checkpoint 2: Mode Routing in Pipeline***
- [x] Add mode-aware execution path in `act/utils/pipe.py` so normal mode and `--rebuild-manifest-only` branch cleanly.
- [x] Ensure manifest-only mode skips GGIR and plotting calls while preserving existing behavior in default mode.
- [x] Keep system-path resolution unchanged and shared between modes.
- [x] A test: extend `act/tests/test_pipeline_smoke.py` to assert GGIR/plot are not invoked when manifest-only is active.

Checkpoint note: `Pipe.run_pipe()` now skips GGIR in manifest-only mode, and `act.main` skips plotting when `--rebuild-manifest-only` is set.

***Checkpoint 3: LSS Session Discovery Engine***
- [x] Implement LSS scanner in `act/utils/save.py` (or a focused helper module) to discover `sub-*/accel/ses-*` session CSVs from configured `INT_DIR`/`OBS_DIR`.
- [x] Derive `subject_id`, `study`, and `run` strictly from folder layout (`ses-# -> run=#`).
- [x] Enforce single-candidate-session rule: if multiple candidate accel CSVs exist in a session folder, register subject conflict.
- [x] A test: add `act/tests/test_manifest_rebuild_from_lss.py` with fixtures that validate discovery and multi-CSV conflict detection.

Checkpoint note: Added `Save.discover_lss_sessions()` returning `(discovered, conflicts)` with strict `ses-#` parsing and multi-candidate session conflict reporting.

***Checkpoint 4: RedCap Subject→Lab Mapping Layer***
- [x] Add a reusable mapping fetch path from RedCap report to resolve `subject_id -> labID` for discovered LSS subjects.
- [x] Handle missing subject mappings as strict rebuild errors (no partial write).
- [x] Ensure mapping logic is isolated for direct unit testing (no filesystem side effects).
- [x] A test: add mapping unit tests in `act/tests/test_manifest_rebuild_from_lss.py` using monkeypatched report responses for found/missing subjects.

Checkpoint note: Added `Save._fetch_redcap_subject_lab_rows()` and `Save.resolve_subject_lab_mapping()` with strict missing-subject failure and direct monkeypatch-friendly tests.

***Checkpoint 5: RDSS Metadata Resolution Layer***
- [x] Implement RDSS lookup that resolves required metadata (`filename`, `labID`, `date`) for each discovered LSS session.
- [x] Treat unresolved metadata as strict failure for rebuild mode.
- [x] Keep RDSS as enrichment-only (must not create manifest rows absent on LSS).
- [x] A test: add success/failure lookup tests in `act/tests/test_manifest_rebuild_from_lss.py` covering complete resolution and unresolved metadata failure.

Checkpoint note: Added `Save._list_rdss_metadata_rows()` and `Save.resolve_rdss_session_metadata()`; resolver enriches only LSS-discovered sessions and raises on unresolved run-level metadata.

***Checkpoint 6: Manifest Rebuild Assembly + Strict Error Model***
- [x] Assemble canonical manifest payload from LSS-discovered sessions enriched by RedCap/RDSS.
- [x] Produce deterministic ordering by subject and run for stable output.
- [x] Aggregate subject-level errors and fail command when any strict conflict exists.
- [x] A test: add end-to-end rebuild unit tests in `act/tests/test_manifest_rebuild_from_lss.py` for deterministic output and strict fail-on-error behavior.

Checkpoint note: Added `Save.rebuild_manifest_payload_from_lss()` with deterministic subject/run ordering and aggregated strict subject-level conflicts across LSS discovery, RedCap mapping, and RDSS metadata resolution.

***Checkpoint 7: Atomic Manifest Write + Exit Semantics***
- [x] Implement atomic write (`temp -> fsync -> replace`) for `res/data.json` in rebuild mode.
- [x] Guarantee prior manifest remains unchanged on failure.
- [x] Return non-zero exit from CLI when rebuild conflicts/errors occur.
- [x] A test: add write-safety and exit-code assertions in `act/tests/test_pipeline_smoke.py` and `act/tests/test_manifest_rebuild_from_lss.py`.

Checkpoint note: Rebuild mode now uses `Save._atomic_write_manifest()` and `main()` returns exit code `1` on strict rebuild `ValueError`; tests cover non-zero exit and manifest preservation when replace fails.

***Checkpoint 8: Documentation + Operator Runbook***
- [x] Update feature docs and operator guidance for new CLI usage and `--rebuild-manifest-only` behavior.
- [x] Document strict-failure conditions (multi-CSV session, missing RedCap mapping, missing RDSS metadata).
- [x] Add example commands for NixOS and generic Linux execution contexts.
- [x] A test: validate docs commands via `pytest --collect-only -q act/tests/test_manifest_rebuild_from_lss.py` and targeted run `pytest -q act/tests/test_manifest_rebuild_from_lss.py act/tests/test_pipeline_smoke.py`.

Checkpoint note: Updated README + TESTING runbook for new flag-based CLI and rebuild-only strict-failure semantics; targeted test run for documented files passed (`20 passed`).
