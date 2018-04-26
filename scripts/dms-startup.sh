#!/bin/bash
set -e
set -x

# retrieve and execute local .env file
curl -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/env -H "Metadata-Flavor: Google" > .env

set -a
. .env
set +a

export USER_NAME=${USER_NAME:-dimas}
export DMS_HOME=${DMS_HOME:-/home/dimas}
export CONF_URL=${CONF_URL:-"https://raw.githubusercontent.com/mlgrm/dms/master/"}

# update and install necessary packages
apt-get update && apt-get upgrade -y
apt-get install -y docker.io curl wget git apg gce-compute-image-packages

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

mkfs.ext4 /dev/disk/by-id/google-home-part1 && \
	mount /dev/disk/by-id/google-home-part1 /home
mkfs.ext4 /dev/disk/by-id/google-docker-part1 && \
	mount /dev/disk/by-id/google-docker-part1 /var/lib/docker
cat >> /etc/fstab <<EOFSTAB
/dev/disk/by-id/google-home-part1       /home   ext4    defaults        0 0
/dev/disk/by-id/google-docker-part1       /var/lib/docker ext4    defaults        0 0
EOFSTAB

# create default user and home direcory
useradd -U ${USER_NAME}
mkdir ${DMS_HOME}
chown ${USER_NAME}:${USER_NAME} ${DMS_HOME}
usermod -a -G docker ${USER_NAME}

# install docker compose
sudo curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

cd ${DMS_HOME}

# get the reverse proxy setup
git clone https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion.git
ln -s docker-compose-letsencrypt-nginx-proxy-companion/ proxy

# learn our external ip for proxy setup
export IP_ADDR=$(curl ipinfo.io/ip)

# initialise the environment files
cp proxy/.env.sample proxy/.env

# modify .env for our setup
curl https://raw.githubusercontent.com/mlgrm/dms/master/proxy/.env.diff | \
	patch proxy/.env

# create our docker compose config
wget $CONF_URL/docker-compose.yml

mkdir -p superset/data
wget $CONF_URL/superset/superset_config.py 
mv superset_config.py superset/

mkdir -p pgadmin/data
mkdir -p postgres/data
mkdir -p proxy/data

cd proxy/
chmod +x start.sh
chown -R ${USER_NAME}:${USER_NAME} ${DMS_HOME}
sudo -u ${USER_NAME} -H bash -c "./start.sh"

sudo -u ${USER_NAME} -H bash -c "docker exec dimas_superset_1 superset_demo"

