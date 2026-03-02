# Fixes for current logic issues in manifest // cli update

## Current bugs // logic issues
- Subjects starting with 9000 ids will not have a subject -> lab id mapping and will not be found in the rdss, remove warnings for these subjects that is causing strict conflict updates
^^ Expanded below


### 9000 IDs
---
***Dilemma***
- 9000 IDs are pulled outside of this workflow from another data source, this logic is currently stable and will always end like this
- Should these subjects even be added to the manifest if they are not truly required?
- They are ran automatically through the GGIR script thus they should not be touched in this pipeline