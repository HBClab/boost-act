#!/usr/bin/env bash

# set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source /opt/anaconda3-2024.10-1/etc/profile.d/conda.sh
conda activate act

cd "${REPO_ROOT}"

git pull --ff-only origin final-test

if [[ -z "${BOOST_TOKEN:-}" ]]; then
  echo "BOOST_TOKEN is required. Aborting." >&2
  exit 1
fi

SYSTEM="${BOOST_SYSTEM:-vosslnxft}"

DAYS_AGO="${DAYS_AGO:-30}"

mkdir -p "logs/${SYSTEM}"
python -m code.main "${DAYS_AGO}" "${BOOST_TOKEN}" "${SYSTEM}" | tee "logs/${SYSTEM}/$(date +%Y%m%d_%H%M%S).log"

if ! git diff --quiet; then
  git add .
  git commit -m "automated commit by vosslab linux"
  git push
fi
