great.circle.distance <- function (loc1, loc2, R) {
  
  names(loc1) = c("lon", "lat")
  names(loc2) = c("lon", "lat")
  
  if (is.null(R)) R = 6367.436  # radius of earth (geometric mean) km
  # if R=1 then distances in radians
  if (missing(loc2)) loc2 <- loc1
  pi180 = pi/180
  coslat1 = cos(loc1$lat * pi180)
  sinlat1 = sin(loc1$lat * pi180)
  coslon1 = cos(loc1$lon * pi180)
  sinlon1 = sin(loc1$lon * pi180)
  coslat2 = cos(loc2$lat * pi180)
  sinlat2 = sin(loc2$lat * pi180)
  coslon2 = cos(loc2$lon * pi180)
  sinlon2 = sin(loc2$lon * pi180)
  pp =   cbind(coslat1 * coslon1, coslat1 * sinlon1, sinlat1) %*%
    t(cbind(coslat2 * coslon2, coslat2 * sinlon2, sinlat2))
  
  d = R * acos(ifelse(pp > 1, 1, pp))
  
  return(d)
}