#/bin/bash
set -e

gcloud compute instances create "$1" \
	--image-project=ubuntu-os-cloud \
	--image-family=ubuntu-1604-lts \
	--boot-disk-type pd-ssd \
	--can-ip-forward \
  --address=${DMS_EXTERNAL_IP} \
  --metadata=startup-script=dms_startup.sh \
	--verbosity=info

# preserve the local ssh config
# cat ~/.ssh/config.stub > ~/.ssh/config

gcloud compute config-ssh \
	--verbosity=info
#gcloud compute instances start "$1" \
#	--verbosity=info
gcloud compute instances tail-serial-port-output "$1" \
	--verbosity=info

