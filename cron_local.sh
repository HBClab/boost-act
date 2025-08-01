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
