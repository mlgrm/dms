#!/bin/bash
set -e
set -x

export USER_NAME=${USER_NAME:-dimas}
export DMS_HOME=${DMS_HOME:-/home/dimas}
export CONF_URL=${CONF_URL:-"https://raw.githubusercontent.com/mlgrm/dms/master/"}

# update and install necessary packages
apt-get update && apt-get upgrade -y
apt-get install -y docker.io curl wget git apg

# format and mount data disks
sfdisk /dev/disk/by-id/google-home <<EOFDISK
label: dos
label-id: 0xadbd6c09
device: /dev/sdb
unit: sectors

/dev/sdb1 : start=        2048, size=   419428352, type=83
EOFDISK

sfdisk /dev/disk/by-id/google-docker <<EOFDISK
label: dos
label-id: 0xadbd6c09
device: /dev/sdb
unit: sectors

/dev/sdb1 : start=        2048, size=   419428352, type=83
EOFDISK

mkfs.ext4 /dev/disk/by-id/google-home-part1 && \
	mount /dev/disk/by-id/google-home-part1 /home
mkfs.ext4 /dev/disk/by-id/google-docker-part1 && \
	mount /dev/disk/by-id/google-docker-part1 /var/lib/docker
cat >> /etc/fstab <<EOFSTAB
/dev/disk/by-id/google-home-part1       /home   ext4    defaults        0 0
/dev/disk/by-id/google-docker-part1       /var/lib/docker ext4    defaults        0 0
EOFSTAB

# get environment variables from the metadata server
ENVFILE=$(mktemp "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")
wget -O $ENVFILE http://metadata.google.internal/computeMetadata/v1/instance/attributes/env
set -a
source $ENVFILE
set +a
rm env

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
wget -0 ../docker-compose.yml $CONF_URL/docker-compose.yml

mkdir -p superset/data
wget $CONF_URL/superset/superset_config.py 
mv superset_config.py superset/

mkdir -p pgadmin/data
mkdir -p pgadmin/data
mkdir -p nginx/data

cd proxy/
chmod +x start.sh
chown -R ${USER_NAME}:${USER_NAME} ${DMS_HOME}

sudo -u ${USER_NAME} -H bash -c "./start.sh"

sudo -u ${USER_NAME} -H bash -c "docker exec dimas_superset_1 superset_demo"

