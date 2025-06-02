### Post-processing paths 


### .ms5 will be in your output dir, will tack on "output_(folder name of data dir) to your output dir
output.ms5path="/output_beh/meta/ms5.out/"
### same thing as output.ms5 but add _original
output.ms5_originalpath="/output_beh/meta/ms5.out_original/"
### path where you want to write out the datacleaning files and info from post-processing
writepaths="/output_beh/meta"
### where your /meta folder will be after the first GGIR run. outputdir/output_datadirfoldername

 

###
Goal: remove days with <16 hours worn, remove nights with less than 240 min, remove nights wake time, onset, and duration differ by more than 3 hours, output as .csv readable by data_cleaning_file parameter in ggir part 5
crit1 = diff bedtime, diff waketime, diff sleep duration
crit3 = sleep onset between 12pm and 7pm, sleep wake time between 1pm and midnight
crit4b = less than 4 hours of sleep


# remove participants from list that need follow-up for errors
GGIRfiles <- GGIRfiles[!grepl("*sub-2385_*",GGIRfiles)]
# GGIRfiles <- GGIRfiles[!grepl("*sub-2100_*",GGIRfiles)]


library(plyr)



### Post Processing Script Adapted From Jairo Miguelues Script


for (r in GGIRfiles){
  # rename original output to preserve before data cleaning

  if (dir.exists(paste0(SubjectGGIRDeriv(r),output.ms5_originalpath))==TRUE){
    next
  } else{
    file.rename(paste0(SubjectGGIRDeriv(r),output.ms5path), paste0(SubjectGGIRDeriv(r),output.ms5_originalpath))
  
    # define directory with original data
    dir = paste0(SubjectGGIRDeriv(r),output.ms5_originalpath)
  
    # lists files in the dir directory
    files = dir(paste0(SubjectGGIRDeriv(r),output.ms5_originalpath))
    
    output.ms5 = paste0(SubjectGGIRDeriv(r), output.ms5path)
      
    output.ms5_original = paste0(SubjectGGIRDeriv(r), output.ms5_originalpath)
    
    writepath = paste0(SubjectGGIRDeriv(r), writepaths)
      
    for(i in 1:length(files)){
    # to uderstand this try paste0(dir,files[1])
      load(paste0(dir,files[i]))
      del = c()
      del.tmp1 = del.tmp3 = del.tmp4b = NA
      
      # ls() == F asks is object in list of env objects, T/F
      if("removed" %in% ls() == F){
        # below is making a dataframe called removed with variables crit, nights, participants_affected, etc.
        # rep(0,4) fills the values for those variables with 0 across the 4 columns
        removed = data.frame(crit = c("1","3","4b","Totals"), 
                             nights = rep(0,4), 
                             participants_affected = rep(0,4),
                             participants_no_valid = rep(0,4), 
                             participants_zero_days = rep(0,4))
      }
      
      # below is making a dataframe called removed_person with first variable as id (filename) 
      # and fills other variables with 0
      if("removed_person" %in% ls() == F){
        removed_person = data.frame(id = files, 
                                    nights_crit1 = 0, 
                                    nights_crit3 = 0,
                                    nights_crit4b = 0,
                                    nights_allcrit = 0)
      }
      
      if("datacleanmm" %in% ls() == F){
        datacleanmm = data.frame(ID = "",
                                 day_part5 = "",
                                 relyonguider_part4 = "",
                                 night_part4 = "")
      }
       if("datacleanww" %in% ls() == F){
        datacleanww = data.frame(ID = "",
                                 day_part5 = "",
                                 relyonguider_part4 = "",
                                 night_part4 = "")
      }
      
      if("parts_1" %in% ls() == F) parts_1 = 0
      if("parts_3" %in% ls() == F) parts_3 = 0
      if("parts_4b" %in% ls() == F) parts_4b = 0
      
      # Valid hours
      # output refers to file for given person in the list
      # question: window_length_in_hours is not a variable in output; is that a version issue or change in GGIR call
      # can nonwear_perc_day work?
      # Yes, version issue. Is now specified as window_length_in_hours_pla and window_length_in_hours_wei
      ## using dur_day_spt_min
      del = which(as.numeric(output$dur_day_spt_min) < 960)
      if(length(del) > 0) output_del <- output[del,]
      
      
      delwear = which(as.numeric(output$nonwear_perc_day) > 33)
      if(length(delwear) > 0) output_delwear <- output[delwear,]
      
      del.rem = unique(c(del,delwear))
      if(length(del) > 0|length(delwear) > 0) output.del.rem <- output[del.rem,]
      
      if(length(del) > 0) output = output[-del,]
      if(length(delwear) > 0) output = output[-delwear,]
      # Crit. 1
      # Check if sleep onset or wake time differed > 3 hours from mean of all this participants recording periods
      
      # acc_wake and acc_onset and dur_night_min don't exist; are sleeponset and wakeup equivalent?
      ## version issue, acc_onset_pla and acc_onset_wei, dur_night_min_pla dur_night_min_wei
      diff_wake = as.numeric(output$wakeup) - mean(as.numeric(output$wakeup), na.rm = T)
      diff_onset = as.numeric(output$sleeponset) - mean(as.numeric(output$sleeponset), na.rm = T)
      diff_bedtime = (as.numeric(output$dur_spt_sleep_min) - mean(as.numeric(output$dur_spt_sleep_min)))/60
      
      if("affected1" %in% ls() == F) affected1 = c()
      crit1 = FALSE
      if(TRUE %in% (abs(diff_bedtime) > 3) & TRUE %in% (abs(diff_wake) > 3)){
        bedtime = which(abs(diff_bedtime) > 3)
        wake = which(abs(diff_wake) > 3)
        if(length(intersect(bedtime, wake)) > 0) crit1 = TRUE
      }
      
      if(TRUE %in% (abs(diff_bedtime) > 3) & TRUE %in% (abs(diff_onset) > 3)){
        bedtime = which(abs(diff_bedtime) > 3)
        onset = which(abs(diff_onset) > 3)
        if(length(intersect(bedtime, onset)) > 0) crit1 = TRUE
      }
      
      if(crit1 == TRUE){
        affected1 = c(affected1,i)
        del.tmp1 = c(which(abs(diff_wake) > 3 & abs(diff_bedtime) > 3), 
                     which(abs(diff_onset) > 3 & abs(diff_bedtime) > 3))
        del.tmp1 = unique(del.tmp1)
        output.tmp = output[-del.tmp1,]
        
        parts_1 = parts_1 + 1
        no_weekends = length(which(output.tmp$weekday == "Saturday" | output.tmp$weekday == "Sunday"))
        novalid = ifelse((nrow(output.tmp) < 4 | (nrow(output.tmp) - no_weekends) < 3 | no_weekends < 1), 1, 0)
        zerodays = ifelse(nrow(output.tmp) == 0,1,0)
        
        removed[1,2:5] = c((as.numeric(removed[1,2]) + length(del.tmp1)), 
                           parts_1, 
                           (as.numeric(removed[1,4]) + novalid),
                           (as.numeric(removed[1,5]) + zerodays))
      }
      
      # Crit. 3
      # need acc_onset and acc_wake or equivalent
      onset_time = as.numeric(output$sleeponset) > 12 & as.numeric(output$sleeponset) < 19
      wake_time = as.numeric(output$wakeup) > 13 & as.numeric(output$wakeup) < 24
      if(TRUE %in% onset_time | TRUE %in% wake_time){
        del.tmp3 = c(which(onset_time == T), which(wake_time == T))
        output.tmp = output[-del.tmp3,]
        
        parts_3 = parts_3 + 1
        no_weekends = length(which(output.tmp$weekday == "Saturday" | output.tmp$weekday == "Sunday"))
        novalid = ifelse((nrow(output.tmp) < 4 | (nrow(output.tmp) - no_weekends) < 3 | no_weekends < 1), 1, 0)
        zerodays = ifelse(nrow(output.tmp) == 0,1,0)
        removed[2,2:5] = c((as.numeric(removed[2,2]) + length(del.tmp3)), 
                           parts_3, 
                           (as.numeric(removed[2,4]) + novalid),
                           (as.numeric(removed[2,5]) + zerodays))  
      }
      
      # Crit. 4b
      # need dur_night_min or equivalent
      if(TRUE %in% (as.numeric(output$dur_spt_sleep_min) < 4*60)){
        del.tmp4b = which(as.numeric(output$dur_spt_sleep_min) < 4*60)
        output.tmp = output[-del.tmp4b,]
        
        parts_4b = parts_4b + 1
        no_weekends = length(which(output.tmp$weekday == "Saturday" | output.tmp$weekday == "Sunday"))
        novalid = ifelse((nrow(output.tmp) < 4 | (nrow(output.tmp) - no_weekends) < 3 | no_weekends < 1), 1, 0)
        zerodays = ifelse(nrow(output.tmp) == 0,1,0)
        removed[3,2:5] = c((as.numeric(removed[3,2]) + length(del.tmp4b)), 
                           parts_4b, 
                           (as.numeric(removed[3,4]) + novalid),
                           (as.numeric(removed[3,5]) + zerodays))    
      }
      
      del.tmp = unique(c(del.tmp1, del.tmp3, del.tmp4b))
      del.tmp = del.tmp[is.na(del.tmp) == FALSE]
      if(length(del.tmp) > 0) output_del.tmp = output[del.tmp,]
      if(length(del.tmp) > 0) output = output[-del.tmp,]
      
      
      # Removed totals summary 
      parts.comb = ifelse(length(del.tmp) == 0, 0, 1)
      no_weekends = length(which(output$weekday == "Saturday" | output$weekday == "Sunday"))
      novalid = ifelse((nrow(output) < 4 | (nrow(output) - no_weekends) < 3 | no_weekends < 1), 1, 0)
      zerodays = ifelse(nrow(output) == 0,1,0)
      
     
      if(novalid == 1) print(paste("novalid:",i))
      if(zerodays == 1) print(paste("ZERO:",i))
    
      
      removed[4,1:5] = c("Totals", 
                         (as.numeric(removed[4,2]) + length(del.tmp)), 
                         (as.numeric(removed[4,3]) + parts.comb), 
                         (as.numeric(removed[4,4]) + novalid),
                         (as.numeric(removed[4,5]) + zerodays))
      
      removed_person[i,2:5] = c(sum(del.tmp1 > 0, na.rm = T), 
                                sum(del.tmp3 > 0, na.rm = T), 
                                sum(del.tmp4b > 0, na.rm = T), 
                                sum(unique(c(del.tmp1,del.tmp3,del.tmp4b)) > 0, na.rm = T))
      
      ### del is days and nights to remove because less than 16 hrs (940 mins), del.wear is more than 33% non-wear time (not equivalent to the 16 hrs per day that GGIR can set). del.rem is unique combination of these two.
     
      if (exists("output.del.rem") == TRUE) del.rem.MM <- subset(output.del.rem, output.del.rem$window == "MM")
      if (exists("output.del.rem") == TRUE) del.rem.WW <- subset(output.del.rem, output.del.rem$window == "WW")
      #output_del.tmp is nights to remove for sleep, subset for mm and ww
      if (exists("output_del.tmp") == TRUE) output_del.tmp.MM <- subset(output_del.tmp, output_del.tmp$window == "MM")
      if (exists("output_del.tmp") == TRUE) output_del.tmp.WW <-subset(output_del.tmp, output_del.tmp$window == "WW")
    
      
      ### add in the day and night removals for GGIR data_cleaning_file template
      cols <- c("ID", "window_number","night_number")
      if (exists("del.rem.MM") == TRUE) del.rem.MM.tmp <- del.rem.MM[cols]
      if (exists("del.rem.MM.tmp") == TRUE) colnames(del.rem.MM.tmp) <- c("ID", "day_part5","night_part4")
      if (exists("del.rem.WW") == TRUE) del.rem.WW.tmp <- del.rem.WW[cols]
      if (exists("del.rem.WW.tmp") == TRUE)colnames(del.rem.WW.tmp) <- c("ID", "day_part5","night_part4")
      
      ### add in the sleep removals for GGIR data_cleaning_file template
      colssleep <- c("ID","night_number")
      if (exists("output_del.tmp") == TRUE) output_del.tmp.MM.tmp <- output_del.tmp.MM[colssleep]
      if (exists("output_del.tmp") == TRUE) colnames(output_del.tmp.MM.tmp) <- c("ID", "night_part4")
      if (exists("output_del.tmp") == TRUE) output_del.tmp.WW.tmp <- output_del.tmp.WW[colssleep]
      if (exists("output_del.tmp") == TRUE) colnames(output_del.tmp.WW.tmp) <- c("ID", "night_part4")
      ### combine day and night removals, and just night removals
      # fill in non-overlapping columns with NAs
      
      if (exists("del.rem.MM.tmp") == TRUE) datacleanmm <- rbind.fill(datacleanmm,del.rem.MM.tmp)
      if (exists("output_del.tmp") == TRUE) datacleanmm <- rbind.fill(datacleanmm,output_del.tmp.MM.tmp)
      datacleanmm = datacleanmm[-1,]
      
      if (exists("del.rem.WW.tmp") == TRUE) datacleanww <- rbind.fill(datacleanww,del.rem.WW.tmp)
      if (exists("output_del.tmp") == TRUE) datacleanww <- rbind.fill(datacleanww,output_del.tmp.WW.tmp)
      datacleanww = datacleanww[-1,]
      
        
      if(dir.exists(output.ms5) == FALSE) dir.create(output.ms5)
      
      save(output, file = paste0(output.ms5, files[i]))
      #save(output, file = paste0(output.ms5, files))
      
      removedpath=file.path(paste0(writepath),"excluded_nights.csv")
      removed_personpath=file.path(paste0(writepath),"excluded_nights_person.csv")
      datacleanmmpath=file.path(paste0(writepath),"dcleanmm.csv")
      datacleanwwpath=file.path(paste0(writepath),"dcleanww.csv")
      if(i == length(files)){
        write.csv(removed, removedpath, row.names = F)
        write.csv(removed_person, removed_personpath, row.names = F)
        write.csv(datacleanmm, datacleanmmpath,row.names = F)
        write.csv(datacleanww, datacleanwwpath,row.names = F)
      rm("del.rem.WW.tmp", "del.rem.WW","datacleanmm","datacleanww","del.rem.MM","del.rem.MM.tmp","output","output_delwear","output.del.rem","removed","removed_person","affected1", "cols","colssleep","crit1","datacleanmmpath", "datacleanwwpath", "del","del.rem","del.tmp", "del.tmp1","del.tmp3","del.tmp4b", "delwear","diff_bedtime","diff_onset","diff_wake","no_weekends","novalid","onset_time","parts_1", "parts_3","parts_4b","parts.comb","removed_personpath","removedpath", "wake_time","zerodays","output_del.tmp.MM.tmp","output_del.tmp.WW.tmp","output_del.tmp.WW.tmp","onset","bedtime","output_del.tmp","output_del.tmp.MM","output.del_tmp.MM","output.tmp","output_del.tmp.WW")
  }
}
  }
}


# Re-run GGIR part 5 based on post-procesisng and write new database after removing abnormal days from subject-level .R dataframes, for both mm window and ww window 
# creates a blank CSV "GGIRcomplete" when done, then checks for that file in future runs to keep from running every time




# metadatadir = file.path(outputdir, "output_beh")
for (r in GGIRfiles){
  if (file.exists(paste0(SubjectGGIRDeriv(r),"/GGIRcomplete.csv"))==TRUE){
    next
  } else{
    
    datadir = paste0(datadirname(r))
    outputdir = paste0(SubjectGGIRDeriv(r))
    datacleanmmpath = paste0(SubjectGGIRDeriv(r),writepaths,"/dcleanmm.csv")
    datacleanwwpath = paste0(SubjectGGIRDeriv(r),writepaths,"/dcleanww.csv")
    metadatadir = file.path(outputdir,"output_beh")
    
    try(g.shell.GGIR(mode = 5,     #Parts of GGIR to run
             # Basic Settings
             metadatadir = metadatadir,
             datadir = datadir,   #Path to raw files
             outputdir = outputdir,
             overwrite = TRUE,
             
              # FINAL ESTIMATES (g.part5 arguments):
             excludefirstlast.part5 = FALSE,
             maxdur = 0,   # Maximum number of days (0 will process all days, set it to 7 if you want to constraint)
             threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
             boutdur.mvpa = c(1,5,10), boutdur.in = c(10,20,30), boutdur.lig = c(1,5,10),
             boutcriter.mvpa=0.8,  boutcriter.in=0.9, boutcriter.lig=0.8,
             timewindow=c("MM"),
             acc.metric = "ENMO",
             data_cleaning_file=datacleanmmpath,
             
             # Reports
             do.report = c(5),
             visualreport = TRUE,
             do.parallel = TRUE))
    
    try(g.shell.GGIR(mode = 5,     #Parts of GGIR to run
             # Basic Settings
             metadatadir = metadatadir,
             datadir = datadir,   #Path to raw files
             outputdir = outputdir,
             overwrite = TRUE,
             
              # FINAL ESTIMATES (g.part5 arguments):
             excludefirstlast.part5 = FALSE,
             maxdur = 0,   # Maximum number of days (0 will process all days, set it to 7 if you want to constraint)
             threshold.lig = c(45), threshold.mod = c(100), threshold.vig = c(430),
             boutdur.mvpa = c(1,5,10), boutdur.in = c(10,20,30), boutdur.lig = c(1,5,10),
             boutcriter.mvpa=0.8,  boutcriter.in=0.9, boutcriter.lig=0.8,
             timewindow=c("WW"),
             acc.metric = "ENMO",
             data_cleaning_file=datacleanwwpath,
             
             # Reports
             do.report = c(5),
             visualreport = TRUE,
             do.parallel = TRUE))

    cat(NULL,file=paste0(SubjectGGIRDeriv(r),"/GGIRcomplete.csv"))
    }
  }# Setting this to TRUE makes the computer slower for other tasks


### Rerun part 2 intensity gradient calculations with cleaned data
read part 2
read part 5 midnight to midnight (comparable to part 2 output)
select 3 columns from part 2 + some of the identifier data
keep only window_number from part 5 match with measurementday from part 2 daysummary
average based on number of days left after cleaning
write out day summary and person summaries


output.results="/output_beh/results/"
for (r in GGIRfiles){
  if (file.exists(paste0(SubjectGGIRDeriv(r),output.results,"part2_cleanedIntensityGradient.csv"))==TRUE){
    next
  } else{
    part2<-read.csv(paste0(SubjectGGIRDeriv(r),output.results,"part2_daysummary.csv"),header = TRUE)
    part2<-part2[c("filename","measurementday","ig_gradient_ENMO_0.24hr","ig_intercept_ENMO_0.24hr","ig_rsquared_ENMO_0.24hr")]
    part5<-read.csv(paste0(SubjectGGIRDeriv(r),output.results,"part5_daysummary_MM_L45M100V430_T5A5.csv"), header = TRUE)
    part5<-part5[c("window_number")]
    part2cleaned <- merge(part2,part5,by.x="measurementday", by.y="window_number")
    igpathday=file.path(paste0(SubjectGGIRDeriv(r),output.results,"part2_day_cleanedIntensityGradient.csv"))
    write.csv(part2cleaned,igpathday,row.names=F)
    part2cleanedperson<-c()
    part2cleanedperson$filename<-unique(part2cleaned$filename)
    part2cleanedperson$ndays<-nrow(part2cleaned)
    part2cleanedperson$AD_ig_gradient_ENMO_0.24hr<-mean(part2cleaned$ig_gradient_ENMO_0.24hr)
    part2cleanedperson$AD_ig_intercept_ENMO_0.24hr<-mean(part2cleaned$ig_intercept_ENMO_0.24hr)
    part2cleanedperson$AD_ig_ig_rsquared_ENMO_0.24hr<-mean(part2cleaned$ig_rsquared_ENMO_0.24hr)
    igpath=file.path(paste0(SubjectGGIRDeriv(r),output.results,"part2_person_cleanedIntensityGradient.csv"))
    write.csv(part2cleanedperson,igpath,row.names=F)
    rm("part2","part2cleaned","part2cleanedperson","part5")
    
  }
}








