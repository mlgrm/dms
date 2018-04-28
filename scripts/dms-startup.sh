#!/bin/bash
set -e
set -x

export USER_NAME=${USER_NAME:-dms}
export DMS_HOME=${DMS_HOME:-/home/dms}
export CONF_URL=${CONF_URL:-"https://raw.githubusercontent.com/mlgrm/dms/master/"}

# format and mount data disks
sfdisk /dev/disk/by-id/google-home <<EOFDISK
label: dos
label-id: 0xd341d41b
device: /dev/disk/by-id/google-home
unit: sectors

/dev/disk/by-id/google-home-part1 : start=        2048, size=   419428352, type=83
EOFDISK

sfdisk /dev/disk/by-id/google-docker <<EOFDISK
label: dos
label-id: 0x2e52db8b
device: /dev/disk/by-id/google-docker
unit: sectors

/dev/disk/by-id/google-docker-part1 : start=        2048, size=   419428352, type=83
EOFDISK

# looks like links are created asynchronously.
# give the system time to catch up.
sleep 5

# format, prepare and mount partitions
mkfs.ext4 /dev/disk/by-id/google-home-part1
mount /dev/disk/by-id/google-home-part1 /mnt
tar c -C /home . | tar x -C /mnt
umount /mnt
mount /dev/disk/by-id/google-home-part1 /home
mkfs.ext4 /dev/disk/by-id/google-docker-part1
mkdir /var/lib/docker
mount /dev/disk/by-id/google-docker-part1 /var/lib/docker
cat >> /etc/fstab <<EOFSTAB
/dev/disk/by-id/google-home-part1       /home   ext4    defaults        0 0
/dev/disk/by-id/google-docker-part1       /var/lib/docker ext4    defaults        0 0
EOFSTAB

# update and install necessary packages
apt-get update && apt-get upgrade -y
apt-get install -y \
    curl wget git apg gce-compute-image-packages \
    apt-transport-https \
    ca-certificates \
    software-properties-common

# install docker from the official repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce

# install docker compose
curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# create default user and home direcory
useradd -U ${USER_NAME} -s "/bin/bash"
mkdir ${DMS_HOME}
chown ${USER_NAME}:${USER_NAME} ${DMS_HOME}
usermod -a -G docker ${USER_NAME}

cd ${DMS_HOME}

# get our file structure.  this includes (for now) a static version of 
# evertramos/docker-compose-letsencrypt-nginx-proxy-companion from 2018.04.26
# in the proxy directory until i find a clever way of downloading and 
# configuring it live
git clone https://github.com/mlgrm/dms.git

cd dms

# retrieve and execute local .env and proxy .env file.  these are stored on the
# metadata server by the gcloud initiation script scripts/create-dimas.sh
curl -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/env -H "Metadata-Flavor: Google" > .env
curl -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/proxy_env -H "Metadata-Flavor: Google" > proxy/.env

# make sure the user owns everything except superset, which runs as user 1000
chown -R $USER_NAME:$USER_NAME $DMS_HOME
chown -R 1000:1000 $DMS_HOME/dms/superset

# first run the proxy's start script, which invokes docker-compose in the 
# proxy directory
cd proxy
sudo -E -u ${USER_NAME} -H bash -c "./start.sh"

# now run our dms system behind the reverse proxy
cd ..
sudo -E -u $USER_NAME -H bash -c "docker-compose up -d"

# and install the demo data just for fun
sudo -E -u ${USER_NAME} -H bash -c \
	"docker exec -it dms_superset_1 'superset-init && superset-demo'"

