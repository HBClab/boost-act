## Session fingerprint reconciliation progress

Pipeline context (from `README.md`): ingest matches from REDCap + RDSS, map to `sub-####_ses-#_accel.csv`, copy into LSS tree, run GGIR + QC, and write `code/res/data.json` plus logs. The current bug is in `Save._determine_run` assigning runs purely by date without reconciling existing sessions.

### Progress so far (based on `determine_run_fix.md` + recent commits)
- Signature helpers added in `code/utils/save.py`:
  - `_peek_signature(path, n_lines=8)` hashes first lines without full reads.
  - `_signature_key(meta)` builds `(size_bytes, mtime, head_hash)` tuples.
- Signature ledger implemented:
  - `_build_signature_maps()` walks `INT_DIR`/`OBS_DIR` for existing session CSVs.
  - Returns `subject -> session -> signature` and `subject -> signature -> session` maps.
- TSV audit plumbing added:
  - `_signature_tsv_path()` targets `logs/session_fingerprint.tsv`.
  - `_load_signature_tsv()` and `_append_signature_tsv()` for read/append with header handling.
- Logging cleanup done ahead of larger refactor.
- Tests added/updated for helper/ledger/TSV pieces (per commit messages).
- Subject-batched `_determine_run` now computes proposed ranks, reuses sessions when signatures match filesystem/TSV, and flags unmatched records for gap-fill.
- Added tests for signature reuse, re-rank when signature maps to a different session, and unmatched pending behavior.
- Added TSV conflict bumping in `_determine_run` plus a unit test for rank conflicts against prior TSV history.
- Updated roadmap requirement: when a newer TSV entry conflicts with an older incoming file, sessions must be reassigned so chronological order wins (older file takes earlier session), which implies renaming/moving prior sessions.
- Implemented TSV conflict reassignment: older incoming files take earlier sessions, and existing sessions are queued for rename/move before copy; test updated to assert rename plan.


### Quick code notes (from current `save.py`)
- `_determine_run` now assigns `proposed_rank`, reuses runs based on signatures/TSV history, and marks unmatched records as pending for gap-fill.
- Signature/TSV helpers exist but are not wired into `_determine_run` or `_determine_location`.
