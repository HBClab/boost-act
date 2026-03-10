# Fixes for current logic issues in manifest // cli update

## Current bugs // logic issues
- Some subjects have correct canonical session ordering in `res/data.json`, but the on-disk `ses-*` files do not match that ordering.
- Review the mismatch pattern and confirm whether the issue is isolated to subjects with prior filesystem drift, failed reorder attempts, or multi-file session directories.

### Session Reordering Fixes
---
- **Representative subject: `8046`**
  - `8046` is a useful example because the manifest already shows a plausible, chronologically ordered wear-period sequence, but the files currently stored under the canonical `ses-*` directories appear not to match those manifest rows.
  - Expected canonical order for the subject, based on `res/data.json`:
    - run 1 / wear period 1: `1330 (2025-05-28)RAW.csv`
    - run 2 / wear period 2: `1330 (2025-08-01)RAW.csv`
    - run 3 / wear period 3: `1330 (2025-12-09)RAW.csv`
    - run 4 / wear period 4: `1330 (2026-01-29)RAW.csv`
  - Reported observed problem:
    - session files on disk do not align with those canonical assignments;
    - at least one earlier wear period appears to have been preserved or duplicated into a later `ses-*` directory;
    - the manifest itself is not the part that looks wrong for this case.
  - What this example is intended to demonstrate:
    - the bug is not just "runs were numbered incorrectly";
    - the stronger claim is "the manifest can be correct while the file contents located at the canonical session paths are wrong."

- **Concrete manifest example for `8046`**
  - The current manifest rows below are the canonical target state the pipeline should enforce:
  ```json
  "8046": [
    {
      "filename": "1330 (2025-05-28)RAW.csv",
      "labID": "1330",
      "date": "2025-05-28",
      "run": 1,
      "study": "int",
      "file_path": "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-final-test-2/sub-8046/accel/ses-1/sub-8046_ses-1_accel.csv"
    },
    {
      "filename": "1330 (2025-08-01)RAW.csv",
      "labID": "1330",
      "date": "2025-08-01",
      "run": 2,
      "study": "int",
      "file_path": "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-final-test-2/sub-8046/accel/ses-2/sub-8046_ses-2_accel.csv"
    },
    {
      "filename": "1330 (2025-12-09)RAW.csv",
      "labID": "1330",
      "date": "2025-12-09",
      "run": 3,
      "study": "int",
      "file_path": "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-final-test-2/sub-8046/accel/ses-3/sub-8046_ses-3_accel.csv"
    },
    {
      "filename": "1330 (2026-01-29)RAW.csv",
      "labID": "1330",
      "date": "2026-01-29",
      "run": 4,
      "study": "int",
      "file_path": "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-final-test-2/sub-8046/accel/ses-4/sub-8046_ses-4_accel.csv"
    }
  ]
  ```

- **What should be verified for this example**
  - For each manifest row, inspect the file currently present at `file_path`.
  - Determine whether the contents of each destination file actually correspond to the expected RDSS source file named in `filename`.
  - Record mismatches as a manifest-vs-disk reconciliation issue, not as a manifest-ordering issue.
  - Check whether any `ses-*` directory contains more than one `_accel.csv`, because that would make the rename path ambiguous and can explain nondeterministic reorder results.

- **Why this example matters**
  - If `8046` is confirmed to have correct manifest rows but incorrect on-disk content, then the required fix is not just better run assignment logic.
  - The pipeline needs a separate manifest-driven reorder/reconciliation step that can verify file identity and repair stale canonical session paths even when the manifest itself is already correct.

### Problem Specification (with code references)
---
- **Observed failure mode**
  - Manifest ordering and `file_path` values can be correct while on-disk session files are stale/misplaced, producing duplicate or otherwise incorrect content across different `ses-*` directories for the same subject.
  - Example pattern: run 1 and run 2 in manifest map to different RDSS source files, but both destination files contain run 1 content.
  - This is not best described as a generic "reordering failure" on a clean subject history. The more precise boundary is: the manifest has the correct canonical order, but the existing session directories on disk already contain stale or mismatched content from an earlier bad state, and the normal ingest path does not reconcile that state back to the manifest.

- **Primary execution path where divergence can happen**
  - `Save.save()` processes subjects transactionally and then persists the manifest: [act/utils/save.py#L50](act/utils/save.py#L50), [act/utils/save.py#L65](act/utils/save.py#L65).
  - Per-subject logic computes canonical runs/paths, applies rename plan to existing session directories, then copies only newly introduced records: [act/utils/save.py#L679](act/utils/save.py#L679), [act/utils/save.py#L748](act/utils/save.py#L748), [act/utils/save.py#L755](act/utils/save.py#L755).
  - On a clean filesystem, this path should handle ordinary backfill/reindex correctly because existing session directories are moved to their new canonical runs before the newly introduced record is copied into the open slot.
  - The divergence appears when the disk state is already wrong before the transaction starts, because the pipeline currently treats the existing `ses-*` directory contents as trustworthy during rename.

- **Likely root cause in current logic (no guard yet)**
  - The more direct gap is in the rename path, not the copy path alone. `_apply_two_phase_renames()` moves whole session directories and then renames whichever `_accel.csv` it finds in the destination directory to the expected canonical filename, without verifying that the file's contents match the manifest record identity for that run: [act/utils/save.py#L882](act/utils/save.py#L882), [act/utils/save.py#L927](act/utils/save.py#L927).
  - If a `ses-*` directory already contains the wrong CSV content, the rename transaction preserves and re-labels that wrong content into a new canonical location.
  - `_copy_subject_record()` is still a secondary contributor. It skips when destination already exists and does not verify that destination content corresponds to the incoming record identity (`filename`/`date`/`labID`): [act/utils/save.py#L633](act/utils/save.py#L633), [act/utils/save.py#L644](act/utils/save.py#L644).
  - That means the pipeline has no built-in content reconciliation step for pre-existing session files. Once disk state drifts from the manifest, later ingest runs can preserve that drift instead of correcting it.

- **Required recovery / reorder pass**
  - The regular ingest transaction should not be the only place where run-order correctness is enforced. Add a separate reconciliation function in the pipeline that can run independently of new RDSS matches and walk every subject already present in `res/data.json`.
  - For each manifest record, the reconciliation pass should:
    - treat the manifest entry as the canonical target (`subject_id`, `run`, `study`, `file_path`, `filename`, `date`, `labID`);
    - inspect the current on-disk file at that canonical path and compare it against a reproducible identity/signature for the expected source record;
    - repair any mismatch by moving/copying the correct file into the canonical session slot rather than assuming the current file in `ses-*` is correct.
  - The signature does not need to be cryptographic if a cheaper identity is available. Options include:
    - comparing a stored manifest-level signature derived from the RDSS source file at ingest time, such as checksum, byte size, and/or modified timestamp;
    - comparing a lightweight content fingerprint computed directly from the destination file and expected RDSS source file during reconciliation;
    - if raw content comparison is too expensive, persisting enough source metadata alongside each manifest record to prove which RDSS file should back each canonical session.
  - The important design point is that the reorder/reconcile pass must answer "does this canonical session file actually contain the record represented by this manifest row?" rather than only "does a file exist at this path?"

- **Logic gap during reindex shifts**
  - `_apply_two_phase_renames()` renames session directories via temp hops and then renames the first discovered `_accel.csv` in the destination directory: [act/utils/save.py#L882](act/utils/save.py#L882), [act/utils/save.py#L906](act/utils/save.py#L906).
  - The file selection is based on `os.listdir(new_dir)` and stops at the first matching `_accel.csv`, with no deterministic ordering and no identity check: [act/utils/save.py#L928](act/utils/save.py#L928), [act/utils/save.py#L929](act/utils/save.py#L929).
  - This creates a real logic gap if a session directory contains more than one candidate CSV:
    - reorder behavior becomes nondeterministic because the chosen file depends on directory listing order rather than manifest identity;
    - the wrong CSV can be silently renamed into the canonical filename for that run;
    - the pipeline's ingest/reorder path is therefore less strict than manifest rebuild, which already treats multi-candidate session directories as a conflict instead of guessing.
  - There is also no post-transaction reconciliation step that validates disk contents against canonical record identity after rename+copy.

- **What is currently tested vs missing**
  - Covered: two-way session swap collision handling: [act/tests/test_save_manifest_reindex.py#L256](act/tests/test_save_manifest_reindex.py#L256).
  - Covered: manifest remains unchanged if rename fails: [act/tests/test_save_manifest_reindex.py#L346](act/tests/test_save_manifest_reindex.py#L346).
  - Covered conceptually: normal clean backfill/reindex should produce dense runs and move existing sessions into their new slots.
  - Not covered: pre-existing disk/manifest divergence before a reorder transaction starts; destination-exists-but-wrong-content; multi-candidate `_accel.csv` selection during rename; and rerun idempotency for on-disk content correctness (not just run index assignment).

- **Current problem boundary to fix next**
  - Keep manifest as source-of-truth.
  - Separate ordinary run reindexing from recovery of stale filesystem state. The current ingest transaction handles the former, but not the latter.
  - Add a manifest-driven reorder/reconciliation function that can run even when no new RDSS matches arrive for a subject.
  - Ensure reorder/reconcile logic performs identity-aware move/copy semantics for canonical session files, with no stale duplicates across `ses-*`.
  - Detect and correct stale destination files when canonical mapping changes or when disk state no longer matches the manifest.
  - Fail fast when a session directory contains multiple candidate CSVs instead of selecting one implicitly.
