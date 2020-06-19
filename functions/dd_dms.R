dd_dms <- function (coord,l,xy) {
  
  coord <- if (xy=="x") coord*-1 else coord <- coord
  Deg<-floor(coord)
  Dec<-coord-Deg
  min<-Dec*60
  min2<-floor(min)
  sec <- floor((min-min2)*60)
  min3<-1:l
  min3<-as.character(min3)
  min3<-ifelse(min<10,(min3=paste("0",min2,sep="")),(min3=as.character(min2))) 
  if (xy=="x") return(paste(Deg,"°",min3,",",sec,"'W",sep="")) else return(paste(Deg,"°",min3,",",sec,"'N",sep=""))

  
}