### all
name=swarmX
netbirdkey=xxxxx-xxxxx-xxxxx

sudo mkdir -p /mnt/{.cluster,gluster/{appdata,media}}
sudo addgroup docker
sudo adduser --home /mnt --shell /bin/bash swarm
sudo usermod -aG sudo,docker swarm
sudo chown -R swarm:docker /mnt/{appdata,media,.cluster}
echo $name | sudo tee /etc/hostname
curl -fsSL https://get.docker.com | bash
curl -fsSL https://pkgs.netbird.io/install.sh | bash
netbird up -k $netbirdkey -n $name
sudo apt update ; sudo apt upgrade -y


### leader
docker swarm init --advertise-addr wt0
netbirdip=$(netbird status --ipv4)
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

for node in swarm2 swarm3 ; do
	ssh swarm@$node.netbird.cloud docker swarm join --token $manager_token $netbirdip:2377
done
ssh swarm@swarm4.netbird.cloud docker swarm join --token $worker_token $netbirdip:2377



##### gluster setup

### leader
for node in swarm1 swarm2 swarm3 swarm4 ; do
	ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s

apt update ; apt install -y glusterfs-server
systemctl enable glusterd ; systemctl start glusterd

sudo mkfs.ext4 /dev/nvme0n1
sudo mount /dev/nvme0n1 /mnt/.cluster
echo 'localhost:/appdata-volume /mnt/gluster/appdata glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
echo 'localhost:/media-volume /mnt/gluster/media glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
sudo mount -a
SSH
done

sudo gluster volume create appdata-volume replica 4 swarm1.netbird.cloud:/mnt/.cluster/appdata swarm2.netbird.cloud:/mnt/.cluster/appdata swarm3.netbird.cloud:/mnt/.cluster/appdata swarm4.netbird.cloud:/mnt/.cluster/appdata force
sudo gluster volume create media-volume swarm1.netbird.cloud:/mnt/.cluster/media swarm2.netbird.cloud:/mnt/.cluster/media swarm3.netbird.cloud:/mnt/.cluster/media swarm4.netbird.cloud:/mnt/.cluster/media force
sudo gluster volume start {appdata,media}-volume
sudo mkdir -p /mnt/gluster/media/{shows,movies} /mnt/gluster/appdata/{traefik,flame,gitea,nextcloud,pihole,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd}