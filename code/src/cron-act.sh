# This file is called by cron to run the actigraphy pipeline 

#!/bin/bash

#connect to LSS/RDSS





cd /path/to/code
source /path/to/venv/bin/activate



python3 src/match.py --indir /Volumes/VossLab/Repositories/Accelerometer_Data --txt ./code/resources/files.txt --token DE4E2DB72778DACA9B8848574107D2F5


#deconnect from RDSS and LSS
#deactivate the virtual environment
