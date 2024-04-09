#!/bin/bash

if [ "$EUID" -ne 0 ] ; then
  echo "Please run script as root"
  exit
fi

### script assumes/relies on the following
# Tested with Ubuntu 22.04
# the node names will be swarm1, swarm2, swarm3, swarm4 (only works with 4)
# swarm1 will be the initial/management/administrative
# swarm2-3 will be managers
# swarm4 will be a worker
# 1 IP below the first node will be used as a VIP with keepalived (make sure there is an available IP below the first node's, this shouldn't be an issue if the first node's IP is > x.x.x.2)
# The assumption of the above line is that the default gateway is on x.x.x.1
# SSH must be setup (i.e. host verification, first-login password change, ...)

### INSTRUCTIONS
# Set the VIP variable in the keepalived_function
# Run following command in order of nodes (first run on initial node, then managers next, finally workers)
## sshpass -p "<password>" ssh -o StrictHostKeyChecking=no ubuntu@swarmX.lan "sudo bash -s" < ./swarm.sh <username> <password> <hostname>


function nvme_setup () {
    local GLUSTERMNT=/mnt/gluster/bricks
    local APPDATAMNT=/mnt/gluster/appdata
    local MEDIAMNT=/mnt/gluster/media
    local NVME=/dev/nvme0n1

    mkdir -vp $GLUSTERMNT $APPDATAMNT $MEDIAMNT
    chmod -R 755 $GLUSTERMNT
    
    systemctl enable glusterd ; systemctl start glusterd
    echo "##### Formatting external storage on $1... #####"
    mkfs.ext4 $NVME > /dev/null 2>&1
    echo "$NVME $GLUSTERMNT ext4 defaults 0 0" | tee -a /etc/fstab
    echo "##### Mounting external storage on $1... #####"
    mount -a
    echo "localhost:/appdata-volume $APPDATAMNT glusterfs defaults,_netdev 0 0" | tee -a /etc/fstab
    echo "localhost:/media-volume $MEDIAMNT glusterfs defaults,_netdev 0 0" | tee -a /etc/fstab
}

function keepalived_setup() {
    local VIP=192.168.45.40

    case "$2" in
        "swarm1")
            # local NETDEV=$(ip route | awk '/default/ {print $5}')
            # local DEVIP=$(ip addr show dev "$NETDEV" | awk '/inet / {print $2}' | cut -d '/' -f 1)
            # local FOUROCT=$(echo "$DEVIP" | awk -F. '{print $4}') ; ((FOUROCT--))
            # local VIP=192.168.45.$FOUROCT

            cat <<- EOF > /etc/keepalived/keepalived.conf
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
        auth_pass $1
    }

    virtual_ipaddress {
        $VIP
    }
}
EOF
            ;;
        "swarm2" | "swarm3")
            if [ $2 == "swarm2" ] ; then
                local PRIORITY=90
            elif [ $2 == "swarm3" ] ; then
                local PRIORITY=80
            fi

            cat <<- EOF > /etc/keepalived/keepalived.conf
global_defs {
    router_id DOCKER_INGRESS
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority $PRIORITY
    advert_int 1

    authentication {
      auth_type PASS
      auth_pass $1
    }

    virtual_ipaddress {
      $VIP
    }
}
EOF
            ;;
        "swarm4")
            cat <<- EOF > /etc/keepalived/keepalived.conf
global_defs {
    router_id DOCKER_INGRESS
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 70
    advert_int 1

    authentication {
      auth_type PASS
      auth_pass $1
    }

    virtual_ipaddress {
      $VIP
    }
}
EOF
            ;;
    esac

systemctl start keepalived ; systemctl enable keepalived
}

function final_touches () {
    echo $3 | tee /etc/hostname

    echo 'DNSStubListener=no' >> /etc/systemd/resolved.conf
    rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

    reboot
}

curl -sS https://starship.rs/install.sh | sh
curl -fsSL https://get.docker.com/ | bash
apt-get update -qq ; apt-get upgrade -y 2>&1 > /dev/null
apt-get install glusterfs-server keepalived sshpass -y -qq
useradd -m -s /bin/bash -G docker,sudo $1
echo $1:$2 | chpasswd
echo -e 'TZ=America/New_York\neval "$(starship init bash)"\nPID=$(id -u)\nGID=$(id -g)' >> /home/$1/.bashrc
echo "##### Gluster and Keepalived installed... #####"
echo "##### Performing tasks for $3... #####"

nvme_setup $3

case "$3" in
    "swarm1")
        # On swarm1
        echo "cluster=('swarm1' 'swarm2' 'swarm3' 'swarm4')" >> /home/$1/.bashrc
        export cluster=('swarm1' 'swarm2' 'swarm3' 'swarm4')

        ssh-keygen -N "" -f /home/$1/.ssh/id_rsa
        chmod 700 "/home/$1/.ssh"
        chmod 600 "/home/$1/.ssh/id_rsa"
        chmod 644 "/home/$1/.ssh/id_rsa.pub"

        docker swarm init

        swarmip=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
        echo -e "docker swarm join --token $(docker swarm join-token manager -q) $swarmip:2377" > /tmp/manager
        echo -e "docker swarm join --token $(docker swarm join-token worker -q) $swarmip:2377" > /tmp/worker

        host=$(echo $swarmip | awk -F. '{print $4}')
        for node in "${cluster[@]}" ; do
            echo "192.168.45.$((host++)) $node.lan" >> /etc/hosts
        done

        keepalived_setup $2 $3

        cat << EOF > /usr/local/bin/final_touches
for node in "${cluster[@]}" ; do
    gluster peer probe $node.lan
    sshpass -p $2 ssh-copy-id -o StrictHostKeyChecking=no -i /home/$1/.ssh/id_rsa.pub $1@$node.lan
done

gluster volume create appdata-volume replica 4 swarm1.lan:/mnt/gluster/bricks/appdata swarm2.lan:/mnt/gluster/bricks/appdata swarm3.lan:/mnt/gluster/bricks/appdata swarm4.lan:/mnt/gluster/bricks/appdata
gluster volume create media-volume swarm1.lan:/mnt/gluster/bricks/media swarm2.lan:/mnt/gluster/bricks/media swarm3.lan:/mnt/gluster/bricks/media swarm4.lan:/mnt/gluster/bricks/media
gluster volume start appdata-volume
gluster volume start media-volume

rm \$0

echo $3 | tee /etc/hostname
reboot
EOF
        chmod +x /usr/local/bin/final_touches
        docker run --rm -dit -v /tmp:/srv -p 80:80 caddy caddy file-server -b
        echo -e "##### Once you are finished with all of the nodes, come back to $3 and run 'sudo final_touches' to setup the hostname and gluster volumes! #####"
        ;;

    "swarm2" | "swarm3")
        # On swarm2 or swarm3
        curl -fsSL swarm1.lan/manager | bash

        keepalived_setup $2 $3

        final_touches
        ;;

    "swarm4")
        # On swarm4
        curl -fsSL swarm1.lan/worker | bash

        keepalived_setup $2 $3

        final_touches
        ;;
esac