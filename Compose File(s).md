# Compose File(s)

**To do**:

- Containers:
	- Semaphore
	- [AdGuard Home](https://gist.github.com/scyto/ce866ee606ef27fd7c47832005b55d9f) (currently on Proxmox)
	- ~~Vaultwarden~~
	- ~~Microbin~~
- [GlusterFS](https://github.com/cfios4/swarm-server/blob/main/GlusterFS.md) / Distributed File System
- [Syncthing](https://superuser.com/questions/1397683/how-can-i-configure-syncthing-from-command-line-to-share-a-folder-with-another-c) for AppData (may require some manual setup)
## Vars
```bash
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

       # DoH
       agh.${DOMAIN} {
         handle /super_secret_password {
           rewrite /super_secret_password /dns-query
           reverse_proxy https://192.168.45.254:53 {
             transport http {
               tls
               tls_insecure_skip_verify
             }
           }
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

       # MicroBin reverse proxy
       bin.${DOMAIN} {
         reverse_proxy microbin:80
       }
       
       # VSCode reverse proxy
       code.${DOMAIN} {
         reverse_proxy vscode:3000
         basicauth {
          admin $$2a$$14$$59fq3dJu7BMgI4os7Z11sOqPUjAsZIg9QFytUDIfVR64v8NlA56Ge
         }
       }
  
       # Vaultwarden reverse proxy
       vault.${DOMAIN} {
         reverse_proxy vaultwarden:80   
       }
  
       # Gitea reverse proxy
       git.${DOMAIN} {
         reverse_proxy gitea:3000   
       }
  
       # Plex reverse proxy
       watch.${DOMAIN} {
         reverse_proxy https://plex:32400 {
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
    networks:
      - ${OVERLAY_NETWORK}
    environment:
      NEXTCLOUD_TRUSTED_DOMAIN=cloud.${DOMAIN}
      SQLITE_DATABASE=nextcloud
   #    MYSQL_PASSWORD=nextcloud
   #    MYSQL_DATABASE=nextcloud
   #    MYSQL_USER=nextcloud
   #    MYSQL_${HOST_NETWORK}=mysql
    volumes:
      - ${APP_MNT}/nextcloud:/var/www/html
    labels:
      - flame.type=app
      - flame.name=Cloud
      - flame.icon=cloud
      - flame.url=https://cloud.${DOMAIN}/
  
# Consider SQLite to reduce containers
  # mysql:
  #   image: mariadb:10.6
  #   container_name: mysql
  #   restart: unless-stopped
  #   command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
  #   environment:
  #     MYSQL_ROOT_PASSWORD=nextcloud
  #     MYSQL_PASSWORD=nextcloud
  #     MYSQL_DATABASE=nextcloud
  #     MYSQL_USER=nextcloud
  #   volumes:
  #     - ${APP_MNT}/mysql:/var/lib/mysql
  
  onlyoffice:
    image: onlyoffice/documentserver:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    tmpfs:
      - /var/log/onlyoffice

  microbin:
    image: danielszabo99/microbin:latest
    networks:
      - ${OVERLAY_NETWORK}
    environment:
      MICROBIN_ADMIN_USERNAME: admin
      MICROBIN_ADMIN_PASSWORD: changeme
      MICROBIN_EDITABLE: 'true'
      MICROBIN_HIGHLIGHTSYNTAX: 'true'
      MICROBIN_PORT: 80
      MICROBIN_BIND: 0.0.0.0
      MICROBIN_PRIVATE: 'true'
      MICROBIN_PUBLIC_PATH: https://bin.${DOMAIN}/
      MICROBIN_SHOW_READ_STATS: 'true'
      MICROBIN_TITLE: cafio
      MICROBIN_ENABLE_BURN_AFTER: 'true'
      MICROBIN_WIDE: 'true'
      MICROBIN_QR: 'true'
      MICROBIN_EXTERNAL_PASTA: 'true'
      MICROBIN_ENABLE_READONLY: 'true'
      MICROBIN_ENCRYPTION_CLIENT_SIDE: 'true'
      MICROBIN_ENCRYPTION_SERVER_SIDE: 'true'
      MICROBIN_DISABLE_TELEMETRY: 'true'
    volumes:
      - ${APP_MNT}/microbin:/app/microbin_data
    labels:
      - flame.type=app
      - flame.name=Microbin
      - flame.icon=delete-variant
      - flame.url=https://bin.${DOMAIN}/
  
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

  vaultwarden:
    image: vaultwarden/server:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAY_NETWORK}
    environment:
      DOMAIN: https://vault.${DOMAIN}/
      SENDS_ALLOWED: 'true'
      EMERGENCY_ACCESS_ALLOWED: 'true'
      WEB_VAULT_ENABLED: 'true'
      SIGNUPS_ALLOWED: 'false'
      SIGNUPS_VERIFY: 'false'
      SIGNUPS_DOMAINS_WHITELIST: ${DOMAIN}
      YUBICO_CLIENT_ID: 92307
      YUBICO_SECRET_KEY: 72o9iOvaz1yUO+6MomnE7EkPNgw=
    volumes:
      - ${APP_MNT}/vaultwarden:/data
    labels:
      - flame.type=app
      - flame.name=Microbin
      - flame.icon=lock
      - flame.url=https://vault.${DOMAIN}/

  gitea:
    image: gitea/gitea:latest
    deploy:
      replicas: 1
    networks:
      - ${OVERLAYNET}
    environment:
      PROTOCOL: https
      DOMAIN: ${DOMAIN}
      HTTP_PORT: 3000
      APP_NAME: Gitea
      SHOW_USER_EMAIL: false
      REVERSE_PROXY_TRUSTED_PROXIES: 127.0.0.0/8,::1/128, 192.168.45.0/24, cafio.co
      EMAIL_DOMAIN_ALLOWLIST: ${DOMAIN}
    volumes:
      - ${APP_MNT}/gitea/config:/etc/gitea
      - ${APP_MNT}/gitea/data:/var/lib/gitea
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    lables:
      - flame.type=app
      - flame.name=Microbin
      - flame.icon=git
      - flame.url=https://git.${DOMAIN}/

networks:
  ${OVERLAY_NETWORK}:
    external: true
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
      - ${OVERLAY_NETWORK}
    environment:
      PLEX_CLAIM: ${PLEX_CLAIM} #https://plex.tv/claim
      ADVERTISE_IP: https://${HOSTNAME}.lan:32400,https://${TAILSCALEIP}:32400,https://watch.${DOMAIN}:443
      ALLOWED_NETWORKS: ${SUBNET},100.64.0.0/255.192.0.0,10.0.0.0/255.0.0.0
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
    configs:
        sabnzbd_config:
        file: /config/sabnzbd.ini
    labels:
      - flame.type=app
      - flame.name=Sabnzbd
      - flame.icon=cloud-download
      - flame.url=https://watch.${DOMAIN}/sabnzbd/
      - flame.visibility=hidden

networks:
  ${OVERLAY_NETWORK}:
    external: true
```
