#/bin/bash
set -e


# clean up
if gcloud compute instances list | grep "$1"; then 
gcloud compute instances delete "$1"
fi
if gcloud compute disks list | grep "$1-home"; then
gcloud compute disks delete "$1-home"
fi
if gcloud compute disks list | grep "$1-docker"; then 
gcloud compute disks delete "$1-docker"
fi

# blank disk for docker images
gcloud compute disks create "$1"-docker \
        --size=200GB \
        --verbosity=info
# blank disk for home directory and local data
gcloud compute disks create "$1"-home \
        --size=200GB \
        --verbosity=info
# ubuntu 16.04 base instance
gcloud compute instances create "$1" \
	--image-project=ubuntu-os-cloud \
	--image-family=ubuntu-1604-lts \
	--boot-disk-type pd-ssd \
	--disk=auto-delete=yes,device-name=home,name="$1-home" \
	--disk=auto-delete=yes,device-name=docker,name="$1-docker" \
	--can-ip-forward \
	--address=${DMS_EXTERNAL_IP:-dms} \
	--verbosity=info \
	--metadata-from-file env=../.env,proxy_env=../proxy/.env \
	--metadata startup-script-url=${STARTUP_SCRIPT:-"https://raw.githubusercontent.com/mlgrm/dms/master/scripts/dms-startup.sh"}
gcloud compute instances add-tags "$1" --tags http-server,https-server
gcloud compute config-ssh \
	--verbosity=info
gcloud compute instances tail-serial-port-output "$1" \
	--verbosity=info

