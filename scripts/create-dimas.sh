#/bin/bash
set -e

# ubuntu 16.04 base instance
gcloud compute instances create "$1" \
	--image-project=ubuntu-os-cloud \
	--image-family=ubuntu-1604-lts \
	--boot-disk-type pd-ssd \
	--can-ip-forward \
	--address=${DMS_EXTERNAL_IP:-dms} \
	--metadata=startup-script-url=${startup-url:-https://raw.githubusercontent.com/mlgrm/dms/master/scripts/dms-startup.sh} \
	--verbosity=info
# blank disk for docker images
gcloud compute disks create "$1"-docker \
        --image=doc-docker-virgin \
        --verbosity=info
# blank disk for home directory and local data
gcloud compute disks create "$1"-home \
        --image=doc-home-virgin \
        --verbosity=info
gcloud compute instances attach-disk "$1" \
        --disk="$1"-docker \
	--device-name="docker" \
        --verbosity=info
gcloud compute instances set-disk-auto-delete "$1" \
        --disk="$1"-docker \
        --verbosity=info
gcloud compute instances attach-disk "$1" \
        --disk="$1"-home \
	--device-name="home"
        --verbosity=info
gcloud compute instances set-disk-auto-delete "$1" \
        --disk="$1"-home \
        --verbosity=info
gcloud compute instances add-tags "$1" --tags http,https
gcloud compute config-ssh \
	--verbosity=info
gcloud compute instances tail-serial-port-output "$1" \
	--verbosity=info

