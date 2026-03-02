# Feature Spec — CLI Modernization + Rebuild Manifest Only

## Goals
- Provide a standard, explicit CLI interface using `argparse` that is stable across NixOS and generic headless Linux.
- Add a strict `--rebuild-manifest-only` execution mode that rebuilds `res/data.json` from current LSS layout.
- Treat LSS folders as source-of-truth for which subject/session records exist.
- Enrich LSS-derived records with metadata from RedCap and RDSS.

## Functional Requirements (FR)

### FR-CLI-1: Standard CLI Interface
- The entrypoint must use `argparse` with typed arguments and validation.
- Existing positional behavior should be replaced or cleanly wrapped by explicit flags.
- CLI usage/help text must document all modes and required arguments.

### FR-CLI-2: `--rebuild-manifest-only` Mode
- Add a boolean flag `--rebuild-manifest-only`.
- When this flag is enabled, the pipeline must:
  - rebuild manifest records,
  - write `res/data.json`,
  - skip copy/rename file operations,
  - skip GGIR,
  - skip plotting.

### FR-MANIFEST-1: Source of Truth = LSS Layout
- In `--rebuild-manifest-only`, discover records from LSS session folders for the selected `system` paths.
- A manifest row must exist only if a corresponding session CSV exists on LSS.
- RDSS presence alone must not create records.

### FR-MANIFEST-2: Run Derivation from Session Folder
- Derive `run` from the LSS folder name `ses-#`.
- `ses-1 -> run=1`, `ses-2 -> run=2`, etc.
- Do not reassign runs based on date ordering in rebuild mode.

### FR-MANIFEST-3: Metadata Enrichment
- Use RedCap report mapping to resolve `subject_id -> labID`.
- Use RDSS file list to resolve per-session metadata fields:
  - `filename`
  - `labID`
  - `date`
- Manifest row shape remains compatible with existing `data.json` contract.

### FR-MANIFEST-4: Strict Failure Rules
- If a session folder contains multiple candidate accel CSV files, mark the subject as conflict and fail rebuild.
- If any required metadata (`filename`, `labID`, `date`) cannot be resolved via RedCap/RDSS for any discovered LSS session, fail rebuild.
- Rebuild failure must return non-zero exit status and must not write a partial final manifest.

### FR-MANIFEST-5: Safe Write Semantics
- Manifest output must be atomic (write temp file, then replace target).
- On failure, preserve prior manifest file unchanged.

## Scope

### In Scope
- CLI argument redesign using `argparse`.
- `--rebuild-manifest-only` implementation.
- LSS scanning logic for session discovery.
- RedCap/RDSS lookup integration required to populate manifest fields.
- Strict conflict/error reporting and non-zero exit behavior.

### Out of Scope
- Any GGIR execution behavior changes.
- Any plotting behavior changes.
- Automatic reconciliation or mutation of LSS files/folders.
- Relaxed mode that keeps partial/placeholder manifest rows.

## Non-Functional Requirements
- Must run in non-interactive/headless environments.
- Must remain dependency-light (no new heavy CLI frameworks).
- Logging must clearly identify subject-level failure causes.

## Acceptance Criteria
- Running with `--rebuild-manifest-only` produces `res/data.json` based strictly on existing LSS sessions.
- Runs in manifest match `ses-#` folder indices.
- Missing RedCap/RDSS metadata causes command failure with clear logs.
- Multi-CSV-in-session conflict causes command failure with clear logs.
- No GGIR, plotting, copy, or rename actions occur in this mode.