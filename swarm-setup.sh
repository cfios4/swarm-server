#!/bin/bash
###################### Ran from swarm0  ######################
###################### BEGIN NODE SETUP ######################
## Vars
export CLUSTER_MNT=/mnt/cluster
export APPDATA_MNT=/mnt/cluster/appdata
export MEDIA_MNT=/mnt/cluster/media
export DOMAIN=cafio.co
export TZ=America/New_York
export SUBNET=192.168.45.0/255.255.255.0
export TAILSCALEIP=$(tailscale ip -4)
export PLEX_CLAIM=$(docker exec $(docker ps -f name=plex --format "{{.ID}}") sh -c 'curl -s "https://plex.tv/api/claim/token?X-Plex-Token=$(grep PlexOnlineToken config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | cut -d '\'' '\'' -f 4 | cut -d '\''"'\'' -f 2)" | cut -d '\''"'\'' -f 2')


swarm0=$(hostname -I | grep -oE '192\.168\.[0-9]+\.[0-9]+')
swarm1=
swarm2=
swarm3=
swarm=("swarm0" "swarm1" "swarm2" "swarm3")
tailscaleip=$(tailscale ip -4)

### swarm 0
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start
# Create SSH key and copy it to cluster
ssh-keygen -b 2048 -t rsa -f .ssh/id_rsa -q -N ""
ssh-copy-id swarm@swarm{1..3}
# Set IPs to swarms
cat <<EOF >> /etc/hosts
$swarm0       swarm0
$swarm1       swarm1
$swarm2       swarm2
$swarm3       swarm3
EOF

## Initialize Docker Swarm
docker swarm init --advertise-addr tailscale0
# Get manager and worker join token
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

# ## Initialize GlusterFS
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start

for node in ${swarm[@]} ; do
    ssh swarm@swarm1 ash <<SSH
#!/bin/bash
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start
# Set IPs to swarms
printf "$swarm0    swarm0
$swarm1    swarm1
$swarm2    swarm2
$swarm3    swarm3" >> /etc/hosts

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}

## Join the Swarm as a worker using the manager token
docker swarm join --token $manager_token $tailscaleip:2377

## Initialize GlusterFS on swarm 1
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
## Join the GlusterFS cluster on swarm 1
# if [ "$hostname" != swarm0 ] ; then
# gluster peer probe swarm0
# fi
SSH
done

##########################################################################
##########################################################################

### swarm 1
ssh swarm@swarm1 ash <<SSH
#!/bin/bash
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start
# Set IPs to swarms
cat <<EOF >> /etc/hosts
$swarm0       swarm0
$swarm1       swarm1
$swarm2       swarm2
$swarm3       swarm3
EOF

## Join the Swarm as a worker using the manager token
docker swarm join --token $manager_token $tailscaleip:2377

## Initialize GlusterFS on swarm 1
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
# ## Join the GlusterFS cluster on swarm 1
# gluster peer probe swarm0
SSH

### swarm 2
ssh swarm@swarm2 <<SSH
#!/bin/bash
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start
# Set IPs to swarms
cat <<EOF >> /etc/hosts
$swarm0       swarm0
$swarm1       swarm1
$swarm2       swarm2
$swarm3       swarm3
EOF

## Join the Swarm as a worker using the manager token
docker swarm join --token $manager_token $tailscaleip:2377

## Initialize GlusterFS on swarm 2
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
# ## Join the GlusterFS cluster on swarm 2
# gluster peer probe swarm0
SSH

### swarm 3
ssh swarm@swarm3 ash <<SSH
#!/bin/bash
# Setup
apk update
apk add docker
rc-update add docker boot
service docker start
# Set IPs to swarms
cat <<EOF >> /etc/hosts
$swarm0       swarm0
$swarm1       swarm1
$swarm2       swarm2
$swarm3       swarm3
EOF

## Join the Swarm as a worker using the worker token
docker swarm join --token $worker_token $tailscaleip:2377

## Initialize GlusterFS on swarm 3
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
# ## Join the GlusterFS cluster on swarm 3
# gluster peer probe swarm0
SSH

### Back to swarm 0
# ## Probe swarms back
# gluster peer probe swarm{1..3}
# # Create GlusterFS volumes for appdata and media
# gluster volume create appdata replica 4 swarm{0..3}:/mnt/cluster/appdata 
# gluster volume create media distributed swarm{0..3}:/mnt/cluster/media
# # Start GlusterFS volumes
# gluster volume start appdata
# gluster volume start media


###################### BEGIN SWARM SETUP ######################
# all managers need to have docker network/s for pihole
for node in $(docker node ls --filter "role=manager" --format "{{.Hostname}}") ; do
    ssh swarm@$node docker network create --config-only -o parent=enp6s18 --subnet 192.168.45.0/24 --gateway 192.168.45.1 --ip-range=192.168.45.254/32 dns-ip \
                    docker network create -d macvlan --scope swarm --attachable --config-from dns-ip macvlan4home
done

# this command will label all managers as having macvlan4home=true, do after the previous
docker node update --label-add "macvlan4home=true" $(docker node ls --filter "role=manager" --format "{{.ID}}")

### End of script
