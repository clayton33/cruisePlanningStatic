# cruisePlanningStatic
Code that provides a static method of planning oceanographic cruises

# Instructions

## General Information
In order for the script to run successfully, the following directories need to be present. Some are optional, but suggested in certain circumstances. 

1. `bathymetry` This is an optional directory, which could contain a high resolution bathymetry `.asc` file. If it is not present, the script will call the function `getNOAA.bathy` from the `marmap` package, and download 1 minute resolution data over the range of latitudes and logitudes loaded from the given `.csv` file.

2. `functions` This contains various functions used in the script.

3. `routes` This includes, input .csv, output html, and .csv and route shapefiles for ArcGIS.

## Input .csv file

In order for the script to run, a `.csv` file must be pointed to which contains the following contents. An example has been provided.

  1. `lon_dd` A numeric value indicating longitude in decimal degrees
  2. `lat_dd` A numeric value indicating latitude in decimal degrees
  3. `station` An optional character string of the station name
  4. `operation` An optional character string indicating the specific operation order for the given operation type. For example, if the `type` is `Transit`, then the `operation` will likely be `Transit` as well. For the `type` `Operations`, this could be `Net_CTD`, indicating first a net will be taken then a CTD profile. If multiple items are happening, distingish by a number, for example, `Net_2_CTD_2_Argo_2` indicates that 2 nets will be taken, then 2 CTD profiles, then the deployment of 2 Argo floats.
  5. `core` And optional numeric value indicating if `1` it is apart of the core program, or `0` it is not apart of the core program.
  6. `optime` A numeric value indicating the total expected operational time at that location in hours.
  7. `xoptime` A numeric value indicating any extra operational time in hours that is anticipated during the occupation. For example, +2 hrs at the end of an occupation to wait for daylight.
  8. `type` A character string indicating either `Transit` or `Operations`, anything else is ignored.
  9. `comments` An optional character string for any comments, an example of this use is explaining why extra operational time is required.
  10. `owner` An optional character string indicating who the owner is, if applicable. As of now, this is mainly used for `Mooring` `operation` to identify the client.
  11. `loc1`
  12. `kts` A numeric value indicating the transit speed of the vessel between locations.

## Code Structure 

### cruiseplanning.R consists of 8 sections

An overview, and indications of where the user will have to change items is summarized below.

1. Loads the packages if they are not already installed

2. Loads all of the required libraries (1 and 2 only need to be run the first time the script is run in an open R session).

3. Set working directories. Since you'll be pulling this from Github, it doesn't require you to change anything, unless things are added on your end.

4. Enter the start date for the mission `s <- ISOdate(2019, 10, 05, 18)` start date and time for mission (Year, month, day, 24hr time)

5. You would specify your input file held in the route directory `file <- "AZMPFall_2020_config_02.csv"`
  
6. This section uses a bit of script was borrowed and modified by Jay Choi.

7. This extracts the depth from the ASCII bathymetry file to each point, or it extracts bathymetry from the downloaded NOAA bathymetry.

8. This final bit generates the shape file, .csv, removes depth from type “Transit” and creates a dynamic .html output.
 
After it is run you should see a dated map as a plot and the associate files should have been generated in your output folder, including your route timing .csv (attached with date/time).
