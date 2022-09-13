#!/bin/bash

####################
### K.K. Ashisuto
### VER=20220906a-dev
####################

ES_PATH="$HOME/ericomshield"
cd $HOME

if which helm ; then
    kubectl -n kube-system delete deployment tiller-deploy
    kubectl delete clusterrolebinding tiller
    kubectl -n kube-system delete serviceaccount tiller
fi
docker stop $(docker ps -q)
while [ $(sudo docker ps | grep -v CONTAINER | wc -l) -ne 0 ]
do
    sleep 1
done
docker rm -f $(docker ps -qa)
while [ $(sudo docker ps -a| grep -v CONTAINER | wc -l) -ne 0 ]
do
    sleep 1
done
docker system prune -a -f
docker volume prune -f
sudo rm -rf /var/lib/docker
sudo systemctl restart docker

cat /proc/mounts | grep /var/lib/kubelet/pods/ | awk '{print $2}' | sudo xargs -I{} umount {}
cleanupdirs="/etc/ceph /etc/cni /etc/kubernetes /opt/cni /opt/rke /run/secrets/kubernetes.io /run/calico /var/run/calico /run/flannel /var/run/flannel /var/lib/calico /var/lib/etcd /var/lib/cni /var/lib/kubelet /var/lib/rancher/rke/log"
for dir in $cleanupdirs; do
    sudo rm -rf $dir
done


if [ -d ${ES_PATH} ]; then
    USERNAME=$(ls -ld  ${ES_PATH} | awk '{print $3}')
    GROUPNAME=$(ls -ld  ${ES_PATH} | awk '{print $4}')
    mv -f ${ES_PATH}/logs ${HOME}
    sudo rm -rf ${ES_PATH}
    mkdir -p ${ES_PATH}
    mv -f logs ${ES_PATH}/
    chown ${USERNAME}:${GROUPNAME} ${ES_PATH}
    chown ${USERNAME}:${GROUPNAME} ${ES_PATH}/logs
fi

sudo rm -rf .kube
sudo rm -f /home/ericom/.es_prepare

# for old ver
sudo rm -rf rancher-store
sudo rm -rf sup
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
rm -f delete-shield.sh
rm -f deploy-shield.sh
rm -f install-docker.sh
rm -f install-helm.sh
rm -f install-kubectl.sh
rm -f run-rancher.sh
# parent check
PARENTCMD=$(ps -o args= $PPID)
if [[ ${PARENTCMD} =~ shield-setup.sh ]]; then
    rm -f delete-all.sh
fi
