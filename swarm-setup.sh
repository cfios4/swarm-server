##### system setup
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
docker swarm init
swarmip=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

for node in swarm2 swarm3 ; do
	ssh swarm@$node.netbird.cloud docker swarm join --token $manager_token $swarmip:2377
done
ssh swarm@swarm4.netbird.cloud docker swarm join --token $worker_token $swarmip:2377



##### gluster setup
### leader
for node in swarm1 swarm2 swarm3 swarm4 ; do
	ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s

sudo mkdir -p /{appdata,media} /mnt/gluster/{appdata,media}
apt update ; apt install -y glusterfs-server
systemctl enable glusterd ; systemctl start glusterd

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

for node in swarm1 swarm2 swarm3 swarm4 ; do
	ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s
sudo mount -a
SSH
done


##### docker setup
### leader
for node in $(docker node ls --filter "role=manager" --format "{{.Hostname}}") ; do
    ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s
sudo apt update ; sudo apt install ipcalc-ng ; sudo apt remove ipcalc
docker network create --config-only -o parent=\$(ip link show | grep -Po '^\d+: \K(eth|eno|enp)[^:]+') --subnet \$(echo \$(ipcalc-ng -n \$(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print \$2}') --no-decorate)/\$(ipcalc-ng -p \$(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print \$2}') --no-decorate)) --gateway \$(ip route | grep default | awk '{print \$3}') --ip-range=\$(ip a | grep -E 'enp|eth|eno' | grep inet | awk '{print \$2}' | awk -F / '{print \$1}' | awk -F . '{print \$1"."\$2"."\$3}').254/32 macvlan4home
docker network create -d macvlan --scope swarm --attachable --config-from macvlan4home dns-ip
SSH
done

for node in $(docker node ls --filter "role=manager" -q) ; do
    docker node update --label-add "dns=true" $node
done