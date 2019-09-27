#!/bin/bash

####################
### K.K. Ashisuto
### VER=20190925a-dev
####################

if which helm ; then
    kubectl -n kube-system delete deployment tiller-deploy
    kubectl delete clusterrolebinding tiller
    kubectl -n kube-system delete serviceaccount tiller
fi

docker rm -f $(docker ps -qa)
while [ $(sudo docker ps | grep -v CONTAINER | wc -l) -ne 0 ]
do
    sleep 1
done
docker system prune -a -f
docker volume prune -f
sudo rm -rf /var/lib/docker
sudo systemctl restart docker

cleanupdirs="/var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/lib/cni /var/run/calico /var/run/flannel /opt/rke"
for dir in $cleanupdirs; do
    sudo rm -rf $dir
done

sudo rm -rf /home/${SUDO_USER}/rancher-store
rm -f .ra_*
rm -f .es_version
rm -f .es_branch
rm -f *.yaml
rm -f command.txt
rm -f shield-stop.sh
rm -f shield-start.sh
rm -f shield-nodes.sh
rm -f shield-update.sh
rm -f node-setup.sh

