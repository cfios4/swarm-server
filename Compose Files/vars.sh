#!/bin/bash
export APPDATA_MNT=/appdata
export MEDIA_MNT=/media
export PASSWORD=changeme
export DOMAIN=cafio.co
export PASSWORD=changeme
export TZ=America/New_York
export NETBIRDIP=$(netbird status --ipv4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')

# pihole
export GATEWAY=$(ip route | grep default | awk '{print $3}')
export DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
export NETWORK=$(echo $(ipcalc-ng -n $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate --no-decorate) | awk -F. '{print $1"."$2"."$3}')

sudo mkdir -p /appdata/{traefik,flame,gitea,nextcloud,overseerr,pihole,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd} /media/{shows,movies}
