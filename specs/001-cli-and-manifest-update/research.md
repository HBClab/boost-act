# Research: Manifest Reconciliation Fix

## Decision 1: Reconciliation entrypoint
- **Decision**: Add a new CLI mode `--reconcile-manifest-only` that runs a
  manifest-driven reconciliation pass without ingest, GGIR, or plotting.
- **Rationale**: The FIXES report requires a reconciliation path that can run
  independently of new RDSS matches while keeping the existing ingest flow
  unchanged.
- **Alternatives considered**:
  - Always reconcile on every ingest run (rejected: higher runtime + unexpected
    file mutations during routine ingest).
  - Manual script outside the pipeline (rejected: harder to enforce tests and
    operator usage).

## Decision 2: Identity comparison strategy
- **Decision**: Compare canonical destination files against RDSS source files
  using size + SHA-256 hash from stdlib `hashlib`; only compute the hash if size
  matches to reduce cost.
- **Rationale**: The manifest provides `filename` and `file_path`, so RDSS files
  can be located and compared deterministically. SHA-256 avoids collision risk
  while keeping dependencies at zero.
- **Alternatives considered**:
  - Size + mtime only (rejected: insufficient identity guarantee).
  - Persisting checksum in manifest only (deferred: requires backfill for legacy
    rows and doesn't eliminate need to compare to RDSS when available).

## Decision 3: Failure handling for ambiguous session folders
- **Decision**: Treat multiple `_accel.csv` files inside a `ses-*` directory as a
  strict error in reconciliation and in `_apply_two_phase_renames`, mirroring the
  strictness used during manifest rebuild.
- **Rationale**: Nondeterministic selection risks re-labeling the wrong file and
  perpetuating drift. Failing fast makes the issue explicit and testable.
- **Alternatives considered**:
  - Choose first file by directory order (rejected: nondeterministic and unsafe).

## Decision 4: Repair semantics
- **Decision**: When a mismatch is detected, copy the RDSS source file into the
  canonical destination (atomic replace) and refresh symlinks, logging the
  correction.
- **Rationale**: Manifest is the source of truth and RDSS holds the canonical
  raw file; replacing the destination repairs drift.
- **Alternatives considered**:
  - Only report mismatches (rejected: does not repair stale disk state).
  - Rename/move the wrong file elsewhere (deferred: would require new archival
    location policy).

## Decision 5: Scope of reconciliation
- **Decision**: Reconcile only subjects present in `res/data.json` and only
  records with valid `filename`, `file_path`, `run`, and `study` fields.
- **Rationale**: Keeps the operation bounded to known canonical records and
  avoids guessing when metadata is incomplete.
- **Alternatives considered**:
  - Scanning LSS independently of manifest (rejected: duplicates rebuild mode).
