#!/bin/bash
export CLUSTER_MNT=/mnt/cluster
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export SUBNET=192.168.45.0/255.255.255.0
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}

docker network create --config-only -o parent=enp6s18 --subnet 192.168.45.0/24 --gateway 192.168.45.1 --ip-range=192.168.45.254/32 dns-ip
docker network create -d macvlan --scope swarm --attachable --config-from dns-ip macvlan4home

##################### NOTES ###########################
## glusterfs is probably the best way to pool storage