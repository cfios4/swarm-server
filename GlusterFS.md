# GlusterFS

```bash
## All nodes with storage
# Create brick folder   
mkdir -p $CLUSTER_MNT/{appdata,media}

## On master
# Connect to other nodes
gluster peer probe swarm-{1..4}
# Create volume on nodes mapped to
gluster volume create clustervol replicas 4 swarm-{1..4}:$CLUSTER_MNT/appdata 
gluster volume create clustervol replicas 4 swarm-{1..4}:$CLUSTER_MNT/media
```

**Note:** It might be tempting to try `gluster volume create myvol2 replica 2 server{1..4}:/data/glusterfs/myvol2/brick{1,2}/brick` but Bash would expand the last `{}` first, so you would end up replicating between the two bricks on each servers, instead of across servers.

```bash
# Start volume
gluster volume start clustervol
```

## AppData mnt
```bash
# On one of the nodes (you only need to run this once):
gluster volume create appdata-volume replica 4 transport tcp \
  node1:/mnt/cluster/appdata \
  node2:/mnt/cluster/appdata \
  node3:/mnt/cluster/appdata \
  node4:/mnt/cluster/appdata

# Start the volume:
gluster volume start appdata-volume

# Mount the volume on each node:
mount -t glusterfs node1:/appdata-volume /mnt/cluster/appdata
```

## Media mnt
```bash
# On one of the nodes (you only need to run this once):
gluster volume create media-volume distributed transport tcp \
  node1:/mnt/cluster/media \
  node2:/mnt/cluster/media \
  node3:/mnt/cluster/media \
  node4:/mnt/cluster/media

# Start the volume:
gluster volume start media-volume

# Mount the volume on each node:
mount -t glusterfs node1:/media-volume /mnt/cluster/media
```
