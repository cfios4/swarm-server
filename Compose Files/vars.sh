#!/bin/bash
export CLUSTER_MNT=/mnt/cluster
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}

##################### NOTES ###########################
## glusterfs is probably the best way to pool storage