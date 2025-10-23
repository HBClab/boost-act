# Repository Guidelines

## Project Structure & Module Organization
- Primary code lives in `code/`; `main.py` orchestrates the pipeline via `utils.pipe.Pipe`.
- `code/utils/` contains data movement, QC, and plotting helpers; keep new helpers modular and reuse logging.
- `code/core/` houses GGIR-facing R scripts and the `GG` Python wrapper; treat these as the source of truth for summary metrics.
- `code/tests/` stores QA notebooks, sample CSVs, and plotting scripts grouped by study focus; add new fixtures beside the notebooks they support.
- Artifacts land in `code/res/data.json` and repo-level `logs/`; avoid committing large raw exports.

## Build, Test, and Development Commands
- `python -m venv .venv && source .venv/bin/activate` – create a local env (Python 3.11).
- `pip install -r code/requirements.txt` – install runtime deps; add extras here only when they are runtime-critical.
- `python -m code.main 1 "$BOOST_TOKEN" vosslnx` – run the ingest + GGIR pipeline; system flag may be `vosslnxft`, `local`, or `argon`.
- `python code/tests/gt3x/plots.py` – regenerate GT3X diagnostic plots and CSV summaries; confirm paths before running.
- `bash cron.sh` – mirrors production cron behaviour; ensure credentials and git remotes are safe before invoking.

## Coding Style & Naming Conventions
- Follow PEP 8 (4-space indents, snake_case for modules/functions, PascalCase for classes).
- Use `logging` (see `code/main.py`) instead of print for new runtime diagnostics.
- File outputs should match `sub-####_ses-#_accel.csv` naming as enforced in `Save._determine_location`.
- Keep tokens and secrets in environment variables; never hard-code inside scripts or configs.

## Testing Guidelines
- Prefer pytest modules named `test_*.py` under `code/tests/`; reuse the existing subfolders to group by modality.
- Lightweight assertions should mock filesystem paths rather than writing to `/mnt`; see `utils.save` for patterns to isolate.
- For manual QA, refresh notebooks (`code/tests/*/*.ipynb`) after dataset changes and export key figures to git-tracked PNG/CSV in the same folder.
- Before submitting, run the pipeline in dry-run mode (use a low `daysago` and a sandbox token) and inspect `code/res/data.json`.

## Commit & Pull Request Guidelines
- Use short, present-tense commit subjects (for example: `Sync GGIR exports`, `Harden RDSS sync error handling`); history (`3c432e9`) favours concise summaries.
- Squash WIP noise before PR; reference related issues or cron job IDs when relevant.
- PR descriptions should list affected directories, expected data side-effects (moved files, new outputs), and screenshots of any new plots.
- Flag any schema or path changes for downstream systems (cron jobs, dashboards) and mention required manual steps.
