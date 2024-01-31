##### system setup
### ALL NODES
read -p "Node name (i.e. swarm1): " nodename
read -p "Netbird authkey: " netbirdkey

sudo mkdir -p /mnt/{appdata,media} /gluster/{appdata,media}
sudo addgroup docker
sudo adduser --home /home/swarm --shell /bin/bash swarm
sudo usermod -aG sudo,docker swarm
echo $nodename | sudo tee /etc/hostname
curl -fsSL https://get.docker.com | bash
curl -fsSL https://pkgs.netbird.io/install.sh | bash
netbird up -k $netbirdkey -n $nodename
sudo apt update ; sudo apt upgrade -y
sudo reboot