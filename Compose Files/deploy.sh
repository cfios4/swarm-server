#!/bin/sh
APPDATA_MNT=./.appdata
MEDIA_MNT=/mnt/media
DOMAIN=cafio.co
PASSWORD=CHANGEME
TZ=America/New_York
NETBIRDIP=$(netbird status --ipv4)
PLEX_CLAIM= #https://plex.tv/claim

GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
NETWORK=$(ip a | grep -E 'enp|eth|eno' | grep -m 1 inet | awk '{print $2}' | awk -F'/' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')


docker stack up -c $1.yaml $1
