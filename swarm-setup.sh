#!/bin/bash
###################### Ran from swarm0  ######################
export CLUSTER_MNT=/mnt/cluster
swarm=("swarm0" "swarm1" "swarm2" "swarm3")
tailscaleip=$(tailscale ip -4)

### swarm 0
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start

## Initialize Docker Swarm
docker swarm init --advertise-addr tailscale0
# Get manager and worker join token
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

# ## Initialize GlusterFS
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start


###################### BEGIN NODE SETUP ######################
for node in ${swarm[@]} ; do
    ssh swarm@swarm1 ash <<SSH
#!/bin/bash
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start

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
# else
    # gluster volume create appdata-volume replica 4 transport tcp \
    # swarm0:/mnt/cluster/appdata \
    # swarm1:/mnt/cluster/appdata \
    # swarm2:/mnt/cluster/appdata \
    # swarm3:/mnt/cluster/appdata
# fi
SSH
done