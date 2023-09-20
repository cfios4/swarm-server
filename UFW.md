# UFW

Example UFW commands: \
`ufw allow in on enp6s18 to any app "WWW Full" comment 'HTTP/s'` \
`ufw allow in on tailscale0 to any app "Docker Swarm" comment 'Docker Swarm over Tailscale'` \
`ufw allow in on tailscale0 to any app "Tailscale" comment 'Tailscale'` \
`ufw allow app Plex comment 'Plex'` \
`ufw limit ssh comment 'Remote shell'` 

Folder Location:
`/etc/ufw/applications.d/ufw-swarmtailscale`
```ini
cat <<EOF > /etc/ufw/applications.d/ufw-swarmtailscale
[Docker Swarm]
title=Docker Swarm
description=Communication for Swarm cluster
ports=2377/tcp|7946/tcp,udp|4789/udp

[Tailscale]
title=Tailscale
description=Tailscale
ports=41641/udp

[Plex]
title=Plex
description=Plex
ports=32400/tcp
EOF
```
