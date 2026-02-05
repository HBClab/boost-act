## Problem recap (from code review, no new data pulled)
- `Save._determine_run` currently just sorts each subject’s matches by `date` and labels them `run = 1..n`. It never checks what sessions already exist on disk (`act-int/obs` trees) or in the prior manifest (`res/data.json`). If session 1 already exists for a subject, the next ingest still assigns `run=1`, so `_move_files` silently skips the copy and the new recording never lands. Conversely, a human-in-the-loop (HITL) manual copy can leave gaps (e.g., ses-2 present but ses-1 missing) that the code doesn’t reuse. Wrong-session placements then propagate into GGIR.

## First potential solution: “Content-aware session reconciliation”
Use cheap file fingerprints to decide whether an incoming RDSS file already exists in the LSS tree and which session it corresponds to—without loading whole files into memory.

Proposed steps:
1) **Build lightweight fingerprints for destination files**  
   - Walk `INT_DIR`/`OBS_DIR` and collect `(size_bytes, mtime, first_10_lines_hash)` for each `sub-*/accel/ses-*/sub-*_ses-*_accel.csv`.  
   - The first 10 lines are read via a streaming helper (e.g., `_peek_signature(path, n=10)`) to avoid loading entire files; decode as text with `errors="ignore"` and hash the joined lines.  
   - Keep an index keyed by `subject_id → session → signature` plus a reverse map `subject_id → signature → session` to support matching before ranking.
2) **Fingerprint incoming RDSS files (subject-batched)**  
   - Process matches grouped by subject to keep ordering/ranking consistent.  
   - For each RDSS file, compute the same signature, then:
     - If signature matches an existing session for that subject, mark `already_ingested`, pin `run` to that session, and log.  
     - If signature matches but is bound to a different session rank than its current position, **re-rank** the subject’s queue to align runs with the signature-backed session numbers.  
     - If no match, keep the file in the subject’s candidate list for gap-fill ranking.
3) **Rank reconciliation against TSV audit**  
   - Before finalizing runs, load the prior audit TSV (if present) so the pipeline can compare the **proposed session rank** with historical fingerprints for that subject.  
   - If a proposed rank conflicts (same rank, different signature), **reassign sessions to preserve chronological order**: older files get lower session numbers, and conflicting prior sessions get shifted to the next available slot (rename/move required).  
   - If a signature already exists in TSV with a different rank, prefer the TSV rank (authoritative) and reorder the current subject batch accordingly.  
   - This forces conflict resolution *inside* the ingest step, not after copy.
4) **Gap-fill run assignment (post-reconcile)**  
   - For unmatched files per subject, assign the smallest free session numbers (dense 1,2,3,…) based on existing files + TSV + reconciled matches.  
   - Subject-level processing ensures consistent ordering when multiple new files arrive together.
5) **Log reconciliation decisions**  
   - Emit/append TSV `logs/session_fingerprint.tsv` with: subject_id, study, proposed_rank, final_rank, signature_match (`exact|none`), action (`reuse|assign_new|bumped_conflict|skip_duplicate`), rdss_filename, source (`fs|tsv`).  
   - No deep content read; only first 10 lines and stat metadata.

Why this helps:
- Detects files already present (or misfiled) without relying on consistent timestamps or exact paths.  
- Avoids re-copying when the same raw appears again on RDSS.  
- Corrects wrong-session placements by matching on content rather than only dates.  
- Stays memory-light and fast; first-10-line reads are cheap and do not load full CSVs.

Implementation outline:
- Add helpers `_peek_signature(path, n_lines=10)` and `_signature_key(record)` in `save.py`.  
- Build a subject/session → signature map before `_determine_run`.  
- Add helpers to compute subject-level reordering and to plan session renames (old → new) when older files should take earlier session slots.  
- Update `_determine_run` to: (a) batch by subject, (b) apply signature reuse + TSV reconciliation, (c) compute any session renames required to keep chronological order, (d) gap-fill, then (e) emit audit log via `logging` + TSV writer.  
- Extend tests to cover: matching existing signature, reassigning to a different session, TSV-driven reorder (older file takes earlier slot), gap-fill after signature reuse, and skip-duplicate path.

Fix Roadmap (with gated tests per step)

  - [x] Update helpers
       - Add _peek_signature(path, n_lines=8) + _signature_key(meta) to code/utils/save.py.
       - Unit: new test ensuring hash changes when first 10 lines differ; handles short files; ignores encoding errors.
  - [x] Build signature ledger
       - Implement _build_signature_maps() to scan INT_DIR/OBS_DIR for existing session files → subject→session→sig and subject→sig→session.
       - Unit: fixture creates two subs with sessions; assert maps return expected lookups and ignore non-CSV.
  - [x] TSV audit loader/writer
       - Add _load_signature_tsv() (idempotent, missing-file safe) and _append_signature_tsv(rows) writing to logs/session_fingerprint.tsv.
       - Unit: round-trip write/read preserves columns; missing file returns empty.
  - [x] Subject-batched determine_run
       - Refactor _determine_run to batch by subject, consult signature maps and prior TSV, perform reuse/re-rank, queue unmatched for gap-fill.
       - Unit: scenarios—exact signature reuse pins session; signature in different session re-ranks; unmatched stays pending.
  - [x] Conflict resolution vs TSV
       - Within _determine_run, compare proposed rank to TSV history; on conflict, **reassign runs so chronological order wins** (older files take earlier sessions), and compute a rename plan for any existing sessions shifted to later runs.
       - Add helper(s) to stage session renames (source path → destination path) so `_move_files` can apply them before copying new files.
       - Unit: TSV fixture with existing rank; incoming older file takes session 1 and the prior TSV session gets scheduled for rename to session 2.
  - [x] Gap-fill allocator
       - After reconciliation, assign smallest free session numbers per subject (dense 1,2,3…).
       - Unit: preexisting sessions {1,3}; two new files get runs 2 and 4; ordering respects date.
  - [x] Integrate with location + renames
       - Ensure _determine_location consumes final runs unchanged; apply any session renames before copy to avoid collisions.
       - Unit: reuse existing test_save_session.py patterns plus one new case where an existing session is shifted to a later run.
  - [x] Logging coverage
       - Emit TSV rows with proposed_rank, final_rank, signature_match, action, source.
       - Unit: confirm TSV contains expected rows/actions for mixed reuse + bump + new.
  - [x] End-to-end dry slice
       - Minimal integration test: construct Save with tmp dirs, seed existing file + TSV, feed three matches (reuse, bump, new); assert copy targets and TSV lines.
       - Manual: run pytest code/tests/code_tests/test_save_session.py::... and new tests.

  Proceed stepwise: only move to next bullet after its unit test passes.
