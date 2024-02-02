########## system setup
### LEADER ONLY (as swarm)
docker swarm init
cluster=("swarm1" "swarm2" "swarm3" "swarm4")
swarmip=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

ssh_key="$HOME/.ssh/id_rsa"
if [ ! -f "$ssh_key" ]; then
    echo "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$ssh_key"
fi
for node in ${cluster[@]} ; do
    echo "Copying public key to $node..."
    ssh-copy-id -i "$ssh_key.pub" "$node"
done

for node in ${cluster[@]:1:3} ; do
	ssh swarm@$node.netbird.cloud docker swarm join --token $manager_token $swarmip:2377
done
ssh swarm@swarm4.netbird.cloud docker swarm join --token $worker_token $swarmip:2377


########## gluster setup
### LEADER ONLY
for node in ${cluster[@]} ; do
	ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s

mkdir -p ~/{appdata,media} ~/.gluster/{appdata,media}
apt update ; apt install -y glusterfs-server
systemctl enable glusterd ; systemctl start glusterd
echo "Formatting external storage on $node..."
sudo mkfs.ext4 /dev/nvme0n1
echo '/dev/nvme0n1 /mnt/gluster ext4 defaults 0 0' | sudo tee -a /etc/fstab
echo "Mounting external storage on $node..."
sudo mount -a
echo 'localhost:/appdata-volume ~/appdata glusterfs defaults,_netdev,noauto,x-systemd.automount 0 0' | sudo tee -a /etc/fstab
echo 'localhost:/media-volume ~/media glusterfs defaults,_netdev,noauto,x-systemd.automount 0 0' | sudo tee -a /etc/fstab
SSH
done

sudo gluster volume create appdata-volume replica 4 swarm1.netbird.cloud:~/.gluster/appdata swarm2.netbird.cloud:~/.gluster/appdata swarm3.netbird.cloud:~/.gluster/appdata swarm4.netbird.cloud:~/.gluster/appdata
sudo gluster volume create media-volume swarm1.netbird.cloud:~/.gluster/media swarm2.netbird.cloud:~/.gluster/media swarm3.netbird.cloud:~/.gluster/media swarm4.netbird.cloud:~/.gluster/media
sudo gluster volume start appdata-volume
sudo gluster volume start media-volume

for node in ${cluster[@]} ; do
	ssh swarm@$node.netbird.cloud bash <<SSH
echo Admin!!1 | sudo -sS
sudo -s
echo "Mounting /etc/fstab on $node..."
sudo mount -a
SSH
done

mkdir -p ~/appdata/{flame,gitea,nextcloud,overseerr,pihole,vaultwarden,vscode,plex,radarr,sonarr,sabnzbd} ~/media/{shows,movies}


########## docker setup
### LEADER ONLY
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
    echo "Adding DNS labe for PiHole on $node..."
    docker node update --label-add "dns=true" $node
done


########## keepalived setup
### LEADER ONLY
sudo apt update ; sudo apt install -y keepalived
sudo tee /etc/keepalived/keepalived.conf <<EOF
global_defs {  
  router_id DOCKER_INGRESS  
}  

vrrp_instance VI_1 {
  state MASTER
  interface eth0
  virtual_router_id 51
  priority 100
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass changeme
  }
  virtual_ipaddress {
    192.168.45.40
  }
}
EOF
sudo systemctl start keepalived  
sudo systemctl enable keepalived