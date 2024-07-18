#!/bin/bash

####################
### K.K. Ashisuto
### VER=20240718a
####################

ES_PATH="$HOME/ericomshield"
cd $HOME

echo "[start]Shield Delete-All Start."
echo
echo "=========================================="
dpkg -l | grep -e docker -e containerd
echo "=========================================="


sudo systemctl unmask docker.service
sudo systemctl unmask docker.socket

while [[ $(sudo systemctl status docker.service docker.socket | grep -c running) -ne 0 ]];
do
    sudo systemctl stop docker.service docker.socket
done

sudo rm /var/lib/apt/lists/lock
sudo rm /var/lib/dpkg/lock
sudo rm /var/lib/dpkg/lock-frontend

while [[ $(dpkg -l | grep -e docker -e containerd | grep  -c ^.i) -ne 0 ]];
do
    sudo apt-get purge -y --allow-change-held-packages $(dpkg -l | grep -e docker -e containerd | awk '{print $2}')
    sudo apt autoremove -y
done

sudo rm /home/ericom/.es_prepare

cat /proc/mounts | grep /var/lib/kubelet/pods/ | awk '{print $2}' | sudo xargs -I{} umount {}

sudo rm -rf /etc/ceph
sudo rm -rf /etc/cni
sudo rm -rf /etc/kubernetes
sudo rm -rf /opt/cni
sudo rm -rf /opt/rke
sudo rm -rf /run/secrets/kubernetes.io
sudo rm -rf /run/calico
sudo rm -rf /var/run/calico
sudo rm -rf /run/flannel
sudo rm -rf /var/run/flannel
sudo rm -rf /var/lib/calico
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/rancher/rke/log
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /var/elk
sudo rm -rf /home/ericom/ericomshield
sudo rm -rf /etc/docker
sudo rm -rf /var/run/docker.sock

sudo -E rm -rf ~/ericomshield/
sudo -E rm -rf ~/.docker/
sudo -E rm -rf ~/.kube/
sudo -E rm -rf ~/.rancher/
sudo -E rm -rf ~/.helm/

echo "=========================================="
dpkg -l | grep -e docker -e containerd
echo "=========================================="
echo
echo "[end]Shield Delete-All Complete!!"

# parent check
PARENTCMD=$(ps -o args= $PPID)
if [[ ${PARENTCMD} =~ shield-setup.sh ]]; then
    rm -f delete-all.sh
fi

exit 0
