################################################################################
# This script spatially allocate NEI 2017 np_rwc emissions to ISRM grid cells
################################################################################

## load input data
load(file.path(inputdir,'isrm.RData'))
load(file.path(inputdir,'counties.RData'))
xwalk = read.csv(file.path(xwalkdir,'xwalk_np_rwc.csv'))

## read raw data and format
raw = read.csv(file.path(inputdir,'nonpoint/np_rwc/rwc_2017NEI_NONPOINT_20200415_15apr2020_v0.csv'),
               skip=15) %>%
      dplyr::filter(poll %in% c('VOC','NOX','NH3','SO2','PM25-PRI')) %>%
      dplyr::select(scc, region_cd, poll, ann_value) %>%
      dplyr::filter(floor(as.numeric(region_cd)/1e3) %in% CONUS_state_ids)

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
  
  ## use quarternary surrogate
  tmp4 = filter(tmp, region_cd %in% unique(tmp3[is.na(tmp3$weight),'region_cd']))
  if (dim(tmp4)[1] > 0){
    surid = xwalk[xwalk$scc==sccid,'surrogate4_id']
    surname = xwalk[xwalk$scc==sccid,'surrogate4_name']
    sur = read.csv(file.path(surdir, paste0(surid,'.csv'))) %>% mutate(region_cd = state_code*1e3+county_code)
    tmp4 = merge(tmp4, sur, by='region_cd', all.x=TRUE, all.y=FALSE)
    print(paste(surid, surname, ":", length(unique(tmp4[!is.na(tmp4$weight),'region_cd'])), 
                '/', length(unique(tmp$region_cd))))
  }
  
  ## safenet: population
  tmp5 = filter(tmp, region_cd %in% unique(tmp4[is.na(tmp4$weight),'region_cd']))
  if (dim(tmp5)[1] > 0){
    surid = 100
    surname = 'Population'
    sur = read.csv(file.path(surdir, paste0(surid,'.csv'))) %>% mutate(region_cd = state_code*1e3+county_code)
    tmp5 = merge(tmp5, sur, by='region_cd', all.x=TRUE, all.y=FALSE)
    print('!!!!! WARNING: SAFENET (POPULATION) USED !!!!!')
    print(paste(surid, surname, ":", length(unique(tmp5[!is.na(tmp5$weight),'region_cd'])), 
                '/', length(unique(tmp$region_cd))))
  }
  
  ## format and append 
  tmp = rbind(tmp1[!is.na(tmp1$weight),], tmp2[!is.na(tmp2$weight),], 
              tmp3[!is.na(tmp3$weight),], tmp4[!is.na(tmp4$weight),]) 
  if (any(is.na(tmp$ann_value))) {print('!!!!! ERROR: NA still exists !!!!!')} 
  tmp = tmp %>%
    mutate(ann_value = ann_value * weight) %>%
    group_by(scc, isrm, poll) %>%
    summarise(ann_value = sum(ann_value))
  dat = rbind(dat, tmp)
}
toc()

## sum emissions by isrm and format
dat = dat %>% 
      group_by(scc, poll, isrm) %>%
      summarise(ann_value = sum(ann_value)) %>%
      reshape2::dcast(scc + isrm ~ poll, value.var = 'ann_value') 
dat[is.na(dat)] = 0

## reorder and rename columns to match expected output format
dat = dat[!is.na(dat$isrm),] # NA means outside ISRM domain
for (pollutant in c('VOC','NOX','NH3','SO2','PM25-PRI')) {
  if (!(pollutant %in% colnames(dat))) {dat[[pollutant]] = 0}
}
dat = dat %>% mutate(Sector='np_rwc',  
                     Height=0, Diam=0, Temp=0, Velocity=0) %>%
      rename('SCC'='scc','ISRM'='isrm',
             'PM25'='PM25-PRI','SOx'='SO2','NOx'='NOX') %>%
      dplyr::select(Sector, SCC, ISRM, VOC, NOx, NH3, SOx, PM25, Height, Diam, Temp, Velocity) 

## save output
save(dat, file=file.path(outputdir,'np_rwc.RData'))
write.csv(sf::st_drop_geometry(dat), file=file.path(outputdir,'np_rwc.csv'), row.names=FALSE, quote=TRUE)

