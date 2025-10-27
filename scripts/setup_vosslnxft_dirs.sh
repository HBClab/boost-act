#!/usr/bin/env bash

set -euo pipefail

# Base directory for InterventionStudy data on vosslnx family machines
INT_BASE_ROOT="/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data"
OBS_BASE_ROOT="/mnt/nfs/lss/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data"


INT_FINAL_DIR="${INT_BASE_ROOT}/act-int-final-test-1"
INT_FINAL_DERIV="${INT_FINAL_DIR}/derivatives/GGIR-3.2.6"
OBS_FINAL_DIR="${OBS_BASE_ROOT}/act-obs-final-test-1"
OBS_FINAL_DERIV="${OBS_FINAL_DIR}/derivatives/GGIR-3.2.6"

# Some tooling still references the legacy ordering; keep it present for compatibility.
INT_TEST_FINAL_DIR="${INT_BASE_ROOT}/act-int-final-test-2"
OBS_TEST_FINAL_DIR="${OBS_BASE_ROOT}/act-int-final-test-2"

echo "Preparing InterventionStudy final-test directory structure under ${INT_BASE_ROOT}"

mkdir -p "${INT_FINAL_DERIV}"
mkdir -p "${INT_TEST_FINAL_DIR}"


echo "Created:"
echo "  - ${INT_FINAL_DIR}"
echo "  - ${INT_FINAL_DERIV}"
echo "  - ${INT_TEST_FINAL_DIR}"


echo "Preparing ObservationalnStudy final-test directory structure under ${OBS_BASE_ROOT}"

mkdir -p "${OBS_FINAL_DERIV}"
mkdir -p "${OBS_TEST_FINAL_DIR}"

echo "Created:"

echo "  - ${OBS_FINAL_DIR}"
echo "  - ${OBS_FINAL_DERIV}"
echo "  - ${OBS_TEST_FINAL_DIR}"

echo "Done."
