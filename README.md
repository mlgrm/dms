# dms
data management server
these are a few scripts to create an odk-based data-collection, management, analysis and visualization platform using modified versions of the following docker images:

- amancevice/superset 
- kobotoolbox/kobo-docker
- library/postgres
- chorss/docker-pgadmin4 
- opencpu/rstudio
- evertramos/docker-compose-letsencrypt-nginx-proxy-companion

... and a few redis containers.  hopefully it will one day roll out a self-contained server with which to securely collect all the data for a project, clean and verify the data, allow for the execution of arbitrary R code on the data, and allow team members to visualize the data on superset or download it in stata, spss, excel, native Rdata, or csv format for local analysis.
