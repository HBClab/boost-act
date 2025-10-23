#!/usr/bin/env bash

set -euo pipefail

# Base directory for InterventionStudy data on vosslnx family machines
BASE_ROOT="/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data"

INT_FINAL_DIR="${BASE_ROOT}/act-int-final-test-1"
INT_FINAL_DERIV="${INT_FINAL_DIR}/derivatives/GGIR-3.2.6"

# Some tooling still references the legacy ordering; keep it present for compatibility.
INT_TEST_FINAL_DIR="${BASE_ROOT}/act-int-test-final-1"

echo "Preparing InterventionStudy final-test directory structure under ${BASE_ROOT}"

mkdir -p "${INT_FINAL_DERIV}"
mkdir -p "${INT_TEST_FINAL_DIR}"

echo "Created:"
echo "  - ${INT_FINAL_DIR}"
echo "  - ${INT_FINAL_DERIV}"
echo "  - ${INT_TEST_FINAL_DIR}"

echo "Done."
