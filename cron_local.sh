#!/usr/bin/env bash

# set -euo pipefail


if [[ -z "${BOOST_TOKEN:-}" ]]; then
  echo "BOOST_TOKEN is required. Aborting." >&2
  exit 1
fi

SYSTEM="${BOOST_SYSTEM:-local}"
DAYS_AGO="${DAYS_AGO:-30}"

mkdir -p "logs/${SYSTEM}"
python -m act.main "${DAYS_AGO}" "${BOOST_TOKEN}" "${SYSTEM}" | tee "logs/${SYSTEM}/$(date +%Y%m%d_%H%M%S).log"



