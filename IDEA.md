MapWise

The Map Wise project is basically a map creator inspired by Google My Maps and Atlist.

# Features

excel/csv import with data for the map;
apply pre-selected styles and allow creation of new styles with json;
addition of geometric shapes (addition of layers);
marker customization
marker clustering
infowindow customization
marker grouping
embedding via iframe
allow street view integration
allow google autocomplete for addresses
allow creation of maps for tracking
- define a webhook for the map, this webhook will receive updates with latitude and longitude.
- path definition
- alert definition when deviating from the planned path

<iframe src="https://my.atlist.com/map/e463112d-1caa-48c8-be2a-4bfc5d390bc4?share=true" allow="geolocation 'self' https://my.atlist.com" width="100%" height="400px" frameborder="0" scrolling="no" allowfullscreen></iframe>

https://my.atlist.com/map/e463112d-1caa-48c8-be2a-4bfc5d390bc4?share=true

# Stack

Build everything in the most recent version of Rails. It has everything we need to build this project. For the map
rendering, we can use the Google Maps API. For the frontend, we can use Rails stack with Hotwire, Tailwind CSS, and
Stimulus JS. For the database, use SQLite.

# Securing API keys

MapWise will require API keys to access the Google Maps API. We have two options:

1. either let customers to provide their own API keys and store them in the database, or
2. create a pool of API keys and let customers use them.

If we go with the second options, we need to rotate the API keys regularly.

https://cloud.google.com/sdk/gcloud/reference/beta/services/api-keys

Create a new one -> update the records -> delete the old one after a day

# References

https://www.atlist.com/
https://batchgeo.com/
Google “My Maps”
