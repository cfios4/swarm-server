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