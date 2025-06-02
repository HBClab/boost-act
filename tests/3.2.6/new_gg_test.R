library("GGIR")
packageVersion("GGIR") #should read out 3.2.6


# Directories to process
datadirs <- c(
  "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test",
  "/Shared/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test"
)

outputdirs <- c(
  "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/GGIR/derivatives/GGIR-3.2.6",
  "/Shared/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/GGIR/derivatives/GGIR-3.2.6"
)

# Loop through each datadir/outputdir pair
for (i in seq_along(datadirs)) {
  datadir <- datadirs[i]
  outputdir <- outputdirs[i]

  message("🔁 Running GGIR for pair ", i, ":")
  message("   📂 datadir: ", datadir)
  message("   📁 outputdir: ", outputdir)

  tryCatch({
    GGIR(
          mode = 1:6, #run parts 1 -> 5
          #================
          # Basic Preparation
          #================
          datadir = datadir,
          outputdir = outputdir,
          studyname = "boost",
          overwrite = FALSE,
          do.report = c(2, 4, 5, 6),
          visualreport = TRUE,
          old_visualreport = FALSE,
          windowsizes = c(5, 900, 3600),
          desiredtz = "america/chicago",
          print.filename = TRUE,
          dayborder = 0,
          idloc = 2, # the string immediately preceeding the first '_' character in the filename (is subject ID)
          epochvalues2csv = TRUE,
          ignorenonwear = TRUE,
          #===============
          # Part 1
          #===============
          do.ENMO = TRUE,
          acc.metric = "ENMO",
          #==============
          # Part 2
          #==============
          hrs.del.start = 4,
          hrs.del.end = 3,
          maxdur = 9,
          #==============
          # Part 3 + 4 -> this is where sleep occurs, all sleep log stuff defined in sleep logs section
          #==============
        
          # Nothing to see here!

          #==============
          # Sleep Logs
          #==============
          # loglocation = "", # location of the sleep log file
          # colid = "", # name of the column with subject ID
          # coln1 = "", # column int that starts the first night
          # sleepwindowType4 = 'TimeInBed',
          #==============
          # Part 5
          #==============
          timewindow = c("WW", "MM"),
          #==============
          # Part 6
          #==============
          part6CR = TRUE,
    )
    message("✅ GGIR completed successfully for pair ", i)
  }, error = function(e) {
    message("❌ GGIR failed for pair ", i, ": ", conditionMessage(e))
  })
}
