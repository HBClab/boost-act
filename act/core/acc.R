#!/usr/bin/env Rscript

library(tidyr)
library(plyr)
library(optparse)
library(GGIR)

main <- function() {
  # Define the option list
  option_list <- list(
    make_option(c("-p", "--project_dir"), type="character", 
                default="/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-Experiment/data/act-int-test/",
                help="Path to the project directory", metavar="character"),
    make_option(c("-d", "--deriv_dir"), type="character", 
                default="/derivatives/GGIR-2.8.2-test2/",
                help="Path to the derivatives directory", metavar="character")
  )

  # Parse the options
  opt_parser <- OptionParser(option_list=option_list)
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

  # Create project-specific derivatives GGIR folder if it doesn't already exist
  if (!dir.exists(paste0(ProjectDir, ProjectDerivDir))) {
    dir.create(paste0(ProjectDir, ProjectDerivDir))
  }

  # List accel.csv files within subject-specific folders
  filepattern <- "*accel.csv"
  GGIRfiles <- list.files(subdirs, pattern = filepattern, recursive = TRUE,  
                          include.dirs = TRUE, full.names = TRUE, no.. = TRUE)
  print(paste("GGIR Files before splitting: ", GGIRfiles))

  # Split files at the "//" so we only have paths from sub-XXX/ses-.....
  GGIRfiles <- sapply(strsplit(GGIRfiles, "//", fixed = TRUE), function(x) paste(x[2]))

  print(paste("GGIR Files after splitting: ", GGIRfiles))


  # Ensure directory structure exists for GGIR processing
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
      datadir <- paste0(normalize(path(datadirname(r)))
      outputdir <- paste0(SubjectGGIRDeriv(r))
      print(paste("datadir: ", datadir))
      print(paste("outputdir: ", outputdir))
      if (!dir.exists(datadir)) {
        stop(paste("Error: datadir does not exist ->", datadir))
      }
    # Force evaluation before calling GGIR
    assign("datadir", datadir, envir = .GlobalEnv)
    assign("outputdir", outputdir, envir = .GlobalEnv)

      try(g.shell.GGIR(
        mode = 1:5,
        datadir = get("datadir", envir = .GlobalEnv),
        outputdir = get("outputdir", envir = .GlobalEnv),
        overwrite = FALSE,
        print.filename = TRUE,
        storefolderstructure = FALSE,
        windowsizes = c(5, 900, 3600),
        desiredtz = "America/Chicago",
        do.enmo = TRUE, do.anglez = TRUE,
        dayborder = 0,
        strategy = 1, hrs.del.start = 0, hrs.del.end = 0,
        maxdur = 0, includedaycrit = 0,
        idloc = 1,
        dynrange = 8,
        chunksize = 1,
        do.cal = TRUE,
        use.temp = FALSE,
        spherecrit = 0.3,
        minloadcrit = 72,
        printsummary = TRUE,
        do.imp = TRUE,
        epochvalues2csv = TRUE,
        L5M5window = c(0,24),
        M5L5res = 10,
        winhr = c(5,10),
        qlevels = c(960/1440, 1320/1440, 1380/1440, 1410/1440, 1430/1440, 1435/1440, 1438/1440),
        ilevels = seq(0,600, by = 25),
        iglevels = c(seq(0,4000, by = 25), 8000),
        bout.metric = 4,
        do.visual = TRUE,
        excludefirstlast = FALSE,
        includenightcrit = 0,
        anglethreshold = 5,
        timethreshold = 5,
        ignorenonwear = TRUE,
        acc.metric = "ENMO",
        do.part3.pdf = TRUE,
        outliers.only = FALSE,
        def.noc.sleep = 1,
        excludefirstlast.part5 = FALSE,
        maxdur = 0,
        threshold.lig = c(45),
        threshold.mod = c(100),
        threshold.vig = c(430),
        boutdur.mvpa = c(1,5,10),
        boutdur.in = c(10,20,30),
        boutdur.lig = c(1,5,10),
        boutcriter.mvpa = 0.8,
        boutcriter.in = 0.9,
        boutcriter.lig = 0.8,
        timewindow = c("MM", "WW"),
        acc.metric = "ENMO",
        do.report = c(2,4,5),
        visualreport = TRUE,
        do.parallel = TRUE
      ))
    }
  }
}

# Run main if executed as a script
if (!interactive()) {
  main()
}
