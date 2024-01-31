##### system setup
### ALL NODES (done manually, copy-paste)
read -p "Node name (i.e. swarm1): " nodename
read -p "Netbird authkey: " netbirdkey

sudo mkdir -p /{appdata,media} /mnt/gluster/{appdata,media}
sudo adduser --home /home/swarm --shell /bin/bash swarm
echo $nodename | sudo tee /etc/hostname
curl -fsSL https://get.docker.com | bash
sudo usermod -aG sudo,docker swarm
curl -fsSL https://pkgs.netbird.io/install.sh | bash
netbird up -k $netbirdkey -n $nodename
sudo apt update ; sudo apt upgrade -y
sudo reboot

########## keepalived setup
### ALL NON-LEADER ONLY
sudo apt update ; sudo apt install -y keepalived
PRIORITY=100
sudo tee /etc/keepalived/keepalived.conf <<EOF
global_defs {  
  router_id DOCKER_INGRESS  
}  

vrrp_instance VI_1 {
  state BACKUP
  interface eth0
  virtual_router_id 51
  priority $((PRIORITY -= 10))
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