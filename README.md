# swarm-server
This repo is supposed to use the `swarm-setup.sh` to create a Swarm cluster with a Glustered storage to synchronize application data across nodes and to pool remaining storage together for media library.

## Stacks

There are 3 seperate stacks of services:
1. `Misc / 1st Stack`
    - This stack deploys the web server / reverse proxy (with configuration file) and the dashboard.
2. `Cloud`
    - This stack deploys, what would be considered, "cloud services". 
3. `Media`
    - This stack deploys anything related to the media server portion.
  
## UFW
`Uncomplicated Firewall` is a simple `iptables` frontend. The provided code should be put into a file at `/etc/ufw/applications.d/ufw-swarmtailscale`. This creates profiles when using `ufw app list` and makes it simpler to allow the correct ports.
