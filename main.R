#!/usr/bin/Rscript

rm(list=ls())
source('./initialization.R')


##############################################
# parse cmd arguments and setup
##############################################
useparser = T 

if(useparser){
  
  suppressPackageStartupMessages(library("optparse"))

  # parse command-line options
  option_list <- list(
    make_option(c("--inputdir"),  dest="inputdir",  action="store", help="NEI 2017 data path", default="./rawdata/" ),
    make_option(c("--outputdir"),  dest="outputdir",  action="store", help="output data path", default="./product/" ),
    make_option(c("--xwalkdir"),  dest="xwalkdir",  action="store", help="scc-surrogate xwalk data path", default="./xwalk/"),
    make_option(c("--surdir"),  dest="surdir",  action="store", help="surrogate data path", default="./surrogate/" ),
    make_option(c("--sector"),  dest="sector",  action="store", help="emission sector", default="onroad" )
  )
  opt <- parse_args(OptionParser(option_list=option_list))
  
  # read out the global variables so that subsequent programs can all use them
  inputdir = opt$inputdir
  outputdir = opt$outputdir
  xwalkdir = opt$xwalkdir
  surdir = opt$surdir
  sector = opt$sector

  # print for users to confirm
  print(paste0（"inputdir: ", inputdir))
  print(paste0（"outputdir: ", outputdir))
  print(paste0（"xwalkdir: ", xwalkdir))
  print(paste0（"surdir: ", surdir))
  print(paste0（"sector: ", sector))
}


######################################################
# call related script to spatially allocate NEI 2017 
######################################################
source(paste0('./',sector,'.R'))

print('---------------')
print('Done! Output written to:')
print(file.path(outputdir, paste0(sector,'.csv')))
