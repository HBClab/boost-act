#!/bin/bash

# Source the Conda activate script
source /opt/anaconda3-2024.10-1/etc/profile.d/conda.sh

# Activate Conda env
conda activate act

# Move to project home dir
cd "$(dirname "$0")"

# run pipe
cd code && python main.py 1
