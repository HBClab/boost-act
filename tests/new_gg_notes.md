
# sleep logs

Sleep logs need to be have a specific syntax in order to work w/ GGIR

Example of a basic sleeplog:

| ID  | onset_N1  | wakeup_N1 | onset_N2  | wakeup_N2 | onset_N3  | wakeup_N3 | onset_N4  |
|-----|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 345 | 21:55:00  | 08:47:00  |           |           | 23:45:00  | 06:30:00  | 00:00:00  |
One column for participant id, this does not have to be the first column. Specify which column it is with argument `colid`.

Alternatingly one column for onset time and one column for waking time. Specify which column is the column for the first night by argument `coln1`, in the above example coln1=2.

Timestamps are to be stored without date as in hh:mm:ss with hour values ranging between 0 and 23 (not 24). If onset corresponds to lights out or intention to fall asleep, then specify sleepwindowType = "TimeInBed".

There can be multiple sleeplogs in the same spreadsheet. Each row representing a single recording.

First row: The first row of the spreadsheet needs to be filled with column names. For the basic sleep log format it does not matter what these column names are.

The first night in the basic sleeplog is assumed to correspond to the first recorded night in the accelerometer recording. If you know that sleep log start on a later day then make sure then add columns with labels but without timestamps. Note that by recorded night we mean that there is data regardless of whether the data is valid. So, if the participant does not wear the accelerometer the first night then that is still the first night in the recording.

### sleeplog dev info
- storing one massive sleep log in the `sleeplog` folder inside the data folder
    - this should have a subject ID column and then all other columnns preceeding being the nights and wakeupsnew
