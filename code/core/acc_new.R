
#!/usr/bin/env Rscript

# Usage: Rscript new_gg.R --project_dir "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/" --deriv_dir "derivatives/GGIR-3.2.6-test/"
library(optparse)
library(GGIR)

main <- function() {
  # Define the option list
  option_list <- list(
    make_option(c("-p", "--project_dir"), type = "character",
                default = "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-Experiment/data/act-int-test/",
                help = "Path to the project directory", metavar = "character"),
    make_option(c("-d", "--deriv_dir"), type = "character",
                default = "/derivatives/GGIR-3.2.6-test/",
                help = "Path to the derivatives directory", metavar = "character")
  )

  # Parse the options
  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)

  # Assign variables
  ProjectDir <- opt$project_dir
  ProjectDerivDir <- opt$deriv_dir

  # Print values to verify
  print(paste("Project Directory:", ProjectDir))
  print(paste("Derivatives Directory:", ProjectDerivDir))

  # Helper functions
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
  filepattern <- "*accel.csv"
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
          mode = 1:6,
          datadir = datadir,
          outputdir = outputdir,
          studyname = "boost",
          overwrite = FALSE,
          do.report = c(2, 4, 5, 6),
          visualreport = TRUE,
          old_visualreport = FALSE,
          windowsizes = c(5, 900, 3600),
          desiredtz = "America/Chicago",
          print.filename = TRUE,
          dayborder = 0,
          idloc = 2,
          epochvalues2csv = TRUE,
          ignorenonwear = TRUE,
          do.ENMO = TRUE,
          acc.metric = "ENMO",
          hrs.del.start = 4,
          hrs.del.end = 3,
          maxdur = 9,
          loglocation = "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sleep.csv",
          colid = 1,
          coln1 = 2,
          sleepwindowType = "SPT",
          timewindow = c("WW", "MM", "OO"),
          part6CR = TRUE
        )
      })
    }
  }
}

# Run main if executed as script
if (!interactive()) {
  main()
}
