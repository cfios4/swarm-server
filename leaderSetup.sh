########## system setup
read -p "Node name (i.e. swarm1): " nodename
read -p "Netbird authkey: " netbirdkey

sudo adduser --home /home/swarm --shell /bin/bash swarm
echo $nodename | sudo tee /etc/hostname
curl -fsSL https://get.docker.com | bash
sudo usermod -aG sudo,docker swarm
curl -fsSL https://pkgs.netbird.io/install.sh | bash
netbird up -k $netbirdkey -n $nodename
sudo apt update ; sudo apt upgrade -y > /dev/null > 2>&1
sudo reboot

### LEADER ONLY (as swarm)
counter=41
for node in "${cluster[@]}" ; do
  echo "192.168.45.$((counter++)) $node.lan" >> /tmp/hosts
done
sudo sh -c "cat /tmp/hosts >> /etc/hosts"
unset counter

docker swarm init
cluster=("swarm1" "swarm2" "swarm3" "swarm4")
swarmip=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
manager_token=$(docker swarm join-token manager -q)
worker_token=$(docker swarm join-token worker -q)

ssh_key="$HOME/.ssh/id_rsa"
if [ ! -f "$ssh_key" ]; then
    ssh-keygen -t rsa -b 4096 -f -p "" "$ssh_key"
fi
for node in ${cluster[@]} ; do
    ssh-copy-id -i "$ssh_key.pub" "$node"
done

for node in ${cluster[@]:1:2} ; do
	ssh swarm@$node.lan docker swarm join --token $manager_token $swarmip:2377
done
for node in ${cluster[@]:3} ; do
	ssh swarm@swarm4.lan docker swarm join --token $worker_token $swarmip:2377
done


########## gluster setup
### LEADER ONLY
read -p "Password for 'swarm': " password

for node in ${cluster[@]} ; do
	ssh swarm@$node.lan <<SSH
echo $password | sudo -sS
sudo -s
mkdir -vp /mnt/gluster{/appdata,/media,/bricks}

apt update ; apt install -y glusterfs-server > /dev/null 2>&1
systemctl enable glusterd ; systemctl start glusterd
echo "Formatting external storage on $node..."
sudo mkfs.ext4 /dev/nvme0n1 > /dev/null 2>&1
echo '/dev/nvme0n1 /mnt/gluster/bricks ext4 defaults 0 0' | sudo tee -a /etc/fstab
echo "Mounting external storage on $node..."
mkdir -p /mnt/gluster/bricks/{appdata,media}
sudo mount -a
echo 'localhost:/appdata-volume /mnt/gluster/appdata glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
echo 'localhost:/media-volume /mnt/gluster/media glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
SSH
done

for node in ${cluster[@]} ; do
  sudo gluster peer probe $node.lan
done

sudo gluster volume create appdata-volume replica 4 swarm1.lan:/mnt/gluster/bricks/appdata swarm2.lan:/mnt/gluster/bricks/appdata swarm3.lan:/mnt/gluster/bricks/appdata swarm4.lan:/mnt/gluster/bricks/appdata
sudo gluster volume create media-volume swarm1.lan:/mnt/gluster/bricks/media swarm2.lan:/mnt/gluster/bricks/media swarm3.lan:/mnt/gluster/bricks/media swarm4.lan:/mnt/gluster/bricks/media
sudo gluster volume start appdata-volume
sudo gluster volume start media-volume

for node in ${cluster[@]} ; do
	ssh swarm@$node.lan bash <<SSH
echo $password | sudo -sS
sudo -s
echo "Mounting /etc/fstab on $node..."
sudo mount -a
SSH
done

sudo mkdir -p /mnt/gluster/appdata/{caddy,flame,gitea,nextcloud,pihole,plex,radarr,sabnzbd,sonarr,vaultwarden,vscode} /mnt/gluster/media/{shows,movies,usenet}


########## docker setup
### LEADER ONLY
for node in $(docker node ls --filter "role=manager" --format "{{.Hostname}}") ; do
  ssh swarm@$node.lan bash <<SSH
echo $password | sudo -sS
sudo -s
sudo apt update && sudo apt install -y ipcalc-ng && sudo apt remove -y ipcalc > /dev/null 2>&1
echo "Creating Docker network for DNS on $node..."
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