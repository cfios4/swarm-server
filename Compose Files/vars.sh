## Global vars
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export SUBNET=192.168.45.0/255.255.255.0
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec <plex-container> sh -c 'echo "#!/bin/bash" > plex_claim.sh && echo "curl -s \"https://plex.tv/api/claim/token?X-Plex-Token=\$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''\"'\'' -f 2)\" | cut -d '\''\"'\'' -f 2" >> plex_claim.sh && chmod +x plex_claim.sh' ; docker exec <plex-container> ./plex_claim.sh)

mkdir -p $APPDATA_MNT/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sabnzbd,sonarr,}

docker network create --config-only --subnet 192.168.45.0/24 -o parent=enp6s18 --ip-range=192.168.45.254/32 agh-ip
docker network create -d macvlan --scope swarm --attachable --config-from agh-ip macvlan4home

############################################################
## just install rclone on the hosts and mount it to /mnt/s3/appdata/ on all nodes
# https://min.io/docs/minio/kubernetes/upstream/operations/concepts.html#minio-intro-server-pool
# https://min.io/docs/minio/linux/reference/minio-server/minio-server.html#command-minio.server
# https://min.io/docs/minio/kubernetes/upstream/operations/concepts/architecture.html#id11