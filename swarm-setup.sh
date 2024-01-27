### all
name=swarmX
netbirdkey=xxxxx-xxxxx-xxxxx

sudo mkdir -p /mnt/{appdata,media} /gluster/{appdata,media}
sudo addgroup docker
sudo adduser --home /mnt --shell /bin/bash swarm
sudo usermod -aG sudo,docker swarm
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

sudo mkdir -p /{appdata,media} /mnt/gluster/{appdata,media}

sudo mkfs.ext4 /dev/nvme0n1
echo '/dev/nvme0n1 /mnt/gluster ext4 defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a
echo 'localhost:/appdata-volume /appdata glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
echo 'localhost:/media-volume /media glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
SSH
done

sudo gluster volume create appdata-volume replica 4 swarm1.netbird.cloud:/mnt/gluster/appdata swarm2.netbird.cloud:/mnt/gluster/appdata swarm3.netbird.cloud:/mnt/gluster/appdata swarm4.netbird.cloud:/mnt/gluster/appdata
sudo gluster volume create media-volume swarm1.netbird.cloud:/mnt/gluster/media swarm2.netbird.cloud:/mnt/gluster/media swarm3.netbird.cloud:/mnt/gluster/media swarm4.netbird.cloud:/mnt/gluster/media
sudo gluster volume start appdata-volume
sudo gluster volume start media-volume


### all
sudo mount -a


### any
sudo mkdir -p /appdata/{traefik,flame,gitea,nextcloud,pihole,postgres,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd} /media/{shows,movies}