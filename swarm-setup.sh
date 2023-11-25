#!/bin/bash
################## Turn this into a playbook ##########################
## Vars
swarm0=$(hostname -i)
swarm1=
swarm2=
swarm3=
tailscaleip=$(tailscale ip -4)

### swarm 0
## Setup
# Install and enable Docker
apk update
apk add docker
rc-update add docker boot
service docker start
# Create gluster bricks
mkdir -p /mnt/cluster/{appdata,media}
# Create SSH key and copy it to cluster
ssh-keygen -b 2048 -t rsa -f .ssh/id_rsa -q -N ""
ssh-copy-id swarm@swarm{1..3}
# Set IPs to swarms
cat <<EOF >> /etc/hosts
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


### swarm 1
ssh swarm@swarm1 <<EOF
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
EOF

### swarm 2
ssh swarm@swarm2 <<EOF
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
EOF

### swarm 3
ssh swarm@swarm3 <<EOF
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
EOF

## Join the Swarm as a worker using the worker token
docker swarm join --token $worker_token $tailscaleip:2377

## Initialize GlusterFS on swarm 3
# apk add glusterfs glusterfs-server
# rc-update add glusterd
# service glusterd start
# ## Join the GlusterFS cluster on swarm 3
# gluster peer probe swarm0
EOF

### Back to swarm 0
# ## Probe swarms back
# gluster peer probe swarm{1..3}
# # Create GlusterFS volumes for appdata and media
# gluster volume create appdata replica 4 swarm{0..3}:/mnt/cluster/appdata 
# gluster volume create media distributed swarm{0..3}:/mnt/cluster/media
# # Start GlusterFS volumes
# gluster volume start appdata
# gluster volume start media


### End of script
