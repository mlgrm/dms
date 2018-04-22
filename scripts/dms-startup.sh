#!/bin/bash
set -e

export USER_NAME=${USER_NAME:-dimas}
export DMS_HOME=${DMS_HOME:-/home/dimas}
useradd -U -m ${USER_NAME}
mkdir ${DMS_HOME}
chown ${USER_NAME}:${USER_NAME} ${DMS_HOME}

apt-get update && apt-get upgrade -y

apt-get install -y docker curl wget git
useradd -G docker ${USER_NAME}

# install docker compose
sudo curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

su ${USER_NAME}
cd ${DMS_HOME}
git clone https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion.git
ln -s docker-compose-letsencrypt-nginx-proxy-companion/ proxy
export $IP_ADDR=$(curl ipinfo.io/ip)

cp proxy/.env.sample proxy/.env

patch proxy/.env << EO_DIFF
19c19
< IP=0.0.0.0
---
> IP=${IP_ADDR}
41c41
< NGINX_FILES_PATH=/path/to/your/nginx/data
---
> NGINX_FILES_PATH=${HOME}/proxy/data/
69,70c69,70
< #NGINX_WEB_LOG_MAX_SIZE=4m
< #NGINX_WEB_LOG_MAX_FILE=10
---
> NGINX_WEB_LOG_MAX_SIZE=4m
> NGINX_WEB_LOG_MAX_FILE=10
72,73c72,73
< #NGINX_GEN_LOG_MAX_SIZE=2m
< #NGINX_GEN_LOG_MAX_FILE=10
---
> NGINX_GEN_LOG_MAX_SIZE=2m
> NGINX_GEN_LOG_MAX_FILE=10
75,76c75,76
< #NGINX_LETSENCRYPT_LOG_MAX_SIZE=2m
< #NGINX_LETSENCRYPT_LOG_MAX_FILE=10
---
> NGINX_LETSENCRYPT_LOG_MAX_SIZE=2m
> NGINX_LETSENCRYPT_LOG_MAX_FILE=10
EO_DIFF

docker-compose.yml <<EO_DOCKER_COMPOSE
version: "3"

  superset:
    image: mlgrm/dms-superset
    restart: always
    ports:
      - "8088"
    volumes: # these need to be owned by uid 1000
      - ./superset_config.py:/etc/superset/superset_config.py
      - ./superset_lib/:/var/lib/superset/
    networks:
      - webproxy
      - privatenet
    environment:
      MAPBOX_API_KEY: ${MAPBOX_API_KEY}
      VIRTUAL_HOST: dimas.bigend.org
      LETSENCRYPT_EMAIL: joshua@bigend.io
      LETSENCRYPT_HOST: "dimas.bigend.org"
      CERT_NAME: dimas.bigend.org
      VIRTUAL_PORT: 8088
    depends_on:
      - redis
      - postgres
    links:
      - postgres:postgres
      - redis:redis

  redis:
    image: redis
    restart: always
    ports:
      - "6379"
    volumes:
      - redis:/data
    networks:
      - privatenet
  
  postgres:
    image: library/postgres
    restart: always
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: superset
      POSTGRES_PASSWORD: Eilteirtus2
      POSTGRES_USER: superset
    volumes:
      - ./postgresql-data:/var/lib/postgresql/data
    networks:
      - webproxy
      - privatenet

  pgadmin:
    image: chorss/docker-pgadmin4
    ports:
      - "5050:5050"
    environment:
      UID: 1000
      GID: 1000
    volumes:
      - ./pgadmin-data:/data/chorss/docker-pgadmin4
    networks:
      - webproxy
      - privatenet

  nginx-web:
    image: nginx
    labels:
        com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy: "true"
    container_name: ${NGINX_WEB:-nginx-web}
    restart: always
    ports:
      - "${IP:-0.0.0.0}:80:80"
      - "${IP:-0.0.0.0}:443:443"
    volumes:
      - ${NGINX_FILES_PATH:-./data}/conf.d:/etc/nginx/conf.d
      - ${NGINX_FILES_PATH:-./data}/vhost.d:/etc/nginx/vhost.d
      - ${NGINX_FILES_PATH:-./data}/html:/usr/share/nginx/html
      - ${NGINX_FILES_PATH:-./data}/certs:/etc/nginx/certs:ro
      - ${NGINX_FILES_PATH:-./data}/htpasswd:/etc/nginx/htpasswd:ro
    logging:
      options:
        max-size: ${NGINX_WEB_LOG_MAX_SIZE:-4m}
        max-file: ${NGINX_WEB_LOG_MAX_FILE:-10}

  nginx-gen:
    image: jwilder/docker-gen
    command: -notify-sighup ${NGINX_WEB:-nginx-web} -watch -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
    container_name: ${DOCKER_GEN:-nginx-gen}
    restart: always
    volumes:
      - ${NGINX_FILES_PATH:-./data}/conf.d:/etc/nginx/conf.d
      - ${NGINX_FILES_PATH:-./data}/vhost.d:/etc/nginx/vhost.d
      - ${NGINX_FILES_PATH:-./data}/html:/usr/share/nginx/html
      - ${NGINX_FILES_PATH:-./data}/certs:/etc/nginx/certs:ro
      - ${NGINX_FILES_PATH:-./data}/htpasswd:/etc/nginx/htpasswd:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro
    logging:
      options:
        max-size: ${NGINX_GEN_LOG_MAX_SIZE:-2m}
        max-file: ${NGINX_GEN_LOG_MAX_FILE:-10}

  nginx-letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: ${LETS_ENCRYPT:-nginx-letsencrypt}
    restart: always
    volumes:
      - ${NGINX_FILES_PATH:-./data}/conf.d:/etc/nginx/conf.d
      - ${NGINX_FILES_PATH:-./data}/vhost.d:/etc/nginx/vhost.d
      - ${NGINX_FILES_PATH:-./data}/html:/usr/share/nginx/html
      - ${NGINX_FILES_PATH:-./data}/certs:/etc/nginx/certs:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      NGINX_DOCKER_GEN_CONTAINER: ${DOCKER_GEN:-nginx-gen}
      NGINX_PROXY_CONTAINER: ${NGINX_WEB:-nginx-web}
    logging:
      options:
        max-size: ${NGINX_LETSENCRYPT_LOG_MAX_SIZE:-2m}
        max-file: ${NGINX_LETSENCRYPT_LOG_MAX_FILE:-10}

networks:
  default:
    external:
      name: ${NETWORK:-webproxy}
  privatenet:

volumes:
  redis:
    external: false

EO_DOCKER_COMPOSE

cd proxy/
./start.sh

docker exec dms_superset_1 superset_demo

