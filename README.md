# dms
data management server
these are a few scripts to create an odk-based data-collection, management, analysis and visualization platform using the following docker images:

- amancevice/superset 
- kobotoolbox/kobo-docker
- library/postgres
- chorss/docker-pgadmin4 
- opencpu/rstudio
- evertramos/docker-compose-letsencrypt-nginx-proxy-companion
- postgres

... and a few redis containers.  hopefully it will one day roll out a self-contained server with which to securely collect all the data for a project, clean and verify the data, allow for the execution of arbitrary R code on the data, and allow team members to visualize the data on superset or download it in stata, spss, excel, native Rdata, or csv format for local analysis.

to start a dms instance,
1. install and initialize the google cloud sdk with a google cloud project with billing
2. clone this repository (you only actually need the create.sh and the two .env.sample files)
3. rename the .env.sample files to .env and fill in the values you need
4. run ./create-dimas.sh <name of your instance> and wait about 5 minutes
  
you're done.
