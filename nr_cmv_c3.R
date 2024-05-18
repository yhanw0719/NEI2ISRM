################################################################################
# This script spatially allocate NEI 2017 nr_cmv_c3 emissions to ISRM grid cells
################################################################################

## load input data
load(file.path(inputdir,'isrm.RData'))
load(file.path(inputdir,'counties.RData'))
xwalk = read.csv(file.path(xwalkdir,'xwalk_nr_cmv_c3.csv'))
sf::sf_use_s2(FALSE)

## read raw data and format
raw1 = read.csv(file.path(inputdir,'nonroad/nr_cmv_c3/c3_offshore_2017NEI_NONPOINT_20200415_15apr2020_v0.csv'),
                skip=15)
raw2 = read.csv(file.path(inputdir,'nonroad/nr_cmv_c3/c3_onshore_2017NEI_NONPOINT_20200415_15apr2020_v0.csv'),
                skip=15)
raw = rbind(raw1, raw2) %>%
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
dat = dat %>% mutate(Sector='nr_cmv_c3',  
                     Height=0, Diam=0, Temp=0, Velocity=0) %>%
      rename('SCC'='scc','ISRM'='isrm',
             'PM25'='PM25-PRI','SOx'='SO2','NOx'='NOX') %>%
      dplyr::select(Sector, SCC, ISRM, VOC, NOx, NH3, SOx, PM25, Height, Diam, Temp, Velocity) 

## Update: use 12km AIS inventory to replace NEI for underway emissions
useAIS = TRUE
if (useAIS){
  ## keep NEI in-port portion
  dat = filter(dat, SCC %in% c(2280002103, 2280002104, 2280003103, 2280003104)) ## keep NEI port emissions
  
  ## read AIS underway portion
  raw = read.csv(file.path(inputdir,'nonroad/nr_cmv_c3/cmv_c3_2017adjust_20200422_12US1_2017_US_annual_25apr2020_v0.csv'),
                 skip=6) %>%
        dplyr::filter(poll %in% c('VOC','NOX','NH3','SO2','PM2_5'),
                      scc %in% c(2280002203, 2280002204, 2280003203, 2280003204)) %>%
        dplyr::select(scc, poll, ann_value, longitude, latitude)
  
  ## assign US121 geometry to AIS underway entry lat/lon
  load(file.path(inputdir,'nonroad/grids_12US1.RData'))
  grids = st_transform(grids, crs=4326)
  raw = sf::st_as_sf(raw, coords = c('longitude','latitude'))
  st_crs(raw) = "+proj=longlat +ellps=WGS84 +datum=WGS84"
  raw = sf::st_join(raw, grids, join = st_within) %>% st_drop_geometry()
  raw = merge(grids, raw, by=c('id','west_east','south_north'))
  raw$grid_area = units::drop_units(st_area(raw$geometry))
  
  ## partition 12km AIS underway to ISRM grid cells
  tmp = st_intersection(raw, isrm)
  tmp$area = units::drop_units(st_area(tmp$geometry)) 
  tmp = st_drop_geometry(tmp) %>%
        mutate(ann_value = ann_value * area / grid_area) %>%
        group_by(scc, isrm, poll) %>%
        summarise(ann_value = sum(ann_value)) %>%
        reshape2::dcast(scc + isrm ~ poll, value.var = 'ann_value')
  for (pollutant in c('VOC','NOX','NH3','SO2','PM2_5')) {
    if (!(pollutant %in% colnames(tmp))) {tmp[[pollutant]] = 0}
  }
  tmp = tmp %>% mutate(Sector='nr_cmv_c1c2',  
                       Height=0, Diam=0, Temp=0, Velocity=0) %>%
        rename('SCC'='scc','ISRM'='isrm',
               'PM25'='PM2_5','SOx'='SO2','NOx'='NOX') %>%
        dplyr::select(Sector, SCC, ISRM, VOC, NOx, NH3, SOx, PM25, Height, Diam, Temp, Velocity) 
  
  ## append to NEI in-port portion
  dat = rbind(dat, tmp)
}

## save output
save(dat, file=file.path(outputdir,'nr_cmv_c3.RData'))
write.csv(sf::st_drop_geometry(dat), file=file.path(outputdir,'nr_cmv_c3.csv'), row.names=FALSE, quote=TRUE)

