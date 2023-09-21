#!/bin/bash

## Vars
node0=$(hostanme -i)
node1=
node2=
node3=

## Node 0
# Setup
apk update
apk add docker
rc-update add docker boot
service docker start
mkdir -p /mnt/cluster/{appdata,media}

cat <<EOF > /etc/hosts
$node1       node1
$node2       node2
$node3       node3
EOF

# Initialize Docker Swarm and get manager join token
docker swarm init --advertise-addr tailscale0
tailscaleip=$(tailscale ip -4)
manager_token=$(docker swarm join-token manager -q)

# Initialize GlusterFS
apk add glusterfs glusterfs-server
rc-update add glusterd
service glusterd start

# Get worker join token
worker_token=$(docker swarm join-token worker -q)

## Node 1
ssh swarm@node1 <<EOF
#!/bin/bash
# Setup
apk update
apk add docker
rc-update add docker boot
service docker start

cat <<EOF > /etc/hosts
$node0       node0
$node2       node2
$node3       node3
EOF

# Join the Swarm as a worker using the manager token
docker swarm join --token $manager_token $tailscaleip:2377

# Initialize GlusterFS on Node 2
apk add glusterfs glusterfs-server
rc-update add glusterd
service glusterd start

# Join the GlusterFS cluster on Node 2
gluster peer probe node0
EOF

## Node 2
ssh swarm@node2 <<EOF
#!/bin/bash
# Setup
apk update
apk add docker
rc-update add docker boot
service docker start

cat <<EOF > /etc/hosts
$node0       node0
$node1       node1
$node3       node3
EOF

# Join the Swarm as a worker using the manager token
docker swarm join --token $manager_token $tailscaleip:2377

# Initialize GlusterFS on Node 3
apk add glusterfs glusterfs-server
rc-update add glusterd
service glusterd start

# Join the GlusterFS cluster on Node 3
gluster peer probe node0
EOF

## Node 3
ssh swarm@node3 <<EOF
#!/bin/bash
# Setup
apk update
apk add docker
rc-update add docker boot
service docker start

cat <<EOF > /etc/hosts
$node0       node0
$node1       node1
$node2       node2
EOF

# Join the Swarm as a worker using the worker token
docker swarm join --token $worker_token $tailscaleip:2377

# Initialize GlusterFS on Node 3
apk add glusterfs glusterfs-server
rc-update add glusterd
service glusterd start

# Join the GlusterFS cluster on Node 3
gluster peer probe node0
EOF

## Back to Node 0
# Probe nodes back
gluster peer probe node{1..3}
# Create GlusterFS volumes for appdata and media
gluster volume create appdata replica 4 node{1..3}:/mnt/cluster/appdata 
gluster volume create media distributed node{1..3}:/mnt/cluster/media

# Start GlusterFS volumes
gluster volume start appdata
gluster volume start media

# End of script
