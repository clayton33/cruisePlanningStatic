# - General Comment
## - Section must be run but not edited
### - Section that may have to be run
#### - Parameter that will be necessary to change

# Sections must be run in the order presented:

### 1. Download packages only if they are not already installed----

if (!require('leaflet')) install.packages('dismo')
if (!require('oce')) install.packages('raster')
if (!require('Orcs')) install.packages('maptools')
if (!require('fields')) install.packages('rgeos')
if (!require('sp')) install.packages('mapview')
if (!require('htmlwidgets')) install.packages('shiny')
if (!require('sf')) install.packages('oce')
if (!require('leafem')) install.packages('Orcs') # for coords2Lines, was in mapview
if (!require('tools')) install.packages('tools')
#if (!require('devtools')) install.packages('devtools')
#devtools::install_github('oce')

### 2. Loading libraries ---- 

library(leaflet) # needed
library(oce) # needed
library(Orcs) # needed for coords2Lines
library(fields) # for interp.surface if no bathy file is given
library(sp) # needed
library(htmlwidgets) # needed
library(sf) # needed to replace rgdal fn calls (readOGR)
library(leafem) # for adding mouseCoordinates
library(tools) # for saving

#### 3. Choose your input file ----

##Enter path for route

routepath <- "./routes"

file <- "AZMPFall_2020_WorstCaseScenario_COREOnly_SydneyDemob_v2.csv"
data <- read.csv(paste(routepath,"/",file,sep=""), stringsAsFactors=F, fileEncoding="Latin1")
file2 <- basename(file)

l <- nrow(data) #number of data rows for loop to add fields
data$ID <- seq(from=1, to=max(l))

#### 4. Enter Start Date ----

s <- ISOdate(2020, 10, 08, 09) #start date and time for mission (Year, month, day, 24hr time)

### 5. Point to various paths ----

##Enter file name for ascii bathymetry

rwd <- "./bathymetry/chs15sec1.asc"
if(!file.exists(rwd)){
  mround <- function(x, base, method = 'round'){
    base*do.call(method, list(x = x/base))
  }
  # round up to nearest 10 degrees to avoid needing to download
  # while at sea. rounding to nearest 5 was considered, but 10
  # will help with boundary cases.
  lonrange <- c(mround(min(data[['lon_dd']]), base = 10, method = 'floor'),
                mround(max(data[['lon_dd']]), base = 10, method = 'ceiling'))
  latrange <- c(mround(min(data[['lat_dd']]), base = 10, method = 'floor'),
                mround(max(data[['lat_dd']]), base = 10, method = 'ceiling'))
  # do a check for near boundary cases
  # if min/max longitude/latitude is within 2.5 degrees of lon/latrange, +/- 10
  lonrange <- c(ifelse(abs(min(data[['lon_dd']]) - lonrange[1]) < 2.5, lonrange[1] - 10, lonrange[1]),
                ifelse(abs(max(data[['lon_dd']]) - lonrange[2]) < 2.5, lonrange[2] + 10, lonrange[2]))
  latrange <- c(ifelse(abs(min(data[['lat_dd']]) - latrange[1]) < 2.5, latrange[1] - 10, latrange[1]),
                ifelse(abs(max(data[['lat_dd']]) - latrange[2]) < 2.5, latrange[2] + 10, latrange[2]))
  # marmap, keep it for now, but use oce way for the time being
  # noaatopo <- getNOAA.bathy(lon1 = lonrange[1], lon2 = lonrange[2],
  #                           lat1 = latrange[1], lat2 = latrange[2],
  #                           keep=TRUE, resolution = 1)
  # topo <- as.topo(noaatopo)
  # oce
  topoFile <- download.topo(west = lonrange[1], east = lonrange[2],
                            south = latrange[1], north = latrange[2],
                            resolution = 1)
  topo <- read.topo(topoFile)
}

## Enter path for functions

funs <- './functions'

##Enter path for shapefiles

shapes <- "./shapefiles"

## 6. Distance and time calculations ----

# calculate distance between input coordinates
idx1 <- 1:(length(data[['lon_dd']])-1)
idx2 <- 2:length(data[['lon_dd']])
# previous version used great circle
# use maintained function geoDist
# but this method uses vincenty
# differences are small, and the cumulative difference is only 2nm
distkm <- oce::geodDist(longitude1 = data[['lon_dd']][idx1],
                   latitude1 = data[['lat_dd']][idx1],
                   longitude2 = data[['lon_dd']][idx2],
                   latitude2 = data[['lat_dd']][idx2])
distnm <- distkm * 0.539957
# add 0 for length agreements
distnm <- c(distnm, 0)
data[['dist_nm']] <- distnm

##Convert Latitude (lat) and Longitude (lon) from DD to DM

source(paste(funs,"dd_dm.R",sep="/"))
source(paste(funs,"dd_dms.R",sep="/"))


data$lat_dm <- dd_dm(data[['lat_dd']],l,"y")
data$lon_dm <- dd_dm(data[['lon_dd']],l,"x")

##Convert Latitude (Lat) and Longitude from DD to DD°MM,SS'N

data$lat_dms <- dd_dms(data[['lat_dd']],l,"y")
data$lon_dms <- dd_dms(data[['lon_dd']],l,"x")


##This formula calculates your transit time using your distance in nautical miles/vessel transit speed
data$trans_hr <- round(data$dist_nm/data$kts,2)
# initialize arrival and departure
data$arrival[1] <- "start"
data$departure[1] <- as.character(s)

# for (n in 2:l){
#   
#   if(n>=2 & n<=(max(l)-1)) data$arrival[n] <- as.character(s+(data$trans_hr[n-1]*3600))
#   s <- s+(data$trans_hr[n-1]*3600)
#   if(n>=2 & n<=(max(l)-1)) data$departure[n]<-as.character(s+(data$optime[n]+data$xoptime[n])*3600)
#   s <- s+((data$optime[n]+data$xoptime[n])*3600)
#   if (n==max(l)) data$departure[n]<-"End" 
#   if (n==max(l)) data$arrival[n]<-as.character(s+(data$trans_hr[n-1]*3600))
# 
# }

for (n in 2:(l-1)){
  # first calculate arrival
  s <- s + (data$trans_hr[n-1]*3600)
  data$arrival[n] <- as.character(s)
  # then calculate departure
  s <- s + ((data$optime[n] + data$xoptime[n]) * 3600)
  data$departure[n] <- as.character(s)
}

# finalize arrival and departure
data$arrival[l] <- as.character(s + (data$trans_hr[l-1] * 3600))
data$departure[l] <- "end"

## This part is only necessary if you need to convert ESRI GRID format to ASCII format.##
## You could add another grid (e.g., GEBCO) to be used in your calculations but it is  ##
## not necessary.##

#esrigrid2ascii <- function(inputgrid,outputascii,xmin,xmax,ymin,ymax)
#{  x <- raster(inputgrid)
#   aoi <- extent(xmin,xmax,ymin,ymax)
#   x.crop <- crop(x,aoi)
#   writeRaster(x.crop,outputascii,NAflag=-9999)
#   "DONE!"
#}

#esrigrid2ascii("chs15sec1","chs15sec1.asc",-72, -42, 40, 64)

#This is where to ask the user to enter a shapefile output name

## 7. Extract the depth from bathy and prep data for output ----
if (file.exists(rwd)) {
  depth <- sp::read.asciigrid(fname = rwd, 
                              proj4string = CRS("+proj=longlat +datum=WGS84")) #assigns ASCII grid from rwd to variable name

  data1 <- data[, names(data) %in% c("lon_dd", "lat_dd")]
  data2 <- data[, !names(data) %in% c("lon_dd", "lat_dd")]
  data3 <- sp::SpatialPointsDataFrame(data1, data2, coords.nrs = numeric(0),proj4string = CRS("+proj=longlat +datum=WGS84"), match.ID = TRUE, bbox = NULL)
  # this is the inferred depth, mult by -1 to get it in depth below sealevel
  extval <- round(over(data3, depth),2) * -1 
  # rename it
  names(extval) <- 'depth_m'
  data <- cbind(data,extval)
  data[['depth_m']] <- ifelse(data$type=='Transit', 0, data$depth_m) # remove depth values from transit points 
  data1 <- data[, names(data) %in% c("lon_dd", "lat_dd")]
  data2 <- data
  data3 <- sp::SpatialPointsDataFrame(data1, data2, 
                                  coords.nrs = numeric(0), 
                                  proj4string = CRS("+proj=longlat +datum=WGS84"), 
                                  match.ID = TRUE, bbox = NULL)
} else {
  # get depth at stations using topo
  zs <- fields::interp.surface(obj = list(x = topo[['longitude']],
                                  y = topo[['latitude']],
                                  z = topo[['z']]),
                       loc = cbind(data[['lon_dd']],
                                   data[['lat_dd']]))
  data[['depth_m']] <- zs
  data[['depth_m']] <- ifelse(data[['type']] == 'Transit', 0, data[['depth_m']])
  coords <- data[, names(data) %in% c("lon_dd", "lat_dd")]
  data3 <- sp::SpatialPointsDataFrame(coords = coords, data = data, 
                                  coords.nrs = numeric(0), 
                                  proj4string = CRS("+proj=longlat +datum=WGS84"), 
                                  match.ID = TRUE, bbox = NULL)
}

## this step adds another field to the shapefile for the end coordinates for xy to route calculation in R
lon_dd_e <- 0
lon_dd_e[1:max(l-1)] <- data3$lon_dd[-1]
lon_dd_e[max(l)] <- data3$lon_dd[max(l)]

lat_dd_e <- 0
lat_dd_e[1:max(l-1)] <- data3$lat_dd[-1]
lat_dd_e[max(l)] <- data3$lat_dd[max(l)]

data3$lon_dd_e <- lon_dd_e
data3$lat_dd_e <- lat_dd_e

## 8. Write shapefile and save .csv. Create a htmlplot for export ----

##These next few steps reorder the data for final export as shape file and csv
##You will likely have to change the variables for your export
##The Sys.Date function applies a date and time stamp at the end of your ouput that has the same
##naming convention as your input csv file.

date <- Sys.Date()
date
substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}

substrLeft <- function(x, n){
  substr(x, 1, n)
}

date <- substrRight(gsub("-","", date),6)
time <- format(Sys.time(),"%H%M")#The 3600 value might be necessary to account for daylight savings.
time <- as.character(time)
file2 <- unlist(strsplit(file2,split='.', fixed=TRUE))[1] #splits original file name and only assigns title without the extension
file3 <- paste(file2,date,time,sep="_")
file4 <- paste(file3,".csv", sep="")

## writes point shapefile and planning csv
try({
  st_write(obj = st_as_sf(data3), dsn = routepath, layer = file3, driver = "ESRI Shapefile", overwrite_layer = TRUE)
})

## Define Shapelayers for Output

closures <- sf::st_read(dsn = shapes,
                        layer = "ProtectedAreasMerge_2017_WGS84") %>%
  st_transform('+proj=longlat +datum=WGS84') # transform it to use it in leaflet
EEZ <- sf::st_read(dsn = shapes,
                   layer = "EEZ_WGS") %>%
  st_transform('+proj=longlat +datum=WGS84') # transform it to use it in leaflet
NAFO <- sf::st_read(dsn = shapes,
                    layer = "NAFO_DivisionsPoly_WGS") %>%
  st_transform('+proj=longlat +datum=WGS84') # transform it to use it in leaflet

data4 <- as.data.frame(data3)
# omit lon[lat]_dd_ee 
data4 <- data4[,!names(data4) %in% c('lon_dd_ee', 'lat_dd_ee')]
##write summary csv that has same order of variables as shapefile
write.csv(data4, paste(routepath, file4, sep="/"), row.names=F)

#position of transit points
tpts <- subset(data4, type == "Transit")
#position of mooring points
mpts <- subset(data4, operation == "Recovery"| operation == "Deployment")
#position of operations points
opts <- subset(data4, type =="Operations")
data4sel <- as.matrix(data4[, names(data4) %in% c('lon_dd','lat_dd')])
#converts data4 points to lines for inclusion in output map
data4ln <- coords2Lines(data4sel, ID=paste(file,"Route",sep=" "))

et <- nrow(data4) #et=end time
dur <- print(paste("The mission is",round(as.numeric(difftime(strptime(data4$arrival[et],"%Y-%m-%d %H:%M:%S"),strptime(data4$departure[1],"%Y-%m-%d %H:%M:%S"))),0), "days long.",sep=" "))


route <- leaflet::leaflet(data4) %>%
  leaflet::fitBounds(min(data4$lon_dd),min(data4$lat_dd),max(data4$lon_dd),max(data4$lat_dd)) %>%
  leaflet::addTiles(urlTemplate = 'http://server.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer/tile/{z}/{y}/{x}', 
           attribution = 'Tiles &copy; Esri &mdash; National Geographic, Esri, DeLorme, NAVTEQ, UNEP-WCMC, USGS, NASA, ESA, METI, NRCAN, GEBCO, NOAA, iPC')%>%

  #NAFO Divisions
  leaflet::addPolygons(data=NAFO, group = "NAFO Zones", color = "#444444", weight = 0.5,
                       smoothFactor = 0.5, popup=paste(NAFO$ZONE), 
                       opacity = 0.5, fillOpacity = 0, 
                       highlightOptions = highlightOptions(color = "white", weight = 2))%>%
  # #EEZ
  # leaflet::addPolylines(data = EEZ,
  #                       group = "EEZ",
  #                       color = "magenta", weight = 2,
  #                       smoothFactor = 0.5, opacity = 0.5)%>%
  
  #Closures
  leaflet::addPolygons(data = closures, group = "Closure Areas", color = "#444444", weight = 1, 
                       smoothFactor = 0.5, popup=paste(closures$Name), 
                       opacity = 1.0, fillOpacity = 0.2, 
                       highlightOptions = highlightOptions(color = "white", weight = 2))%>%
  
  #Mission Route
  leaflet::addPolylines(data = data4ln, group="Route", color = "blue", weight=1, 
                        popup=paste(file,"Route","|",dur,sep=" "), 
                        highlightOptions = highlightOptions(color = "white", weight = 10,bringToFront = TRUE))%>%
  
  #Transit Points
  leaflet::addCircles(lng = tpts$lon_dd,lat = tpts$lat_dd, group="Transit Locations", 
                      color="red", weight = 5, radius=10, stroke = TRUE, 
                      opacity=0.5, fillOpacity = 1, 
                      popup=paste ("ID:",tpts$ID,"|", 
                          "Station:", tpts$type,"|",
                          "Lon:", round(tpts$lon_dd,3), "|",
                          "Lat:", round(tpts$lat_dd,3),"|",
                          "Arrival:",substrLeft(tpts$arrival,16),"|",
                          "Departure:", substrLeft(tpts$departure,16), 
                          "Next Stn:",round(tpts$dist_nm,1),"nm","&",round(tpts$trans_hr,1), "hr(s)", 
                          sep=" "), 
                      highlightOptions = highlightOptions(color = "white", weight = 20,bringToFront = TRUE))%>%
  
  #Operations Points
  leaflet::addCircles(lng = opts$lon_dd, lat = opts$lat_dd, group="Operations Locations",
                      weight = 5, radius = 10, color="yellow", stroke = TRUE, opacity=.5,
                      fillOpacity = 1, 
                      popup=paste ("ID:",opts$ID,"|", 
                          "Station:", opts$station,"|",
                          "Lon:", round(opts$lon_dd,3), "|",
                          "Lat:", round(opts$lat_dd,3), "|",
                          "Depth:",round(opts$depth_m,1),"m","|", 
                          "Arrival:", substrLeft(opts$arrival,16),"|",
                          "Departure:", substrLeft(opts$departure,16), "|",
                          "Op Time:", (opts$optime+opts$xoptime),"hr(s)","|",
                          "Operation(s):",opts$operation, "|",
                          "Next Stn:", round(opts$dist_nm,1),"nm","&",round(opts$trans_hr,1),"hr(s)", 
                          sep=" "),
             highlightOptions = highlightOptions(color = "white", weight = 20,bringToFront = TRUE))%>% 
  
  # Mooring Operations
  leaflet::addCircleMarkers(lng = mpts$lon_dd, lat = mpts$lat_dd, group="Mooring Locations",
                            weight = 2, radius=20, color="green",stroke = TRUE, opacity=0.5,
                            fillOpacity = 0.5, clusterOptions = markerClusterOptions(radius=5), 
                            popup=paste("ID:",mpts$ID,"|", 
                              "Station:", mpts$station,"|",
                              "Lon:", round(mpts$lon_dd,3), "|",
                              "Lat:",round(mpts$lat_dd,3), "|",
                              "Depth:",round(mpts$depth_m,1),"m","|", 
                              "Arrival:", substrLeft(mpts$arrival,16),"|",
                              "Departure:",substrLeft(mpts$departure,16), "|",
                              "Op Time:", (mpts$optime+mpts$xoptime),"hr(s)","|",
                              "Operation(s):",mpts$operation, "|",
                              "Next Stn:", round(mpts$dist_nm,1),"nm","&",round(mpts$trans_hr,1),"hr(s)",
                              sep=" ")) %>%
  # #Add Mouse Coordinates
  # leafem::addMouseCoordinates(epsg = NULL,proj4string = NULL, native.crs = FALSE)%>%
  # #Operations Points Labels
  leaflet::addLabelOnlyMarkers(lng=opts$lon_dd, lat=opts$lat_dd,label =  as.character(opts$station),group="Station Labels",
                      labelOptions = labelOptions(noHide = T, direction = 'top', textOnly = T))%>%
  # #Legend
  leaflet::addLegend("bottomright",
                     colors= c("yellow", "red","green","blue"),
                     labels=c("Operations","Transit","Moorings","Route"),
                     title=paste("Map created on ",Sys.Date(),": ",file), opacity=1) %>%

  # #Scale Bar
  # leaflet::addScaleBar("bottomleft",options=scaleBarOptions(maxWidth=100,imperial=T,metric=T,updateWhenIdle=T))
  
  #Layer Control
  addLayersControl(
  overlayGroups = c("Operations Locations","Transit Locations","Mooring Locations","Route","Station Labels", "Closure Areas", "NAFO Zones", "EEZ"),
  options = layersControlOptions(collapsed = TRUE)
  )

route
route_html <- paste(file_path_sans_ext(file),"_",as.numeric(format(Sys.Date(), "%y%m%d")),"_",time,".html",sep="")
saveWidget(widget = route, file = route_html)
