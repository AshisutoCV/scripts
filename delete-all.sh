#!/bin/bash

####################
### K.K. Ashisuto
### VER=20191003a
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

sudo rm -rf rancher-store
rm -f .ra_*
rm -f .es_version
rm -f .es_branch
rm -f .es_update
rm -f *.yaml
rm -f command.txt
rm -f shield-stop.sh
rm -f shield-start.sh
rm -f shield-nodes.sh
rm -f shield-update.sh
rm -f node-setup.sh
rm -f *_backup
rm -f add-shield-repo.sh
rm -f clean-rancher-agent.sh
rm -f configure-sysctl-values.sh
rm -f delete-all.sh
rm -f delete-shield.sh
rm -f deploy-shield.sh
rm -f install-docker.sh
rm -f install-helm.sh
rm -f install-kubectl.sh
rm -f run-rancher.sh