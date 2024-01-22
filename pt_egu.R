################################################################################
# This script spatially allocate NEI 2017 pt_egu emissions to ISRM grid cells
################################################################################

## load input data
load(file.path(inputdir,'isrm.RData'))
cems = read.csv(file.path(inputdir,'point/pt_egu/egucems_2017NEI_POINT_20200618.csv'), skip=12)
noncems = read.csv(file.path(inputdir,'point/pt_egu/egunoncems_2017NEI_POINT_20200618.csv'), skip=12)
raw = rbind(cems, noncems)

## data cleaning and formatting
tmp = raw %>% 
      dplyr::filter(poll %in% c('VOC','NOX','NH3','SO2','PM25-PRI')) %>%
      dplyr::select(scc, poll, ann_value, longitude, latitude, stkhgt, stkdiam, stktemp, stkvel)
tmp[is.na(tmp)] = 0

## aggregate point sources with the same latlon, scc, pollutant, and stack information
cols_to_fac = c('scc', 'poll', 'longitude', 'latitude', 'stkhgt', 'stkdiam', 'stktemp', 'stkvel')
tmp[cols_to_fac] = lapply(tmp[cols_to_fac] , factor) 
tmp = tmp %>% 
      group_by(scc, poll, longitude, latitude, stkhgt, stkdiam, stktemp, stkvel) %>%
      summarise(ann_value = sum(ann_value)) %>%
      reshape2::dcast(scc+longitude+latitude+stkhgt+stkdiam+stktemp+stkvel ~ poll, value.var = 'ann_value') 
tmp[is.na(tmp)] = 0
cols_to_num = c('scc', 'longitude', 'latitude', 'stkhgt', 'stkdiam', 'stktemp', 'stkvel')
tmp[cols_to_num] = lapply(tmp[cols_to_num] , as.character) 
tmp[cols_to_num] = lapply(tmp[cols_to_num] , as.numeric)  

## identify ISRM polygon id for each point  
tmp = sf::st_as_sf(tmp, coords = c('longitude','latitude'))
st_crs(tmp) = "+proj=longlat +ellps=WGS84 +datum=WGS84"
sf_use_s2(TRUE)
dat = sf::st_join(tmp, isrm, join = st_within) 

## format data product
dat = dat[!is.na(dat$isrm),] # NA means outside ISRM domain
for (pollutant in c('VOC', 'NOX', 'NH3', 'SO2', 'PM25-PRI')) {
  if (!(pollutant %in% colnames(dat))) {dat[[pollutant]] = 0}
}
dat = dat %>% 
      mutate(Sector='pt_egu') %>% 
      dplyr::select(Sector, scc, isrm, VOC, NOX, NH3, SO2, `PM25-PRI`, stkhgt, stkdiam, stktemp, stkvel) %>%
      rename('NOx'='NOX','SOx'='SO2','PM25'='PM25-PRI',
             'Height'='stkhgt','Diam'='stkdiam','Temp'='stktemp','Velocity'='stkvel',
             'SCC'='scc','ISRM'='isrm')

## save output
save(dat, file=file.path(outputdir,'pt_egu.RData'))
write.csv(sf::st_drop_geometry(dat), file=file.path(outputdir,'pt_egu.csv'), row.names=FALSE, quote=TRUE)
