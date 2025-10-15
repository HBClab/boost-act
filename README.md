# Boost Actigraphy Processing Pipeline

An automation stack for synchronizing raw actigraphy exports, routing them through GGIR, and publishing QC plots for the BOOST observational and intervention studies. The service pulls IDs from REDCap, reconciles them with RDSS file drops, mirrors curated files to the LSS project hierarchy, and runs the GGIR + QC suite end to end.

## Table of Contents
- [Features](#features)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Running the Pipeline](#running-the-pipeline)
- [Configuration](#configuration)
- [Testing & QA](#testing--qa)
- [Automation & Cron Support](#automation--cron-support)
- [Troubleshooting Tips](#troubleshooting-tips)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

## Features
- Mirrors RDSS accelerometer files into LSS study folders using deterministic naming (`sub-####_ses-#_accel.csv`).
- Executes GGIR (3.2.6) via bundled R scripts and captures QC metrics per subject/session.
- Generates interactive activity composition plots (Plotly/Matplotlib) and summary tables for downstream dashboards.
- Exposes a Python CLI (`code/main.py`) that orchestrates symlink creation, ingest, GGIR, QC, and group visualizations.
- Provides cron wrappers to keep remote environments synchronized with `main` and to ship new outputs automatically.

## Repository Layout
```
code/
  core/          # GGIR-facing R scripts and conda env spec
  utils/         # ingest, QC, plotting, symlink helpers
  tests/         # QA notebooks, sample fixtures, exploratory plots
  res/data.json  # latest ingest manifest written by the pipeline
cron*.sh         # automation entry points (local + production)
logs/            # QC summaries emitted by utils.qc
AGENTS.md        # contributor workflow guide
```

## Prerequisites
- Python 3.11 (see `pyproject.toml`).
- R 4.3 with GGIR 3.0+; `code/core/environment.yml` captures a conda environment that works on VossLab Linux.
- Access to RDSS (`/mnt/nfs/rdss/vosslab/Repositories/Accelerometer_Data`) and LSS project mounts.
- REDCap API token with access to report `43327` (store in an environment variable, e.g. `BOOST_TOKEN`).
- Git credentials for fetching/pushing when using the cron wrappers.

## Quick Start
```bash
# 1. Clone
git clone https://github.com/HBCLab/boost-act.git
cd boost-act

# 2. Python environment
python -m venv .venv
source .venv/bin/activate
pip install -r code/requirements.txt

# 3. Optional: create R/GGIR env (Linux)
conda env create -f code/core/environment.yml
conda activate act-newer
```

## Running the Pipeline
```bash
export BOOST_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
python -m code.main <daysago> $BOOST_TOKEN <system>
```
- `daysago` filters RDSS files by acquisition date; use `1` for “yesterday’s drops”.
- `system` controls filesystem roots: `vosslnx` (default), `local`, or `argon`.
- The run will:
  1. Create fresh symlinks under `../mnt` (see `utils.mnt`).
  2. Match REDCap IDs to RDSS filenames (`utils.comparison_utils`).
  3. Copy curated CSVs into the correct LSS project folders (`utils.save`).
  4. Call GGIR through `core/acc_new.R` and execute QC/plotting (`utils.qc`, `utils.group`).
  5. Write a subject manifest to `code/res/data.json`.

For ad-hoc diagnostics, re-run plot generation with `python code/tests/gt3x/plots.py` (requires adjusting the hard-coded file path).

## Configuration
- Edit `code/utils/pipe.py` if new deployment targets or mounts are added.
- Update `code/core/acc_new.R` to tweak GGIR parameters or derivative paths.
- Place credentials in the environment or a secure secrets manager; never commit tokens.
- Logging defaults to INFO via `logging.basicConfig` in `code/main.py`; adjust the level for verbose runs.

## Testing & QA
- Lightweight Python tests can be added under `code/tests/<area>/test_*.py` and executed with `pytest`.
- QA notebooks in `code/tests/*/*.ipynb` document exploratory checks; rerun them after major data or script changes.
- `utils.qc` aggregates results into `logs/GGIR_QC_errs.csv`; inspect this file to confirm expected wear-time and calibration checks.
- Use sandbox tokens and the `local` system flag to validate changes without touching production mounts.

## Automation & Cron Support
- `cron.sh` bootstraps the conda env, pulls latest `main`, runs the pipeline (`daysago=1`, production token), and pushes any resulting artifacts.
- `cron_local.sh` mirrors the same flow without conda activation logic; run it from a workstation once credentials and remotes are configured.
- Review git staging before enabling cron on a new host to avoid committing large raw exports.

## Troubleshooting Tips
- **Missing symlinks:** run `python -c "from code.utils.mnt import create_symlinks; create_symlinks('../mnt')"` and confirm mount availability.
- **GGIR failures:** check the console output and logs under `code/core/` or R’s stderr; ensure the conda env includes GGIR dependencies.
- **REDCap mismatches:** `utils.comparison_utils.ID_COMPARISONS` logs duplicate IDs; review its stdout and `AGENTS.md` for remediation steps.
- **Permission errors:** verify the executing user can read RDSS and write to the LSS target directories.

## Contributing
Contributions are welcome! Start by reviewing `AGENTS.md` for code style, testing expectations, and PR etiquette. Please open issues for feature requests or bugs, and link related cron/job IDs when proposing changes that affect automation.

## Roadmap
- Finish session-aware aggregation in `utils.group.Group` to replace TODO blocks.
- Expand automated test coverage with filesystem mocks for ingest routines.
- Parameterize REDCap report IDs and GGIR derivative paths for multi-study support.

## License
No license has been specified yet. Until a license is published, usage is limited to collaborators with explicit permission from the maintainers.

/mnt/lss/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/derivatives/GGIR-3.2.6-test-ncp-sleep2/sub-8020/accel/ses-3/output_ses-3/results/part5_personsummary_MM_L44.8M100.6V428.8_T5A5.csv
/mnt/lss/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/derivatives/GGIR-3.2.6-test-ncp-sleep2/sub-7168/accel/ses-1/output_ses-1/results/part5_personsummary_MM_L44.8M100.6V428.8_T5A5.csv

```sh
cp /mnt/rdss/VossLab/Repositories/Accelerometer_Data/1168\ \(2025-08-14\)RAW.csv \
   /mnt/lss/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sub-8019/accel/ses-3
```

