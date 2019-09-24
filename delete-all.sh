#!/bin/bash

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
#docker image prune
#docker network prune
sudo rm -rf /var/lib/docker
sudo systemctl restart docker

cleanupdirs="/tmp/shield /var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/lib/cni /var/run/calico /var/run/flannel /opt/rke"
for dir in $cleanupdirs; do
    sudo rm -rf $dir
done
sudo rm -rf ~/rancher-store
rm -f .ra_*
rm -f .es_version
rm -f .es_branch
rm -f *.yaml
rm -f command.txt

