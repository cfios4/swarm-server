#!/bin/bash
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export CLUSTER_MNT=/mnt/cluster
export DOMAIN=cafio.co
export TZ=America/New_York
export SUBNET=192.168.45.0/255.255.255.0
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}" | tail -n 1) sh -c 'echo "#!/bin/bash" > plex_claim.sh && echo "curl -s \"https://plex.tv/api/claim/token?X-Plex-Token=\$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''\"'\'' -f 2)\" | cut -d '\''\"'\'' -f 2" >> plex_claim.sh && chmod +x plex_claim.sh') ; docker exec $(docker ps -f name=plex --format "{{.ID}}" | tail -n 1) ./plex_claim.sh

mkdir -p $APPDATA_MNT/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sabnzbd,sonarr,}

docker network create --config-only --subnet 192.168.45.0/24 -o parent=enp6s18 --ip-range=192.168.45.254/32 agh-ip
docker network create -d macvlan --scope swarm --attachable --config-from agh-ip macvlan4home

############################################################
## glusterfs is probably the best way to pool storage