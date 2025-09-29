#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_PREFIX_ROOT="${CONDA_PREFIX_ROOT:-/opt/anaconda3-2024.10-1}"

# shellcheck source=/dev/null
source "${CONDA_PREFIX_ROOT}/etc/profile.d/conda.sh"
conda activate act

cd "${REPO_ROOT}"

git pull --ff-only origin main

if [[ -z "${BOOST_TOKEN:-}" ]]; then
  echo "BOOST_TOKEN is required. Aborting." >&2
  exit 1
fi

# TODO: replace this placeholder logic with host-based system detection.
SYSTEM="${BOOST_SYSTEM:-vosslnx}"

DAYS_AGO="${DAYS_AGO:-1}"

python -m code.main "${DAYS_AGO}" "${BOOST_TOKEN}" "${SYSTEM}"

if ! git diff --quiet; then
  git add .
  git commit -m "automated commit by vosslab linux"
  git push
fi
