# ACTIGRAPH WORKFLOW


## Requirements
- Move Data from RDSS to LSS
- Process data using GGIR
- Store data in correct format on LSS
- Produce reports and display on webpage

## Plan
- write accel transfer scripts
- write GGIR router function
- work with mv to finalize GGIR R file


### Tasks
- [x] create layout
- [x] build accel transfer
- [x] transfer current data
- [ ] add study rule ->
    - if sub already in obs -> move to int 
    - all need to be after start date 

### adding sleep logs
- [x] need to return the sleep files from `/sleep` inside the accel folder in RDSS
- [x] modify `code/utils/comparison_utils` to also add the sleep logs to the linkage, storing the correct study inside
    - [ ] need to split running by session and split sleep logs by session
    


- [ ] create a new util that transforms the current logs into the GGIR available one
