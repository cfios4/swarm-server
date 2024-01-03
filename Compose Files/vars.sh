#!/bin/bash
export CLUSTER_MNT=/mnt/cluster
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}

# all managers need to have docker network/s for pihole
for node in $(docker node ls --filter "role=manager" --format "{{.Hostname}}") ; do
    ssh swarm@$node docker network create --config-only -o parent=$(ip link show | grep -Po '^\d+: \K(eth|eno|enp)[^:]+') --subnet $(echo $(ipcalc -n $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate)/$(ipcalc -p $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate)) --gateway $(ip route | grep default | awk '{print $3}') --ip-range=$(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}' | awk -F / '{print $1}' | awk -F . '{print $1"."$2"."$3}').254/32 dns-ip \
                    docker network create -d macvlan --scope swarm --attachable --config-from dns-ip macvlan4home
done
# this command will label all managers as having macvlan4home=true, do after the previous
docker node update --label-add "macvlan4home=true" $(docker node ls --filter "role=manager" --format "{{.ID}}")

##################### NOTES ###########################
## glusterfs is probably the best way to pool storage