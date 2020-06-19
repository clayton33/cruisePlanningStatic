dd_dm <- function (coord,l,xy) {
  
  coord <- if (xy=="x") coord*-1 else coord <- coord
  Deg<-floor(coord)
  Dec<-coord-Deg
  min<-Dec*60
  min<-round(min,6)
  min2<-1:l
  min2<-as.character(min2)
  min2<-ifelse(min<10,(min2=paste("0",min,sep="")),(min2=as.character(min))) 
 
  if (xy=="x") return(paste(Deg," ",min2, " W", sep="")) else return(paste(Deg," ",min2, " N", sep=""))
  
}