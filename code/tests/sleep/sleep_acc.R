#!/usr/bin/env Rscript

# The following code is used for testing sleep logs in GGIR. 
# Sleep logs are in the root folder of the accel directory,
# a better place is needed but for testing purposes it will do.
library(GGIR)

# first test on intervention - since there are less subjects
ProjectDir <- "/Shared/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/"
ProjectDerivDir <- "derivatives/GGIR-3.2.6/"

# Extract final folder name
last_folder <- basename(ProjectDir)

# Determine correct filename
if (grepl("act-obs", last_folder, fixed = TRUE)) {
  SleepLog <- file.path(ProjectDir, "sleep_log_observational.csv")
} else if (grepl("act-int", last_folder, fixed = TRUE)) {
  SleepLog <- file.path(ProjectDir, "sleep_log_intervention.csv")
} else {
  stop("Unrecognized project directory. Exiting.")
}

# Print values to verify
print(paste("Project Directory:", ProjectDir))
print(paste("Derivatives Directory:", ProjectDerivDir))
print(paste("SleepLog Location"))


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
        idloc = 6, # six is the dot character, needed for use of sleep logs

        # ==== Part 1: Data loading and basic signal processing ====
        do.report = c(2, 4, 5, 6),
        epochvalues2csv = TRUE,
        do.ENMO = TRUE,
        acc.metric = "ENMO",
        windowsizes = c(5, 900, 3600),

        # ==== Part 2: Non-wear detection ====
        ignorenonwear = TRUE,

        # ==== Part 3: Sleep detection ====
        # Uncomment the below if using external sleep log:
        loglocation = "/Shared/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/sleep_log_observational.csv",

        colid = 1,
        coln1 = 2,
        sleepwindowType = "TimeInBed",

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

