################################################################################
# This script spatially allocate NEI 2017 onroad emissions to ISRM grid cells
################################################################################

## clean up and initialize
#rm(list=ls())
#setwd('G:/Shared drives/CMAQ_Adjoint/Yuhan/Fall_2022/Task4_NEI/Deliverable/script')
#source('initialization.R')
#inputdir = '../rawdata/'
#outputdir = '../product/'
#xwalkdir = '../xwalk/'
#surdir = '../surrogate/'

## load input data
print('----- inputdir below -----')
print(inputdir)
print('----- work dir below -----')
print(getwd())
print('----- list files below -----')
print(list.files(path=inputdir))
load(file.path(inputdir,'isrm.RData'))
load(file.path(inputdir,'counties.RData'))
load(file.path(inputdir,'onroad/2017gb_nata_onroad_SMOKE_MOVES_NATAstyle_14may2020_v0.RData'))
xwalk = read.csv(file.path(xwalkdir,'xwalk_onroad.csv'))

## data formatting
raw = raw %>% 
      dplyr::filter(poll %in% c('VOC','NOX','NH3','SO2','PM25-PRI')) %>%
      dplyr::select(scc, region_cd, poll, ann_value) 

## check if all relevant scc are covered in xwalk (should print nothing)
for (sccid in as.character(unique(raw$scc))){
  if (!sccid %in% as.character(xwalk$scc)){print(paste0('!ERROR: ', sccid,' NOT FOUND IN XWALK!'))}
}

## main loop by scc
tic()
dat = NULL
options(dplyr.summarise.inform = FALSE)
for (sccid in as.character(unique(raw$scc))){
  
  tmp = filter(raw, as.character(scc)==sccid)
  print(paste0('----- SCC: ', sccid,' -----'))
  
  ## use primary surrogate
  surid = xwalk[xwalk$scc==sccid,'surrogate1_id']
  surname = xwalk[xwalk$scc==sccid,'surrogate1_name']
  sur = read.csv(file.path(surdir, paste0(surid,'.csv'))) %>% mutate(region_cd = state_code*1e3+county_code)
  tmp1 = merge(tmp, sur, by='region_cd', all.x=TRUE, all.y=FALSE)
  print(paste(surid, surname, ":", length(unique(tmp1[!is.na(tmp1$weight),'region_cd'])), 
              '/', length(unique(tmp$region_cd))))
  
  ## use secondary surrogate
  tmp2 = filter(tmp, region_cd %in% unique(tmp1[is.na(tmp1$weight),'region_cd']))
  if (dim(tmp2)[1] > 0){
    surid = xwalk[xwalk$scc==sccid,'surrogate2_id']
    surname = xwalk[xwalk$scc==sccid,'surrogate2_name']
    sur = read.csv(file.path(surdir, paste0(surid,'.csv'))) %>% mutate(region_cd = state_code*1e3+county_code)
    tmp2 = merge(tmp2, sur, by='region_cd', all.x=TRUE, all.y=FALSE)
    print(paste(surid, surname, ":", length(unique(tmp2[!is.na(tmp2$weight),'region_cd'])), 
                '/', length(unique(tmp$region_cd))))
  }

  ## use tertiary surrogate
  tmp3 = filter(tmp, region_cd %in% unique(tmp2[is.na(tmp2$weight),'region_cd']))
  if (dim(tmp3)[1] > 0){
    surid = xwalk[xwalk$scc==sccid,'surrogate3_id']
    surname = xwalk[xwalk$scc==sccid,'surrogate3_name']
    sur = read.csv(file.path(surdir, paste0(surid,'.csv'))) %>% mutate(region_cd = state_code*1e3+county_code)
    tmp3 = merge(tmp3, sur, by='region_cd', all.x=TRUE, all.y=FALSE)
    print(paste(surid, surname, ":", length(unique(tmp3[!is.na(tmp3$weight),'region_cd'])), 
                '/', length(unique(tmp$region_cd))))
  }
  
  ## format and append 
  tmp = rbind(tmp1[!is.na(tmp1$weight),], tmp2[!is.na(tmp2$weight),], tmp3[!is.na(tmp3$weight),]) 
  if (any(is.na(tmp$ann_value))) {print('!ERROR: NA still exists!')} 
  tmp = tmp %>%
        mutate(ann_value = ann_value * weight) %>%
        group_by(scc, isrm, poll) %>%
        summarise(ann_value = sum(ann_value))
  dat = rbind(dat, tmp)
}
toc()
#save(dat, file=file.path(inputdir,'onroad/onroad_intermediate.RData')) 
#load(file.path(inputdir,'onroad/onroad_intermediate.RData'))

## sum emissions by isrm and format
dat = dat %>% 
      group_by(scc, poll, isrm) %>%
      summarise(ann_value = sum(ann_value)) %>%
      reshape2::dcast(scc + isrm ~ poll, value.var = 'ann_value') 
dat[is.na(dat)] = 0

## reorder and rename columns to match expected output format
dat = dat %>% mutate(Sector='onroad',  
                     Height=0, Diam=0, Temp=0, Velocity=0) %>%
              rename('SCC'='scc','ISRM'='isrm','PM25'='PM25-PRI','SOx'='SO2','NOx'='NOX') %>%
              dplyr::select(Sector, SCC, ISRM, VOC, NOx, NH3, SOx, PM25, Height, Diam, Temp, Velocity) 

## save output
save(dat, file=file.path(outputdir,'onroad.RData'))
write.csv(sf::st_drop_geometry(dat), file=file.path(outputdir,'onroad.csv'), row.names=FALSE, quote=TRUE)

