#!/bin/bash
export APPDATA_MNT=/appdata
export MEDIA_MNT=/media
export DOMAIN=cafio.co
export PASSWORD=changeme
export TZ=America/New_York
export NETBIRDIP=$(netbird status --ipv4)
export PLEX_CLAIM= #https://plex.tv/claim

# pihole
export GATEWAY=$(ip route | grep default | awk '{print $3}')
export DNS=$(docker network inspect macvlan4home -f '{{range .IPAM.Config}}{{.IPRange}}{{end}}' | awk -F/ '{print $1}')
#export NETWORK=$(echo $(ipcalc-ng -n $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate --no-decorate) | awk -F. '{print $1"."$2"."$3}')