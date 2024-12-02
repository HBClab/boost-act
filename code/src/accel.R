#!/usr/bin/env Rscript

#USAGE:
# cd /path/to/code/func/
# chmod +x accel.R
# ./accel.R --project_dir="path/to/project" --project_deriv_dir="path/to/derivatives" --files="file1.csv, file2.csv, file3.csv" --verbose

# Load required libraries
library(optparse)
library(tidyr)
library(plyr)
library(GGIR)

# Define command-line options
option_list <- list(
  make_option(c("-p", "--project_dir"), type="character", default="~/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data",
              help="Project directory [default= %default]", metavar="character"),
  make_option(c("-d", "--project_deriv_dir"), type="character", default="derivatives/GGIR/testing",
              help="Project derivative directory [default= %default]", metavar="character"),
  make_option(c("-f", "--files"), type="character", default=NULL,
              help="Comma-separated list of files to process", metavar="character"),
  make_option(c("-v", "--verbose"), action="store_true", default=TRUE,
              help="Print verbose output [default= %default]")
)

# Parse command-line arguments
opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)
print(opt)
cat("Project Directory:", opt$project_dir, "\n")
cat("Files:", opt$files, "\n")
# Main function
main <- function(opt) {
  # Set paths
  paths <- set_paths(opt$project_dir, opt$project_deriv_dir)
  GGIRfiles <- character(0)

  # Check if files were provided as input
  if (!is.null(opt$files)) {
    # Split the files provided as a comma-separated string
    files_to_process <- unlist(strsplit(opt$files, split=","))
    
    # Ensure the provided files exist
    GGIRfiles <- files_to_process[file.exists(files_to_process)]
    
    # Ensure GGIRfiles is a character vector and not empty
    if (is.null(GGIRfiles) || length(GGIRfiles) == 0) {
      stop("GGIRfiles is not initialized or empty or the specified files do not exist.")
    }

    cat("GGIRfiles before processing:", GGIRfiles, "\n")
    
    # Process each file directly
    for (r in GGIRfiles) {
      process_file(r, paths$ProjectDir, paths$ProjectDerivDir, opt$verbose)
    }
    
    return()  # Exit the function after processing the files
  } 
  
  # If no files are provided, proceed with the preprocessing steps
  # Gather subject directories
  subdirs <- gather_subject_directories(paths$ProjectDir)
  
  # Create output directories
  create_output_directories(paths$ProjectDir, paths$ProjectDerivDir)
  
  # List accel.csv files from subject directories
  GGIRfiles <- list_accel_files(subdirs, paths$ProjectDir)
  
  # Ensure GGIRfiles is a character vector and not empty
  if (is.null(GGIRfiles) || length(GGIRfiles) == 0) {
    stop("GGIRfiles is not initialized or empty.")
  }
  
  if (!is.character(GGIRfiles)) {
    stop("GGIRfiles must be a character vector.")
  }

  # Process each file found in the directories
  for (r in GGIRfiles) {
    process_file(r, paths$ProjectDir, paths$ProjectDerivDir, opt$verbose)
  }
}

# Function to set paths
set_paths <- function(project_dir, project_deriv_dir) {
  ProjectDir <- normalizePath(project_dir, mustWork = FALSE)
  ProjectDerivDir <- project_deriv_dir
  return(list(ProjectDir=ProjectDir, ProjectDerivDir=ProjectDerivDir))
}

# Function to gather subject directories
gather_subject_directories <- function(project_dir) {
  directories <- list.dirs(project_dir, recursive = FALSE)
  subdirs <- directories[grepl("[0-9]", directories)]
  return(subdirs)
}

# Function to create output directories
create_output_directories <- function(project_dir, project_deriv_dir) {
  output_dir <- file.path(project_dir, project_deriv_dir)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
}

# Function to list accel.csv files
list_accel_files <- function(subdirs, project_dir) {
  filepattern <- "*.csv"
  GGIRfiles <- list()
  for (subdir in subdirs) {
    files_in_subdir <- list.files(subdir, pattern=filepattern, recursive=TRUE,
                                  include.dirs=TRUE, full.names=TRUE, no..=TRUE)
    GGIRfiles <- c(GGIRfiles, files_in_subdir)
  }
  # Get relative paths
  GGIRfiles <- sapply(GGIRfiles, function(x) {
    rel_path <- substr(x, nchar(project_dir)+1, nchar(x))
    return(rel_path)
  })
  return(GGIRfiles)
}

# Function to process each file
process_file <- function(r, project_dir, project_deriv_dir, verbose=FALSE) {
  # Helper functions
  SubjectGGIRDeriv <- function(x) {
    output <- file.path(project_dir, project_deriv_dir)
    return(output)
  }
  
  datadirname <- function(x) {
    b <- dirname(x)
    outputname <- file.path(b)
    return(outputname)
  }
  
  # Define directories
  outputdir <- SubjectGGIRDeriv(r)
  datadir <- datadirname(r)
  
  # Create directory if it doesn't exist
  if (!dir.exists(outputdir)) {
    dir.create(outputdir, recursive = TRUE)
  }
  
  # Skip if output already exists
  if (dir.exists(file.path(outputdir, "output_beh"))) {
    if (verbose) cat("Skipping", r, "- output already exists.\n")
    return()
  }
  if (!dir.exists(datadir)) {
  stop("Data directory does not exist: ", datadir)
  } else {
    print("Data directory exists")
  }
  # Run GGIR
  tryCatch({
    if (verbose) {
      cat("Processing file:", r, "\n")
      cat("Data directory:", datadir, "\n")
      cat("Output directory:", outputdir, "\n")
    }
  datadir <<- datadir  # Assign as a global variable
  outputdir <<- outputdir  # Assign as a global variable
  print(r)
  session <<- strsplit("/", r)[[-2]]
  #print session
  print(session)
    g.shell.GGIR(mode = 1:5,     #Parts of GGIR to run
                 datadir = datadir,   #Path to raw files
                 outputdir = outputdir,
                 studyname = "BOOST",
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
                 ilevels = seq(0,600,by = 25),      
                 iglevels = c(seq(0,4000,by=25),8000),
                 bout.metric=4,
                 do.visual=TRUE, 
                 excludefirstlast = FALSE, 
                 includenightcrit = 0,
                 anglethreshold = 5,
                 timethreshold = 5,
                 ignorenonwear=TRUE, 
                 acc.metric="ENMO",
                 do.part3.pdf=TRUE,
                 outliers.only = FALSE,
                 def.noc.sleep = 1,
                 excludefirstlast.part5 = FALSE,
                 threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
                 boutdur.mvpa = c(1,5,10), boutdur.in = c(10,20,30), boutdur.lig = c(1,5,10),
                 boutcriter.mvpa=0.8,  boutcriter.in=0.9, boutcriter.lig=0.8,
                 timewindow=c("MM", "WW"),
                 do.report = c(2,4,5),
                 visualreport = TRUE,
                 do.parallel = TRUE)
    if (verbose) cat("GGIR processing completed for", r, "\n")
    
    # Post-processing
    post_process_file(r, project_dir, project_deriv_dir, verbose)
    
    # Re-run GGIR part 5
    #re_run_ggir_part5(r, project_dir, project_deriv_dir, verbose)
    
    # Re-run intensity gradient calculations
    #re_run_intensity_gradient(r, project_dir, project_deriv_dir, verbose)
    
  }, error=function(e) {
    cat("Error processing", r, ":", e$message, "\n")
  })
}

# Function for post-processing
post_process_file <- function(r, project_dir, project_deriv_dir, verbose=FALSE) {
  SubjectGGIRDeriv <- function(x) {
    ses <- strsplit("/", x)[[-2]]
    output <- file.path(project_dir, project_deriv_dir, ses)
    return(output)
  }
  
  session <- strsplit("/", r)[[-2]]
  outputdir <- SubjectGGIRDeriv(r)
  output_ms5 <- file.path(paste0(outputdir, "output_", session, "/meta/ms5.out"))
  output_ms5 <- file.path(paste0(outputdir, "output_", session, "/meta/ms5.out_original"))
  
  if (dir.exists(output_ms5_original)) {
    if (verbose) cat("Post-processing already done for", r, "\n")
    return()
  }
  
  # Rename ms5.out to ms5.out_original
  if (dir.exists(output_ms5)) {
    file.rename(output_ms5, output_ms5_original)
  } else {
    if (verbose) cat("ms5.out not found for", r, "\n")
    return()
  }
  
  # Load, clean, and save data
  dir <- output_ms5_original
  files <- list.files(dir)
  if (length(files) == 0) {
    if (verbose) cat("No files to process in", dir, "\n")
    return()
  }
  
  if (verbose) cat("Post-processing", length(files), "files for", r, "\n")
  
  # Initialize data frames
  removed <- data.frame(crit = c("1","3","4b","Totals"), 
                        nights = rep(0,4), 
                        participants_affected = rep(0,4),
                        participants_no_valid = rep(0,4), 
                        participants_zero_days = rep(0,4))
  removed_person <- data.frame(id = files, 
                               nights_crit1 = 0, 
                               nights_crit3 = 0,
                               nights_crit4b = 0,
                               nights_allcrit = 0)
  datacleanmm <- data.frame()
  datacleanww <- data.frame()
  
  for (i in seq_along(files)) {
    load(file.path(dir, files[i]))
    # [Insert data cleaning code here]
    # Save cleaned data
    output_ms5_clean <- file.path(outputdir, "output_beh/meta/ms5.out/")
    if (!dir.exists(output_ms5_clean)) dir.creat-e(output_ms5_clean, recursive = TRUE)
    save(output, file = file.path(output_ms5_clean, files[i]))
  }
  
  # Write CSV files
  writepath <- file.path(outputdir, "output_beh/meta")
  if (!dir.exists(writepath)) dir.create(writepath, recursive = TRUE)
  write.csv(removed, file.path(writepath, "excluded_nights.csv"), row.names = FALSE)
  write.csv(removed_person, file.path(writepath, "excluded_nights_person.csv"), row.names = FALSE)
  write.csv(datacleanmm, file.path(writepath, "dcleanmm.csv"), row.names = FALSE)
  write.csv(datacleanww, file.path(writepath, "dcleanww.csv"), row.names = FALSE)
  
  if (verbose) cat("Post-processing completed for", r, "\n")
}

# Function to re-run GGIR part 5
re_run_ggir_part5 <- function(r, project_dir, project_deriv_dir, verbose=FALSE) {
  SubjectGGIRDeriv <- function(x) {
    a <- dirname(x)
    output <- file.path(project_dir, project_deriv_dir, a)
    return(output)
  }
  
  outputdir <- SubjectGGIRDeriv(r)
  if (file.exists(file.path(outputdir, "GGIRcomplete.csv"))) {
    if (verbose) cat("GGIR part 5 already re-run for", r, "\n")
    return()
  }
  
  datadir <- dirname(file.path(project_dir, r))
  writepath <- file.path(outputdir, "output_beh/meta")
  datacleanmmpath <- file.path(writepath, "dcleanmm.csv")
  datacleanwwpath <- file.path(writepath, "dcleanww.csv")
  metadatadir <- file.path(outputdir, "output_beh")
  
  tryCatch({
    if (verbose) cat("Re-running GGIR part 5 for MM window for", r, "\n")
    g.shell.GGIR(mode = 5,
                 metadatadir = metadatadir,
                 datadir = datadir,
                 outputdir = outputdir,
                 overwrite = TRUE,
                 excludefirstlast.part5 = FALSE,
                 threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
                 boutdur.mvpa = c(1,5,10), boutdur.in = c(10,20,30), boutdur.lig = c(1,5,10),
                 boutcriter.mvpa=0.8,  boutcriter.in=0.9, boutcriter.lig=0.8,
                 timewindow=c("MM"),
                 acc.metric = "ENMO",
                 data_cleaning_file=datacleanmmpath,
                 do.report = c(5),
                 visualreport = TRUE,
                 do.parallel = TRUE)
    
    if (verbose) cat("Re-running GGIR part 5 for WW window for", r, "\n")
    g.shell.GGIR(mode = 5,
                 metadatadir = metadatadir,
                 datadir = datadir,
                 outputdir = outputdir,
                 overwrite = TRUE,
                 excludefirstlast.part5 = FALSE,
                 threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
                 boutdur.mvpa = c(1,5,10), boutdur.in = c(10,20,30), boutdur.lig = c(1,5,10),
                 boutcriter.mvpa=0.8,  boutcriter.in=0.9, boutcriter.lig=0.8,
                 timewindow=c("WW"),
                 acc.metric = "ENMO",
                 data_cleaning_file=datacleanwwpath,
                 do.report = c(5),
                 visualreport = TRUE,
                 do.parallel = TRUE)
    
    # Create a completion file
    file.create(file.path(outputdir, "GGIRcomplete.csv"))
  }, error=function(e) {
    cat("Error re-running GGIR part 5 for", r, ":", e$message, "\n")
  })
}

# Function to re-run intensity gradient calculations
re_run_intensity_gradient <- function(r, project_dir, project_deriv_dir, verbose=FALSE) {
  SubjectGGIRDeriv <- function(x) {
    a <- dirname(x)
    output <- file.path(project_dir, project_deriv_dir, a)
    return(output)
  }
  
  outputdir <- SubjectGGIRDeriv(r)
  results_path <- file.path(outputdir, "output_beh/results/")
  if (file.exists(file.path(results_path, "part2_cleanedIntensityGradient.csv"))) {
    if (verbose) cat("Intensity gradient calculations already done for", r, "\n")
    return()
  }
  
  tryCatch({
    part2_path <- file.path(results_path, "part2_daysummary.csv")
    part5_path <- file.path(results_path, "part5_daysummary_MM_L45M100V430_T5A5.csv")
    if (!file.exists(part2_path) || !file.exists(part5_path)) {
      if (verbose) cat("Required files for intensity gradient not found for", r, "\n")
      return()
    }
    part2 <- read.csv(part2_path)
    part2 <- part2[c("filename","measurementday","ig_gradient_ENMO_0.24hr","ig_intercept_ENMO_0.24hr","ig_rsquared_ENMO_0.24hr")]
    part5 <- read.csv(part5_path)
    part5 <- part5[c("window_number")]
    part2cleaned <- merge(part2, part5, by.x="measurementday", by.y="window_number")
    
    igpathday <- file.path(results_path, "part2_day_cleanedIntensityGradient.csv")
    write.csv(part2cleaned, igpathday, row.names=FALSE)
    
    part2cleanedperson <- data.frame(
      filename = unique(part2cleaned$filename),
      ndays = nrow(part2cleaned),
      AD_ig_gradient_ENMO_0.24hr = mean(part2cleaned$ig_gradient_ENMO_0.24hr),
      AD_ig_intercept_ENMO_0.24hr = mean(part2cleaned$ig_intercept_ENMO_0.24hr),
      AD_ig_ig_rsquared_ENMO_0.24hr = mean(part2cleaned$ig_rsquared_ENMO_0.24hr)
    )
    igpath <- file.path(results_path, "part2_person_cleanedIntensityGradient.csv")
    write.csv(part2cleanedperson, igpath, row.names=FALSE)
    if (verbose) cat("Intensity gradient calculations completed for", r, "\n")
  }, error=function(e) {
    cat("Error in intensity gradient calculations for", r, ":", e$message, "\n")
  })
}

# Run the main function
main(opt)
