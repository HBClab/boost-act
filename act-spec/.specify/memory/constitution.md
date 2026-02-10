<!--
Sync Impact Report
- Version change: N/A (template) → 0.1.0
- Modified principles: Template placeholders → Mandatory Testing for Function Changes; Secrets Stay Private; Automation Branch Discipline; Deterministic Outputs & Naming; Logging-First Diagnostics
- Added sections: Security & Data Handling; Development Workflow & Quality Gates
- Removed sections: None
- Templates requiring updates: ✅ .specify/templates/plan-template.md; ✅ .specify/templates/spec-template.md; ✅ .specify/templates/tasks-template.md
- Follow-up TODOs: TODO(RATIFICATION_DATE): original ratification date not recorded
-->
# Boost Actigraphy Processing Pipeline Constitution

## Core Principles

### Mandatory Testing for Function Changes
All new functions and any changes to existing functions MUST include tests, and
those tests MUST be run before merge or deployment. Use pytest where applicable
and prefer filesystem-mocked tests for pipelines touching `/mnt`. Rationale:
regressions in ingest, QC, or GGIR orchestration can silently corrupt outputs,
so tested changes are non-negotiable.

### Secrets Stay Private
API keys, tokens, and credentials MUST remain in environment variables or secure
secrets managers and MUST NEVER be committed to the repository, embedded in
scripts, or echoed to logs. Rationale: pipeline access spans RDSS/LSS/REDCap and
leaked credentials create immediate operational risk.

### Automation Branch Discipline
`final-test` is the current automation branch; cron/automation workflows MUST
track this branch unless explicitly approved otherwise. Changes that affect
automation behavior MUST be reviewed, validated on a sandbox token, and merged
into `final-test` before enabling in production. Rationale: stable automation
requires a single, explicit source of truth.

### Deterministic Outputs & Naming
Pipeline outputs MUST follow the `sub-####_ses-#_accel.csv` naming convention as
implemented in `Save._determine_location`, and large raw exports MUST NOT be
committed. Artifacts are limited to `code/res/data.json` and curated logs under
`logs/`. Rationale: downstream dashboards and LSS routing depend on stable names
and controlled artifact size.

### Logging-First Diagnostics
Use `logging` for runtime diagnostics and avoid `print` in production paths.
Logs MUST capture meaningful context for ingest, GGIR, and QC failures without
exposing secrets. Rationale: production troubleshooting depends on consistent,
structured logs.

## Security & Data Handling
- Tokens and secrets live in environment variables or secrets managers only.
- Avoid committing large raw exports or sensitive source data to git.
- Maintain least-privilege access to RDSS/LSS mounts and REDCap reports.

## Development Workflow & Quality Gates
- Run tests for every new or modified function before merge or automation use.
- Validate changes with a dry-run pipeline (low `daysago`, sandbox token).
- If modifying automation behavior, confirm `final-test` is updated and the
  cron flow references that branch.
- Keep logging changes aligned with `code/main.py` logging configuration.

## Governance
This constitution supersedes all other practices. Amendments require a
documented update to this file, review by maintainers, and any migration notes
for downstream automation. Versioning follows semantic versioning: MAJOR for
backward-incompatible governance changes, MINOR for new principles or material
expansions, PATCH for clarifications. Every plan and PR MUST include a
constitution compliance check, and any exception MUST be documented with
rationale in plan complexity tracking or an equivalent review note.

**Version**: 0.1.0 | **Ratified**: TODO(RATIFICATION_DATE): original ratification date not recorded | **Last Amended**: 2026-02-10
