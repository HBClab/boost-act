#!/bin/bash

# Source the Conda activate script
source /opt/anaconda3-2024.10-1/etc/profile.d/conda.sh

# Activate Conda env
conda activate act

# Move to project home dir
cd "$(dirname "$0")"
# grab any new code changes, otherwise skip
git pull --ff-only origin main

# run pipe
cd code && python main.py 1 "DE4E2DB72778DACA9B8848574107D2F5"

#move back to home dir
cd ..

# commit and push made changes
git add .
git commit -m "automated commit by vosslab linux"
git push
