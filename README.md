# swarm-server
This repo is supposed to use the `swarm-setup.sh` to create a Swarm cluster with a Gluster pool to synchronize application data across nodes and to pool remaining storage together for media library

## Stacks

There are 3 seperate stacks of services:
1. `Initial`
    - This stack deploys the web server / reverse proxy (with configuration file), dashboard, DNS, ...
2. `Cloud`
    - This stack deploys what would be considered "cloud services"; Nextcloud, Vaultwarden, Gitea, Bin, Code Server, ...
3. `Media`
    - This stack deploys anything related to the media server

I want to have these stacks deployed like this: `curl https://raw.githubusercontent.com/cfios4/swarm-server/main/Compose%20Files/{initial,media,cloud}.yaml | docker stack up -c - initial` \
~~The stack yamls will need to be recreated in the Git repo to just be the yaml as opposed to [detailed version](https://git.cafio.co/casey/swarm-server/src/commit/0a699d4e96c83b28e40b68bbc9828bb2e1b3d2be/Compose%20File%28s%29.md)~~

## UFW
`Uncomplicated Firewall` is a simple `iptables` frontend. The provided code should be put into a file at `/etc/ufw/applications.d/ufw-swarmtailscale`, This creates profiles when using `ufw app list` and makes it simpler to allow the correct ports


this line is a test