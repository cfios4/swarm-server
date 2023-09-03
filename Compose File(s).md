# New Stacks 

**To do**:

- Containers:
	- Semaphore
	- AdGuard Home
- [[GlusterFS]] / Distributed File System

## Vars
```bash
CLUSTER_MNT=/mnt/cluster
APP_MNT=/mnt/cluster/appdata
MEDIA_MNT=/mnt/cluster/media
DOMAIN=cafio.co
SUBNET=192.168.45.0/255.255.255.0
TAILSCALEIP=$(tailscale ip -4)
OVERLAY_NETWORK=overlaynet

PLEX_CLAIM=$(docker exec <plex-container> sh -c 'echo "#!/bin/bash" > plex_claim.sh && echo "curl -s \"https://plex.tv/api/claim/token?X-Plex-Token=\$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''\"'\'' -f 2)\" | cut -d '\''\"'\'' -f 2" >> plex_claim.sh && chmod +x plex_claim.sh' ; docker exec <plex-container> ./plex_claim.sh)

```

## Misc / 1st Stack
`docker stack up -c misc.yaml misc`
```yaml
---
version: "3.8"

services:

  caddy:
    image: caddy:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    ports:
      - ${HTTP_PORT:-80}:80
      - ${HTTPS_PORT:-443}:443
    environment:
      CADDYFILE: |
        # Main site
        ${DOMAIN} {
          reverse_proxy flame:5005
        }
  
        # Plex reverse proxy
        watch.${DOMAIN} {
          reverse_proxy https://${$HOSTNAME}.lan:32400 {
            transport http {
              tls
              tls_insecure_skip_verify
            }
          }
  
          reverse_proxy /sabnzbd* sabnzbd:8080
          basicauth /sabnzbd/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
  
          reverse_proxy /radarr* radarr:7878
          basicauth /radarr/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
  
          reverse_proxy /sonarr* sonarr:8989
          basicauth /sonarr/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
        }
  
        # VSCode reverse proxy
        code.${DOMAIN} {
          reverse_proxy vscode:3000
          basicauth {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
        }
  
        # PairDrop reverse proxy
        drop.${DOMAIN} {
          reverse_proxy pairdrop:3000
        }
  
        # Nextcloud reverse proxy
        cloud.${DOMAIN} {
          reverse_proxy nextcloud:80
        }
  
        # OnlyOffice reverse proxy
        office.${DOMAIN} {
          reverse_proxy onlyoffice:80
        }
    command: sh -c 'printenv CADDYFILE > /config/Caddyfile && caddy run --config /config/Caddyfile --adapter caddyfile'
    volumes:
      - ${APP_MNT}/caddy:/data
      - ${APP_MNT}/caddy:/config
  
  flame:
    image: pawelmalak/flame:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    environment:
      PASSWORD: changeme
    volumes:
      - ${APP_MNT}/flame:/app/data
      - /var/run/docker.sock:/var/run/docker.sock

# docker exec <tailscale-container> tailscale web --listen 0.0.0.0:8080
  tailscale:
    image: tailscale/tailscale:stable
    restart: unless-stopped
    hostname: tailscale
    networks:
      - ${OVERLAY_NETWORK}
    container_name: swarm
    cap_add: # Required for tailscale to work
      - net_admin
      - net_raw
    environment:
      TS_EXTRA_ARGS: --qr --timeout 60s --ssh --advertise-exit-node --advertise-routes=${SUBNET}
      TS_STATE_DIR: /var/lib
  #  command: sh -c "tailscale web --listen 0.0.0.0:8080"
    volumes:
      - ${APP_MNT}/tailscale:/var/lib # State data will be stored in this directory for node persistence
      - /dev/net/tun:/dev/net/tun # Required for tailscale to work
  
  vscode:
    image: linuxserver/vscodium:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    volumes:
      - ${APP_MNT}/vscode:/config
    labels:
      - flame.type=app
      - flame.name=VSCode
      - flame.icon=microsoft-visual-studio
      - flame.url=https://code.${DOMAIN}/
  
networks:
  ${OVERLAY_NETWORK}:
    driver: overlay
```
## Cloud
`docker stack up -c cloud.yaml cloud`
```yaml
---
version: "3.8"
  
services:
  
  pairdrop:
    image: linuxserver/pairdrop:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    tmpfs:
      - /config
    labels:
      - flame.type=app
      - flame.name=Pairdrop
      - flame.icon=share-variant
      - flame.url=https://drop.${DOMAIN}/
  
  nextcloud:
    image: nextcloud:latest
    deploy:
      replicas: 1
    container_name: nextcloud
    restart: unless-stopped
    networks:
      - ${OVERLAY_NETWORK}
    environment:
      - NEXTCLOUD_TRUSTED_DOMAIN=cloud.${DOMAIN}
      - SQLITE_DATABASE=nextcloud
  #    - MYSQL_PASSWORD=nextcloud
  #    - MYSQL_DATABASE=nextcloud
  #    - MYSQL_USER=nextcloud
  #    - MYSQL_${HOST_NETWORK}=mysql
    volumes:
      - ${APP_MNT}/nextcloud:/var/www/html
  
# Consider SQLite to reduce containers
  # mysql:
  #   image: mariadb:10.6
  #   container_name: mysql
  #   restart: unless-stopped
  #   command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
  #   environment:
  #     - MYSQL_ROOT_PASSWORD=nextcloud
  #     - MYSQL_PASSWORD=nextcloud
  #     - MYSQL_DATABASE=nextcloud
  #     - MYSQL_USER=nextcloud
  #   volumes:
  #     - ${APP_MNT}/mysql:/var/lib/mysql
  
  onlyoffice:
    image: onlyoffice/documentserver:latest
    deploy:
      replicas: 1
    container_name: onlyoffice
    restart: unless-stopped
    networks:
      - ${OVERLAY_NETWORK}
    tmpfs:
      - /var/log/onlyoffice
  
networks:
  ${OVERLAY_NETWORK}:
    external:
      name: ${OVERLAY_NETWORK}
```
## Media
`docker stack up -c media.yaml media`
```yaml
---
version: "3.8"
  
services:
 
  plex:
    image: plexinc/pms-docker:latest
    deploy:
      replicas: 1
    networks:
      - host
    ports:
      - 32400:32400
    environment:
      PLEX_CLAIM: ${PLEX_CLAIM} #https://plex.tv/claim
      ADVERTISE_IP: https://${$HOSTNAME}.lan:32400,https://${TAILSCALEIP}:32400,https://watch.${DOMAIN}:443
      ALLOWED_NETWORKS: ${SUBNET},100.64.0.0/255.192.0.0,10.0.11.0/255.255.255.0
    volumes:
      - ${APP_MNT}/plex:/config
      - ${MEDIA_MNT}:/media:ro
    tmpfs:
      - /transcode
    labels:
      - flame.type=app
      - flame.name=Plex
      - flame.icon=plex
      - flame.url=https://watch.${DOMAIN}/
  
  radarr:
    image: hotio/radarr:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    depends_on:
      - sabnzbd
    volumes:
      - ${APP_MNT}/radarr:/config
      - ${MEDIA_MNT}:/data
    labels:
      - flame.type=app
      - flame.name=Radarr
      - flame.icon=movie-open
      - flame.url=https://watch.${DOMAIN}/radarr/
      - flame.visibility=hidden
  
  sonarr:
    image: hotio/sonarr:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    depends_on:
      - sabnzbd
    volumes:
      - ${APP_MNT}/sonarr:/config
      - ${MEDIA_MNT}:/data
    labels:
      - flame.type=app
      - flame.name=Sonarr
      - flame.icon=youtube-tv
      - flame.url=https://watch.${DOMAIN}/sonarr/
      - flame.visibility=hidden
  
  sabnzbd:
    image: hotio/sabnzbd:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    volumes:
      - ${APP_MNT}/sabnzbd:/config
      - ${MEDIA_MNT}:/data
    labels:
      - flame.type=app
      - flame.name=Sabnzbd
      - flame.icon=cloud-download
      - flame.url=https://watch.${DOMAIN}/sabnzbd/
      - flame.visibility=hidden

networks:
  ${OVERLAY_NETWORK}:
    external:
      name: ${OVERLAY_NETWORK}

  host:
    name: host
```
# Docker Swarm 

Install `kompose` on Fedora and run `kompose convert` in the `compose.yaml`'s directory
`kompose convert -f docker-compose.yaml` [[Manifests]]

```yaml
---
version: "3.8"

services:
  caddy:
    image: caddy:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    ports:
      - ${HTTP_PORT:-80}:80
      - ${HTTPS_PORT:-443}:443
    environment:
      CADDYFILE: |
        # Main site
        cafio.co {
          reverse_proxy flame:5005
        }

        # Plex reverse proxy
        watch.cafio.co {
          reverse_proxy https://${HOSTNAME}.lan:32400 {
            transport http {
              tls
              tls_insecure_skip_verify
            }
          }

          reverse_proxy /sabnzbd* sabnzbd:8080
          basicauth /sabnzbd/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }

          reverse_proxy /radarr* radarr:7878
          basicauth /radarr/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }

          reverse_proxy /sonarr* sonarr:8989
          basicauth /sonarr/* {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
        }

        # VSCode reverse proxy
        code.cafio.co {
          reverse_proxy vscode:8443
          basicauth {
            admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
          }
        }

        # PairDrop reverse proxy
        drop.cafio.co {
          reverse_proxy pairdrop:3000
        }

        # Nextcloud reverse proxy
        cloud.cafio.co {
          reverse_proxy nextcloud:8080
        }

        # OnlyOffice reverse proxy
        office.cafio.co {
          reverse_proxy nextcloud:8081
        }
    command: sh -c 'printenv CADDYFILE > /config/Caddyfile && caddy run --config /config/Caddyfile --adapter caddyfile'
    volumes:
      - ~/swarmConfigs/apps/caddy:/data
      - ~/swarmConfigs/apps/caddy:/config

  flame:
    image: pawelmalak/flame:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    environment:
      PASSWORD: changeme
    volumes:
      - ~/swarmConfigs/apps/flame:/app/data
      - /var/run/docker.sock:/var/run/docker.sock

  plex:
    image: plexinc/pms-docker:latest
    deploy:
      replicas: 1
    networks:
      - hostnet
    environment:
      PLEX_CLAIM:  #https://plex.tv/claim
      ADVERTISE_IP: https://${HOSTNAME}.lan:32400,https://${TAILSCALEIP}:32400,https://watch.cafio.co:443
      ALLOWED_NETWORKS: 192.168.45.0/24,100.64.0.0/10
    volumes:
      - ~/swarmConfigs/apps/plex:/config
      - media:/media:ro
    tmpfs:
      - /transcode
    labels:
      - flame.type=app
      - flame.name=Plex
      - flame.icon=plex
      - flame.url=https://watch.cafio.co/

  radarr:
    image: hotio/radarr:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    depends_on:
      - sabnzbd
    volumes:
      - ~/swarmConfigs/apps/radarr:/config
      - media:/data
    labels:
      - flame.type=app
      - flame.name=Radarr
      - flame.icon=movie-open
      - flame.url=https://watch.cafio.co/radarr/
      - flame.visibility=hidden

  sonarr:
    image: hotio/sonarr:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    depends_on:
      - sabnzbd
    volumes:
      - ~/swarmConfigs/apps/sonarr:/config
      - media:/data
    labels:
      - flame.type=app
      - flame.name=Sonarr
      - flame.icon=youtube-tv
      - flame.url=https://watch.cafio.co/sonarr/
      - flame.visibility=hidden

  sabnzbd:
    image: hotio/sabnzbd:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    volumes:
      - ~/swarmConfigs/apps/sabnzbd:/config
      - media:/data
    labels:
      - flame.type=app
      - flame.name=Sabnzbd
      - flame.icon=cloud-download
      - flame.url=https://watch.cafio.co/sabnzbd/
      - flame.visibility=hidden

  vscode:
    build:
      context: .
      dockerfile_inline: |
        FROM linuxserver/code-server:latest
        ARG DOCKER_GID
        COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/
        RUN groupadd -g ${DOCKER_GID} docker && \
            usermod -aG docker abc && \
            touch /var/run/docker.sock && \
            chown :docker /var/run/docker.sock && \
            printf "alias 'terraform'='docker run --rm -v $PWD:/workspace -w /workspace -it hashicorp/terraform'\nalias 'packer'='docker run --rm -v $PWD:/workspace -w /workspace -it hashicorp/packer'" >> /etc/bash.bashrc
      args: 
        DOCKER_GID: $(cut -d: -f3 < <(getent group docker))
    image: vscode-dind:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    environment:
      - PUID: 1000
      - PGID: 1000
    volumes:
      - ~/swarmConfigs/apps/vscode:/config
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - flame.type=app
      - flame.name=VSCode
      - flame.icon=microsoft-visual-studio
      - flame.url=https://code.cafio.co/

  pairdrop:
    image: linuxserver/pairdrop:latest
    deploy:
      replicas: 1
    networks:
      - overlaynet
    tmpfs:
      - /config
    labels:
      - flame.type=app
      - flame.name=Pairdrop
      - flame.icon=share-variant
      - flame.url=https://drop.cafio.co/    

networks:
  overlaynet:
    driver: overlay
  hostnet:
    external:
      name: "host"

volumes:
  media:
    driver_opts:
      type: cifs
      device: "//gamingpc/media/data"
      o: "addr=gamingpc,vers=3.0,username=docker,password=docker,file_mode=0777,dir_mode=0777"
```

# Nextcloud Compose Stack

```yaml
---
version: "3.8"

services:

  tailscale:
    image: tailscale/tailscale:stable
    restart: unless-stopped
    container_name: tailscale
    network_mode: host
    hostname: nextcloud
    cap_add: # Required for tailscale to work
      - net_admin
      - net_raw
    environment:
      TS_EXTRA_ARGS: --qr --timeout 60s
      TS_STATE_DIR: /var/lib
    volumes:
      - tailscale:/var/lib # State data will be stored in this directory for node persistence
      - /dev/net/tun:/dev/net/tun # Required for tailscale to work

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - 8080:80
    environment:
      - NEXTCLOUD_TRUSTED_DOMAIN=cloud.${DOMAIN}
      - MYSQL_PASSWORD=nextcloud
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=mysql
    volumes:
      - nextcloud:/var/www/html 

  mysql:
    image: mariadb:10.6
    container_name: mysql
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    environment:
      - MYSQL_ROOT_PASSWORD=nextcloud
      - MYSQL_PASSWORD=nextcloud
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
    volumes:
      - mysql:/var/lib/mysql

  onlyoffice:
    image: onlyoffice/documentserver:latest
    container_name: onlyoffice
    restart: unless-stopped
    ports:
      - 8081:80
    tmpfs:
      - /var/log/onlyoffice

volumes:
  tailscale:
  nextcloud:
  mysql:
```
