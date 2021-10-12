# cruisePlanningStatic
Code that provides a static method of planning oceanographic cruises

# Instructions

## General Information

The script `cruisePlanning.R` contains code that aids in the planning of oceanographic cruises. As of now it is a single script that requires the user to change a few lines for it to work for the user.

In order for the script to run successfully, the following directories need to be present. Some are optional, but suggested in certain circumstances. They are all provided here in the Github repo, so no alteration or addition in needed by the user with the exception of the `bathymetry` directory.

1. `bathymetry` This is an optional directory, which could contain a high resolution bathymetry `.asc` file. If it is not present, the script will call the function `download.topo` from the `oce` package, and download 1 minute resolution data over the range of latitudes and logitudes loaded from the given `.csv` file. *note :* the user should insure the bathymetry data is present before going to sea. 

2. `functions` This contains various functions used in the script.

3. `routes` This includes, input `.csv`, output `.html`, output `.csv`, and route shapefiles for ArcGIS.

## Input .csv file

In order for the script to run, a `.csv` file must be pointed to which contains the following contents, in no particular order. An example has been provided.

  1. `lon_dd` A numeric value indicating longitude in decimal degrees
  2. `lat_dd` A numeric value indicating latitude in decimal degrees
  3. `station` An character string of the station name
  4. `operation` An character string indicating the specific operation order for the given operation type. For example, if the `type` is `Transit`, then the `operation` will likely be `Transit` as well. For the `type` `Operations`, this could be `Net_CTD`, indicating first a net will be taken then a CTD profile. If multiple items are happening, distingish by a number, for example, `Net_2_CTD_2_Argo_2` indicates that 2 nets will be taken, then 2 CTD profiles, then the deployment of 2 Argo floats.
  5. `core` An optional numeric value indicating if `1` it is apart of the core program, or `0` it is not apart of the core program.
  6. `optime` A numeric value indicating the total expected operational time at that location in hours.
  7. `xoptime` A numeric value indicating any extra operational time in hours that is anticipated during the occupation. For example, +2 hrs at the end of an occupation to wait for daylight.
  8. `type` A character string indicating either `Transit` or `Operations`, anything else is ignored.
  9. `comments` An optional character string for any comments, an example of this use is explaining why extra operational time is required.
  10. `owner` An optional character string indicating who the owner is, if applicable. As of now, this is mainly used for `Mooring` `operation` to identify the client.
  11. `loc1`
  12. `kts` A numeric value indicating the transit speed of the vessel between locations.

## Code Structure 

### cruiseplanning.R consists of 8 sections

An overview, summarized below. See `cruisePlanning.R` for additional details on what and where to change a few lines.

1. Downloads the packages if they are not already installed

2. Loads all of the required libraries (1 and 2 only need to be run the first time the script is run in an open R session).

3. Choose input file. This requires the user to supply the name of the file

4. Enter the start date for the mission `s <- ISOdate(2019, 10, 05, 18)` start date and time for mission (Year, month, day, 24hr time)

5. Load in bathymetry file if present OR download 1-minute resolution bathymetry data 
from NOAA. 
  
6. Distance calculations, and converts coordinates in decimal degrees to varying different forms.

7. This extracts the depth from the ASCII bathymetry file to each point, or it extracts bathymetry from the downloaded NOAA bathymetry. It then preps the data for export.

8. Write shapefile and save .csv. Create and save htmlplot.
 
After it is run you should see a dated map as a plot and the associate files should have been generated in your output folder, including your route timing .csv (attached with date/time).
