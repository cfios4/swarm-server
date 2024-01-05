#!/bin/bash
export CLUSTER_MNT=/mnt/cluster
export APPDATA_MNT=$CLUSTER_MNT/appdata
export MEDIA_MNT=$CLUSTER_MNT/media
export DOMAIN=cafio.co
export TZ=America/New_York
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')

# pihole
export GATEWAY=$(ip route | grep default | awk '{print $3}')
export DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
export NETWORK=$(echo $(ipcalc -n $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate --no-decorate) | awk -F. '{print $1"."$2"."$3}')

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}

##################### NOTES ###########################
## glusterfs is probably the best way to pool storage