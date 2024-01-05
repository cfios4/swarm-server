#!/bin/bash
###################### Ran from swarm0 ######################
export CLUSTER_MNT=/mnt/cluster
swarm=("swarm0" "swarm1" "swarm2" "swarm3")

### swarm 0
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start

## Initialize Docker Swarm
docker swarm init --advertise-addr tailscale0
# Get variables for other nodes
tailscaleip=$(tailscale ip -4)
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

# ## Initialize GlusterFS
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start


###################### BEGIN NODE SETUP ######################
for node in ${swarm[@]} ; do
    ssh swarm@$node ash <<SSH
#!/bin/bash
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start

mkdir -p $CLUSTER_MNT/{media,appdata/{traefik,flame,gitea,nextcloud,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}}


if [ "$node" != swarm3 ] ; then
    ## Join the Swarm as a manager if not swarm3
    docker swarm join --token $manager_token $tailscaleip:2377
else
    ## Join the Swarm as a worker if swarm3
    docker swarm join --token $worker_token $tailscaleip:2377
fi

## Initialize GlusterFS on swarm 1
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
## Join the GlusterFS cluster on swarm 1
# if [ "$node" != swarm0 ] ; then
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

# all managers need to have docker network/s for pihole
for node in $(docker node ls --filter "role=manager" --format "{{.Hostname}}") ; do
    ssh swarm@$node docker network create --config-only -o parent=$(ip link show | grep -Po '^\d+: \K(eth|eno|enp)[^:]+') --subnet $(echo $(ipcalc -n $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate)/$(ipcalc -p $(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}') --no-decorate)) --gateway $(ip route | grep default | awk '{print $3}') --ip-range=$(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print $2}' | awk -F / '{print $1}' | awk -F . '{print $1"."$2"."$3}').254/32 macvlan4home \
                    docker network create -d macvlan --scope swarm --attachable --config-from macvlan4home dns-ip
done
# this command will label all managers as having macvlan4home=true, do after the previous
docker node update --label-add "macvlan4home=true" $(docker node ls --filter "role=manager" --format "{{.Hostname}}")