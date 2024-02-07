#!/bin/sh
read -p "Password for apps (Flame, Nextcloud, ...)" PASSWORD
read -p "Plex claim ID (https://plex.tv/claim): " PLEX_CLAIM
export $PASSWORD
export $PLEX_CLAIM
export APPDATA_MNT=/mnt/gluster/appdata
export MEDIA_MNT=/mnt/gluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export NETBIRDIP=$(netbird status --ipv4)

export GATEWAY=$(ip route | grep default | awk '{print $3}')
export DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
export NETWORK=$(ip a | grep -E 'enp|eth|eno' | grep -m 1 inet | awk '{print $2}' | awk -F'/' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')


docker stack up -c $1 $(basename $1 .yaml)
