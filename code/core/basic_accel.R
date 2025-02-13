#!/usr/bin/env Rscript
# ./process_single_file.R --input_file="/path/to/input.csv" --output_location="/path/to/output" --verbose
# Load required libraries
# (Include any other libraries your processing function requires)
# For example, if ggir is used, make sure it is installed and loaded:
# library(ggir)
interactive_session <- FALSE
suppressMessages(library(optparse))

# Define command-line options: input_file and output_location (plus an optional verbose flag)
option_list <- list(
  make_option(c("-i", "--input_file"), type="character", default=NULL,
              help="Path to the input file to process", metavar="FILE"),
  make_option(c("-o", "--output_location"), type="character", default=NULL,
              help="Path to the output directory where results will be written", metavar="DIR"),
  make_option(c("-v", "--verbose"), action="store_true", default=FALSE,
              help="Print verbose output")
)

# Parse command-line arguments
opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

# Check that both input_file and output_location are provided
if (is.null(opt$input_file) || is.null(opt$output_location)) {
  print_help(opt_parser)
  stop("Both --input_file and --output_location must be specified.", call.=FALSE)
}

# Verify the input file exists; if not, stop with an error
if (!file.exists(opt$input_file)) {
  stop("Input file does not exist: ", opt$input_file, call.=FALSE)
}

# If the output directory does not exist, create it
if (!dir.exists(opt$output_location)) {
  if (opt$verbose) cat("Output directory does not exist; creating:", opt$output_location, "\n")
  dir.create(opt$output_location, recursive = TRUE)
}

if (opt$verbose) {
  cat("Input file:", opt$input_file, "\n")
  cat("Output directory:", opt$output_location, "\n")
}

# Define a function to process the input file.
# (This is an example using ggir’s processing; adjust parameters as needed.)
process_file <- function(input_file, output_dir, verbose = FALSE) {
  # Use the directory containing the input file as the data directory.
  data_dir <- dirname(normalizePath(input_file))

  if (verbose) {
    cat("Data directory (from input file):", data_dir, "\n")
    cat("Processing file:", input_file, "\n")
  }

  # Call the processing function (here assumed to be g.shell.ggir)
  # Adjust the arguments below to suit your processing needs.
  tryCatch({
    if (verbose) cat("Starting ggir processing...\n")
        g.shell.ggir(
        mode = 1:5,                    # Parts of ggir to run
        datadir = data_dir,            # Use the directory where the input file resides
        outputdir = output_dir,        # Write outputs to the provided output directory
        studyname = "boost",
        overwrite = FALSE,
        print.filename = TRUE,
        storefolderstructure = FALSE,
        windowsizes = c(5, 900, 3600),
        desiredtz = "america/chicago",
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
        l5m5window = c(0, 24),
        m5l5res = 10,
        winhr = c(5, 10),
        qlevels = c(960/1440, 1320/1440, 1380/1440, 1410/1440, 1430/1440, 1435/1440, 1438/1440),
        ilevels = seq(0, 600, by = 25),
        iglevels = c(seq(0, 4000, by = 25), 8000),
        bout.metric = 4,
        do.visual = TRUE,
        excludefirstlast = FALSE,
        includenightcrit = 0,
        anglethreshold = 5,
        timethreshold = 5,
        ignorenonwear = TRUE,
        acc.metric = "enmo",
        do.part3.pdf = TRUE,
        outliers.only = FALSE,
        def.noc.sleep = 1,
        excludefirstlast.part5 = FALSE,
        threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
        boutdur.mvpa = c(1, 5, 10), boutdur.in = c(10, 20, 30), boutdur.lig = c(1, 5, 10),
        boutcriter.mvpa = 0.8, boutcriter.in = 0.9, boutcriter.lig = 0.8,
        timewindow = c("mm", "ww"),
        do.report = c(2, 4, 5),
        visualreport = TRUE,
        do.parallel = TRUE
        )

    if (verbose) cat("ggir processing completed for", input_file, "\n")
  }, error = function(e) {
    cat("Error processing", input_file, ":", e$message, "\n")
  })
}

# Run the processing function on the provided input file
process_file(opt$input_file, opt$output_location, opt$verbose)
