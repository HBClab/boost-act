# Feature Spec -> Testing Suite
---

## Requirements
--
- pytest testing suite and flake8 linting (no e502) for the entire project
- tests should msotly cover the python code, not the R/GGIR code
- tests should cover the saving logic:  
  - e.g. if there is a new session added for a subject for a date prior than what's currently saved as session 1, does a rename occur?
  - mostly just edge cases like these 
- testing should