#!/bin/bash -x
set -e

# make it interactive by default
# need to add options for -y version later
INTERACTIVE=0

INSTANCE_NAME=$1

# delete this instance if it exists
if gcloud compute instances list | grep "$INSTANCE_NAME"; then
gcloud compute instances delete "$1"
fi

# see if this ip address name is reserved and if it's in use warn the user
# otherwise, just delete it.
ADDR_LINE=$(gcloud compute addresses list | \
	grep "^dms-$INSTANCE_NAME\s" || \
	echo"")
if ! [ -z "$ADDR_LINE"] ; then
  if $(echo $ADDR_LINE | awk '{print $4}') = "IN_USE" ; then
    echo "this address ($(echo $ADDR_LINE | awk '{print $1}')) is being used by another   instance. press ctrl-C to abort or return to continue."
    read
    gcloud compute addresses delete "dms-$INSTANCE_NAME"
    gcloud compute addresses create "dms-$INSTANCE_NAME"
    fi
else
# create a new static ip.
gcloud compute addresses create "dms-$INSTANCE_NAME" --region europe-west3
fi


# the ip address is the third field in the line that starts with dms-$INSTANCE_NAME
IP_ADDRESS=$(gcloud compute addresses list | \
  grep -e "^dms-$INSTANCE_NAME\s" | \
  awk '{print $3}')
  
# start with the default 10 gig container-optimized image, add disks if necessary

gcloud compute instances create $INSTANCE_NAME \
  --image-family=cos-stable \
  --image-project=cos-cloud \
  --can-ip-forward \
	--address=$IP_ADDRESS \
	--verbosity=info \
	--metadata-from-file user-data=./startup.yml,env=./.env \
	--tags=http-server,https-server \
	--machine-type n1-standard-1

gcloud compute config-ssh \
	--verbosity=info
gcloud compute instances tail-serial-port-output "$1" \
	--verbosity=info
