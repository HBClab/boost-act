<!--
Sync Impact Report:
- Version change: unversioned template -> 1.0.0
- Modified principles: N/A (initialized from template)
- Added sections: Core Principles, Additional Constraints, Development Workflow & Quality Gates, Governance
- Removed sections: None
- Templates requiring updates: ✅ .specify/templates/plan-template.md, ✅ .specify/templates/spec-template.md, ✅ .specify/templates/tasks-template.md, ⚠ .specify/templates/commands/*.md (not present)
- Follow-up TODOs: TODO(RATIFICATION_DATE): initial adoption date not found
-->
# Boost Actigraphy Processing Pipeline Constitution

## Core Principles

### I. Checkpoint Test Discipline
Each checkpoint MUST be commit-sized, independently unit-testable, and MUST pass
the current test suite before the checkpoint is accepted.

### II. Realistic Test Design
Tests MUST reflect real data shapes, workflows, and failure modes, avoiding
unrealistic mocks that hide integration risks.

### III. Edge-Complete Coverage
Tests MUST cover edge cases that can occur in production (boundary values,
missing data, malformed inputs, and IO failures) in addition to happy paths.

### IV. End-to-End Validation After Full Implementation
End-to-end testing MUST be executed after the full implementation of a feature
or change set to verify system-wide behavior.

### V. Dependency Minimization
New dependencies MUST be minimized and only introduced when existing libraries
or the standard library cannot meet the requirement; additions require explicit
justification in the change summary.

## Additional Constraints

- Follow PEP 8 and repository naming conventions for modules, classes, and files.
- Use `logging` for runtime diagnostics; do not add new print-based logging.
- Keep tokens and secrets in environment variables; never hard-code them.
- File outputs MUST preserve the `sub-####_ses-#_accel.csv` naming convention.
- Avoid committing large raw exports; artifacts belong in `act/res/data.json`
  and repo-level `logs/`.

## Development Workflow & Quality Gates

- Each checkpoint MUST run the current test suite, be commit-sized, and be
  independently unit-testable.
- E2E tests MUST run after the full implementation of the change set.
- Tests SHOULD prefer filesystem mocks and sandboxed paths over `/mnt`.
- Manual QA artifacts (notebooks, plots, CSVs) MUST be refreshed when data or
  plotting logic changes.

## Governance

- This constitution supersedes other guidance; conflicts must be resolved in
  favor of these rules.
- Amendments require a documented PR that updates this file, the Sync Impact
  Report, and any dependent templates or docs.
- Versioning follows semantic versioning: MAJOR for incompatible governance
  changes, MINOR for new/expanded principles or sections, PATCH for clarifications.
- Compliance is reviewed in every plan/spec/tasks phase and during code review;
  reviewers must confirm checkpoint testing, edge coverage, dependency discipline,
  and E2E validation where applicable.
- `AGENTS.md` and `README.md` provide runtime guidance but cannot override this
  constitution.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE): initial adoption date not found | **Last Amended**: 2026-03-10
