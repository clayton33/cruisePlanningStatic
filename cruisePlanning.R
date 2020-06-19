# - General Comment
## - Section must be run but not edited
### - Section that may have to be run
#### - Parameter that will be necessary to change


# Sections must be run in the order presented:

### 1. Load Packages only if they are not already installed----

if (!require('rgdal')) install.packages('rgdal')
if (!require('dismo')) install.packages('dismo')
if (!require('raster')) install.packages('raster')
if (!require('maptools')) install.packages('maptools')
if (!require('rgeos')) install.packages('rgeos')
if (!require('mapview')) install.packages('mapview')
if (!require('shiny')) install.packages('shiny')
if (!require('oce')) install.packages('oce')
if (!require('Orcs')) install.packages('Orcs') # for coords2Lines, was in mapview
if (!require('marmap')) install_github(repo = "ericpante/marmap",
                                       ref = 'master', force = TRUE) # git version due to NOAA server changes
#if (!require('devtools')) install.packages('devtools')
#devtools::install_github('oce')

### 2. Loading libraries ---- 

library(rgdal)
library(dismo)
library(raster)
library(maptools) 
library(rgeos)
library(mapview)
library(leaflet)
library(oce)
library(Orcs)
library(marmap)

#### 2. Choose your input file ----

##Enter path for route

routepath <- "./routes"

file <- "AZMPSpring_2020_config_01.csv"
data <- read.csv(paste(routepath,"/",file,sep=""), stringsAsFactors=F, fileEncoding="Latin1")
file2 <- basename(file)

l <- nrow(data) #number of data rows for loop to add fields
data$ID <- seq(from=1, to=max(l))

#### 3. Enter Start Date ----

s <- ISOdate(2019, 10, 05, 18) #start date and time for mission (Year, month, day, 24hr time)

### 4. point to various paths 

##Enter file name for ascii bathymetry

rwd <- "./bathymetry/chs15sec1.asc"
if(!file.exists(rwd)){
  lonrange <- range(data[['lon_dd']]) + c(-5,5)
  latrange <- range(data[['lat_dd']]) + c(-5, 5)
  noaatopo <- getNOAA.bathy(lon1 = lonrange[1], lon2 = lonrange[2],
                            lat1 = latrange[1], lat2 = latrange[2],
                            keep=TRUE, resolution = 1)
  topo <- as.topo(noaatopo)
}

## Enter path for functions

funs <- './functions'

##Enter path for shapefiles

shapes <- "./shapefiles"

## 5. Distance and time calculations ----

## The Great circle functions modified from script provided from Jae Choi - https://github.com/jae0/ecomod/blob/master/spatialmethods/src/_Rfunctions/geodist.r
source(paste(funs,"GreatCircle.R",sep="/"))
source(paste(funs,"GeoDist.R",sep="/"))

##default is great circle... Vincenty is a more accurate version but is not vectorized (yet).

Coords <- c("lon_dd", "lat_dd") # order is important
Result <- geodist(data[2:l,Coords],data[1:l,Coords], method="great.circle") #output distance in metres on diagonal in matrix in kilometers

##Extracts distance values from "Result" matrix and calculates distance in nautical miles to 1 decimal place
dist_nm <- as.data.frame(diag(Result)*0.539957) # extracts values from diagonal geodist output
dist_nm[max(l),] <- 0
names(dist_nm) <- c("dist_nm")
data$dist_nm <- round(dist_nm$dist_nm,1)

##Convert Latitude (lat) and Longitude (lon) from DD to DM

source(paste(funs,"dd_dm.R",sep="/"))
source(paste(funs,"dd_dms.R",sep="/"))

lat <- data[,2]
  
data$lat_dm <- dd_dm(lat,l,"y")
data$lon_dm <- dd_dm(data$lon_dd,l,"x")

##Convert Latitude (Lat) and Longitude from DD to DD°MM,SS'N

data$lat_dms <- dd_dms(data$lat_dd,l,"y")
data$lon_dms <- dd_dms(data$lon_dd,l,"x")


##This formula calculates your transit time using your distance in nautical miles/vessel transit speed
data$trans_hr <- round(data$dist_nm/data$kts,2)
data$arrival[1] <- "start"
data$departure[1] <- as.character(s)

for (n in 2:l){
  
  if(n>=2 & n<=(max(l)-1)) data$arrival[n] <- as.character(s+(data$trans_hr[n-1]*3600))
  s <- s+(data$trans_hr[n-1]*3600)
  if(n>=2 & n<=(max(l)-1)) data$departure[n]<-as.character(s+(data$optime[n]+data$xoptime[n])*3600)
  s <- s+((data$optime[n]+data$xoptime[n])*3600)
  if (n==max(l)) data$departure[n]<-"End" 
  if (n==max(l)) data$arrival[n]<-as.character(s+(data$trans_hr[n-1]*3600))

}

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

## 7. Extract depth from ASCII - turn on and off ----
if (!exists('depth')) {
  depth <- readAsciiGrid(rwd, proj4string=CRS("+proj=longlat +datum=WGS84"))#assigns ASCII grid from rwd to variable name
}
data1 <- data[,1:2]
data2 <- data[,3:length(data)]
data3 <- SpatialPointsDataFrame(data1, data2, coords.nrs = numeric(0),proj4string = CRS("+proj=longlat +datum=WGS84"), match.ID = TRUE, bbox = NULL)
extval <- round(over(data3, depth),2)

data <- cbind(data,extval)
nc <- ncol(data)
data[,nc] <- data[,nc]*-1
colnames(data)[nc] <- "depth_m"

## 8. Prepare data for export as a shape file and .csv and remove depth from type "Transit". and create a htmlplot for export ----
data1 <- data[,1:2]
data2 <- data[,1:length(data)]

data3 <- SpatialPointsDataFrame(data1, data2, coords.nrs = numeric(0),proj4string = CRS("+proj=longlat +datum=WGS84"), match.ID = TRUE, bbox = NULL)

data3$depth_m <- ifelse(data3$type=='Transit', 0, data3$depth_m) #This filter just removes depth values from transit points


## this step adds another field to the shapefile for the end coordinates for xy to route calculation in R
lon_dd_e <- 0
lon_dd_e[1:max(l-1)] <- data3$lon_dd[-1]
lon_dd_e[max(l)] <- data3$lon_dd[max(l)]

lat_dd_e <- 0
lat_dd_e[1:max(l-1)] <- data3$lat_dd[-1]
lat_dd_e[max(l)] <- data3$lat_dd[max(l)]

data3$lon_dd_e <- lon_dd_e
data3$lat_dd_e <- lat_dd_e


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
  writeOGR(data3, routepath, file3, driver="ESRI Shapefile",overwrite_layer=TRUE)
})

## Define Shapelayers for Output

closures <- readOGR(dsn=shapes,
                    layer = "ProtectedAreasMerge_2017_WGS84", GDAL1_integer64_policy = TRUE)
EEZ <- readOGR(dsn=shapes,
               layer = "EEZ_WGS", GDAL1_integer64_policy = TRUE)
NAFO <- readOGR(dsn=shapes,
                layer = "NAFO_DivisionsPoly_WGS", GDAL1_integer64_policy = TRUE)

nc <- ncol(data3)+2
data4 <- as.data.frame(data3)
data4 <- data4[,1:(nc-2)]
##write summary csv that has same order of variables as shapefile
write.csv(data4, paste(routepath, file4,sep="/"), row.names=F)

library(htmlwidgets)
#position of transit points
tpts <- subset(data4,data4$type=="Transit")
#position of mooring points
moorings <- subset(data4,data4$operation=="Recovery"|data4$operation=="Deployment")
#position of operations points
opts <- subset(data4,data4$type=="Operations")
data4sel <- as.matrix(data4[,c(1:2)])
#converts data4 points to lines for inclusion in output map
data4ln <- coords2Lines(data4sel, ID=paste(file,"Route",sep=" "))

et <- nrow(data4) #et=end time
dur <- print(paste("The mission is",round(as.numeric(difftime(strptime(data4$arrival[et],"%Y-%m-%d %H:%M:%S"),strptime(data4$departure[1],"%Y-%m-%d %H:%M:%S"))),0), "days long.",sep=" "))


route<-leaflet(data4) %>%
  fitBounds(min(data4$lon_dd),min(data4$lat_dd),max(data4$lon_dd),max(data4$lat_dd)) %>%
  addTiles(urlTemplate = 'http://server.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer/tile/{z}/{y}/{x}', 
           attribution = 'Tiles &copy; Esri &mdash; National Geographic, Esri, DeLorme, NAVTEQ, UNEP-WCMC, USGS, NASA, ESA, METI, NRCAN, GEBCO, NOAA, iPC')%>%  # Add awesome tiles
  
  #EEZ
  addPolylines(data=EEZ, group = "EEZ", color = "red", weight = 2, smoothFactor = 0.5, opacity = 0.5)%>%
  
  #NAFO Divisions
  addPolygons(data=NAFO, group = "NAFO Zones", color = "#444444", weight = 0.5, smoothFactor = 0.5, popup=paste(NAFO$ZONE),opacity = 0.5, 
              fillOpacity = 0, 
              highlightOptions = highlightOptions(color = "white", weight = 2))%>%
  
  #Closures
  addPolygons(data=closures, group = "Closure Areas", color = "#444444", weight = 1, smoothFactor = 0.5, popup=paste(closures$Name),opacity = 1.0, 
              fillOpacity = 0.2, 
              highlightOptions = highlightOptions(color = "white", weight = 2))%>%
  
  #Mission Route
  addPolylines(data=data4ln,color="blue",weight=1,popup=paste(file,"Route","|",dur,sep=" "),
               highlightOptions = highlightOptions(color = "white", weight = 10,bringToFront = TRUE),group="Route")%>%
  
  #Transit Points
  addCircles(lng=tpts$lon_dd,lat=tpts$lat_dd, weight = 5, radius=10, color="red", stroke = TRUE,opacity=0.5,
             group="Transit Locations",fillOpacity = 1,
             popup=paste ("ID:",tpts$ID,"|", "Station:", tpts$type,"|","Lon:", round(tpts$lon_dd,3), "|","Lat:",
                          round(tpts$lat_dd,3),"|","Arrival:",substrLeft(tpts$arrival,16),"|","Departure:",
                          substrLeft(tpts$departure,16), "Next Stn:",round(tpts$dist_nm,1),"nm","&",round(tpts$trans_hr,1),
                          "hr(s)",sep=" "),highlightOptions = highlightOptions(color = "white", weight = 20,bringToFront = TRUE))%>%
  
  #Operations Points
  addCircles(lng=opts$lon_dd, lat=opts$lat_dd, weight = 5, radius=10, color="yellow",stroke = TRUE, opacity=.5,
             group="Operations Locations",fillOpacity = 1, 
             popup=paste ("ID:",opts$ID,"|", "Station:", opts$station,"|","Lon:", round(opts$lon_dd,3), "|","Lat:",
                          round(opts$lat_dd,3), "|","Depth:",round(opts$depth_m,1),"m","|", "Arrival:",
                          substrLeft(opts$arrival,16),"|","Departure:",substrLeft(opts$departure,16), "|","Op Time:",
                          (opts$optime+opts$xoptime),"hr(s)","|","Operation(s):",opts$operation, "|","Next Stn:",
                          round(opts$dist_nm,1),"nm","&",round(opts$trans_hr,1),"hr(s)",sep=" "),
             highlightOptions = highlightOptions(color = "white", weight = 20,bringToFront = TRUE))%>% 
  
  #Mooring Operations
  #addCircleMarkers(lng=moorings$lon_dd, lat=moorings$lat_dd, weight = 10, radius=10, color="green",stroke = TRUE, opacity=1,
  #group="Mooring Locations",fillOpacity = 1, clusterOptions=markerClusterOptions(),
  #popup=paste ("ID:",moorings$ID,"|", "Station:", moorings$station,"|","Lon:", round(moorings$lon_dd,3), "|",
             # "Lat:",round(moorings$lat_dd,3), "|","Depth:",round(moorings$depth_m,1),"m","|", "Arrival:",
             #substrLeft(moorings$arrival,16),"|","Departure:",substrLeft(moorings$departure,16), "|","Op Time:",
           # (moorings$optime+moorings$xoptime),"hr(s)","|","Operation(s):",moorings$operation, "|","Next Stn:",
          # round(moorings$dist_nm,1),"nm","&",round(moorings$trans_hr,1),"hr(s)",sep=" "), 
  #highlightOptions = highlightOptions(color = "white", weight = 20,bringToFront = TRUE))%>%
  
addCircleMarkers(lng=moorings$lon_dd, lat=moorings$lat_dd, weight = 2, radius=20, color="green",stroke = TRUE, opacity=0.5,
                 group="Mooring Locations",fillOpacity = 0.5, clusterOptions=markerClusterOptions(radius=5),
                 popup=paste ("ID:",moorings$ID,"|", "Station:", moorings$station,"|","Lon:", round(moorings$lon_dd,3), "|",
                              "Lat:",round(moorings$lat_dd,3), "|","Depth:",round(moorings$depth_m,1),"m","|", "Arrival:",
                              substrLeft(moorings$arrival,16),"|","Departure:",substrLeft(moorings$departure,16), "|","Op Time:",
                              (moorings$optime+moorings$xoptime),"hr(s)","|","Operation(s):",moorings$operation, "|","Next Stn:",
                              round(moorings$dist_nm,1),"nm","&",round(moorings$trans_hr,1),"hr(s)",sep=" "))%>%
  
  
  
  #Add Mouse Coordinates
  leafem::addMouseCoordinates(epsg = NULL,proj4string = NULL, native.crs = FALSE)%>%
  
  #Operations Points Labels
  addLabelOnlyMarkers(lng=opts$lon_dd, lat=opts$lat_dd,label =  as.character(opts$station),group="Station Labels", 
                      labelOptions = labelOptions(noHide = T, direction = 'top', textOnly = T))%>%
  
  #Legend
  addLegend("bottomright", colors= c("yellow", "red","Green","blue"), labels=c("Operations","Transit","Moorings","Route"), title=paste("Map created on ",Sys.Date(),": ",file),opacity=1)%>% 
  
  #Scale Bar
  addScaleBar("bottomleft",options=scaleBarOptions(maxWidth=100,imperial=T,metric=T,updateWhenIdle=T))
  
  #Layer Control
  #addLayersControl(
   # overlayGroups = c("Operations Locations","Transit Locations","Mooring Locations","Route","Station Labels", "Closure Areas", "NAFO Zones", "EEZ"),
    #options = layersControlOptions(collapsed = TRUE)
  #)

route

library(tools)   # unless already loaded, comes with base R
route_html <- paste(file_path_sans_ext(file),"_",as.numeric(format(Sys.Date(), "%y%m%d")),"_",time,".html",sep="")

saveWidget(widget = route, file = route_html)
#End