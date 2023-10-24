packages_to_install<- c("dplyr","reshape2","sf","optparse")


for (i in packages_to_install){
  if ( i %in% rownames(installed.packages()) == FALSE) {
    install.packages(i)
  }
}
library(dplyr)
library(reshape2)
library(sf)
library(tictoc)
suppressPackageStartupMessages(library("optparse"))


######## DO NOT CHANGE ORDER
CONUS_state_ids = c(01, 04, 05, 06, 08, 09, 10, 12, 13, 16, 
                    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 
                    27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 
                    37, 38, 39, 40, 41, 42, 44, 45, 46, 47, 
                    48, 49, 50, 51, 53, 54, 55, 56, 11)
CONUS_states <- c('Alabama', 'Arizona', 'Arkansas', 'California', 'Colorado', 
                  'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Idaho', 'Illinois', 'Indiana', 
                  'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 
                  'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 
                  'Nevada', 'NewHampshire', 'NewJersey', 'NewMexico', 'NewYork', 'NorthCarolina', 
                  'NorthDakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'RhodeIsland', 
                  'SouthCarolina', 'SouthDakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 
                  'Virginia', 'Washington', 'WestVirginia', 'Wisconsin', 'Wyoming', 'District')
