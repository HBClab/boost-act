
/mnt/lss/Users/zak/ggir


#!/usr/bin/env Rscript

# Usage: Rscript new_gg.R --project_dir "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/" --deriv_dir "derivatives/GGIR-3.2.6-test/"
library(GGIR)

main <- function() {

  # Assign variables
  ProjectDir <- "/Shared/vosslabhpc/Users/zak/files"
  ProjectDerivDir <- "/derivatives/ggir/"

  # Print values to verify
  print(paste("Project Directory:", ProjectDir))
  print(paste("Derivatives Directory:", ProjectDerivDir))

  # Helper function
  SubjectGGIRDeriv <- function(x) {
    a <- dirname(x)
    paste0(ProjectDir, ProjectDerivDir, a)
  }

  datadirname <- function(x) {
    b <- dirname(x)
    paste0(ProjectDir, b)
  }

  # Gather subject directories
  directories <- list.dirs(ProjectDir, recursive = FALSE)
  subdirs <- directories[grepl("sub-*", directories)]
  print(paste("subdirs: ", subdirs))

  # Create project-specific derivatives GGIR folder if it doesn't exist
  if (!dir.exists(paste0(ProjectDir, ProjectDerivDir))) {
    dir.create(paste0(ProjectDir, ProjectDerivDir))
  }

  # List accel.csv files
  filepattern <- "*accel.gt3x"
  GGIRfiles <- list.files(subdirs, pattern = filepattern, recursive = TRUE,
                          include.dirs = TRUE, full.names = TRUE, no.. = TRUE)
  print(paste("GGIR Files before splitting: ", GGIRfiles))

  # Adjust path formatting
  GGIRfiles <- sapply(strsplit(GGIRfiles, "//", fixed = TRUE), function(x) paste(x[2]))
  print(paste("GGIR Files after splitting: ", GGIRfiles))

  # Ensure directory structure exists
  for (i in GGIRfiles) {
    if (!dir.exists(SubjectGGIRDeriv(i))) {
      dir.create(SubjectGGIRDeriv(i), recursive = TRUE)
    }
  }

  # Run GGIR loop
  for (r in GGIRfiles) {
    if (dir.exists(paste0(SubjectGGIRDeriv(r), "/output_beh"))) {
      next
    } else {
      datadir <- normalizePath(datadirname(r), mustWork = FALSE)
      outputdir <- SubjectGGIRDeriv(r)
      print(paste("datadir: ", datadir))
      print(paste("outputdir: ", outputdir))
      if (!dir.exists(datadir)) {
        stop(paste("Error: datadir does not exist ->", datadir))
      }

      assign("datadir", datadir, envir = .GlobalEnv)
      assign("outputdir", outputdir, envir = .GlobalEnv)

      try({
        GGIR(
          # ==== Initialization ====
          mode = 1:6,
          datadir = datadir,
          outputdir = outputdir,
          studyname = "boost",
          overwrite = FALSE,
          desiredtz = "America/Chicago",
          print.filename = TRUE,
          idloc = 2,
          save_ms5rawlevels = "csv"

          # ==== Part 1: Data loading and basic signal processing ====
          do.report = c(2, 4, 5, 6),
          epochvalues2csv = TRUE,
          do.ENMO = TRUE,
          acc.metric = "ENMO",
          windowsizes = c(5, 900, 3600),

          # ==== Part 2: Non-wear detection ====
          ignorenonwear = TRUE,

          # ==== Part 3: Sleep detection (optional if using external file) ====
          # Uncomment the below if using external sleep log:
          # loglocation = "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sleep.csv",
          # colid = 1,
          # coln1 = 2,
          # sleepwindowType = "SPT",

          # ==== Part 4: Physical activity summaries ====
          timewindow = c("WW", "MM", "OO"),

          # ==== Part 5: Day-level summaries ====
          hrs.del.start = 4,
          hrs.del.end = 3,
          maxdur = 9,
          threshold.lig = 44.8,
          threshold.mod = 100.6,
          threshold.vig = 428.8,

          # ==== Part 6: CR and other metrics ====
          part6CR = TRUE,
          visualreport = TRUE,
          old_visualreport = FALSE
        )
      })
    }
  }
}

# Run main if executed as script
if (!interactive()) {
  main()
}

