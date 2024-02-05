#!/bin/sh
export APPDATA_MNT=/mnt/gluster/appdata
export MEDIA_MNT=/mnt/gluster/media
export DOMAIN=cafio.co
export PASSWORD=CHANGEME
export TZ=America/New_York
export NETBIRDIP=$(netbird status --ipv4)
export PLEX_CLAIM= #https://plex.tv/claim

export GATEWAY=$(ip route | grep default | awk '{print $3}')
export DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
export NETWORK=$(ip a | grep -E 'enp|eth|eno' | grep -m 1 inet | awk '{print $2}' | awk -F'/' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')


docker stack up -c $1.yaml $1
