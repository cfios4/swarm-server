```bash
CLUSTER_MNT=/mnt/cluster
## All nodes with storage
# Create brick folder   
mkdir -p $CLUSTER_MNT/{appdata,media}

## On master
# Connect to other nodes
gluster peer probe swarm-{1..4}
# Create volume on nodes mapped to
gluster volume create clustervol replicas 4 swarm-{1..4}:$CLUSTER_MNT/appdata swarm-{1..4}:$CLUSTER_MNT/media
```

**Note:** It might be tempting to try `gluster volume create myvol2 replica 2 server{1..4}:/data/glusterfs/myvol2/brick{1,2}/brick` but Bash would expand the last `{}` first, so you would end up replicating between the two bricks on each servers, instead of across servers.

```bash
# Start volume
gluster volume start clustervol
```