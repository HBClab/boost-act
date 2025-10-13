#!/usr/bin/env Rscript

# Usage: Rscript new_gg.R --project_dir "/Shared/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/" --deriv_dir "derivatives/GGIR-3.2.6-test/"
library(optparse)
library(GGIR)

main <- function() {
        GGIR(
          # ==== Initialization ====
          mode = 1:6,
          datadir = "/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sub-8019/accel/ses-3",
          outputdir = "/mnt/nfs/lss/vosslabhpc/Users/zak",
          studyname = "boost",
	  overwrite = TRUE,
          desiredtz = "America/Chicago",
          print.filename = TRUE,
          idloc = 6,

          # ==== Part 1: Data loading and basic signal processing ====
          do.report = c(4, 5, 6),
          epochvalues2csv = TRUE,
          do.ENMO = TRUE,
          acc.metric = "ENMO",
          windowsizes = c(5, 900, 3600),

          # ==== Part 2: Non-wear detection ====
          ignorenonwear = TRUE,

          # ==== Part 3: Sleep detection ====

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
      }

# Run main if executed as script
if (!interactive()) {
  main()
}
