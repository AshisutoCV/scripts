#!/bin/bash
############################################
#####   Ericom Shield Support          #####
#######################################BH###

####################
### K.K. Ashisuto
### VER=20191031b
####################

#Check if we are root
if ((EUID != 0)); then
    #    sudo su
    echo " Please run it as Root"
    echo "sudo" $0
    exit
fi

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"


usage() {
   echo "$0 [-y]"
   echo "    -y   : All logs are collected without confirmation."
}

y_flg=0

for i in `seq 1 ${#}`
do
    if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
        usage
        exit 0
    elif [ "$1" == "-y" ]; then
        y_flg=1
    else
        args="${args} ${1}"
    fi
    shift
done

if [ ! -z ${args} ]; then
    log_message "${args} は不正な引数です。"
    exit 1
fi

echo
echo " Shield Support: Collecting Info and Logs from System and Shield ....."
echo

# Create temp directory
TMPDIR=$(mktemp -d)

# System info
echo " Shield Support: Collecting System Info ....."
mkdir -p $TMPDIR/systeminfo
date > $TMPDIR/systeminfo/date 2>&1
hostname > $TMPDIR/systeminfo/hostname 2>&1
hostname -f > $TMPDIR/systeminfo/hostname-fqdn 2>&1
env > $TMPDIR/systeminfo/env 2>&1
cat /etc/hosts > $TMPDIR/systeminfo/etc-hosts 2>&1
cat /etc/resolv.conf > $TMPDIR/systeminfo/etcresolvconf 2>&1
systemd-resolve --status > $TMPDIR/systeminfo/systemd-resolve 2>&1
free -m > $TMPDIR/systeminfo/free-m 2>&1
cat /proc/buddyinfo > $TMPDIR/systeminfo/proc-buddyinfo 2>&1
cat /proc/meminfo > $TMPDIR/systeminfo/proc-meminfo 2>&1
cat /proc/cpuinfo > $TMPDIR/systeminfo/proc-cpuinfo 2>&1
uptime > $TMPDIR/systeminfo/uptime 2>&1
dmesg > $TMPDIR/systeminfo/dmesg 2>&1
df -hT > $TMPDIR/systeminfo/df-hT 2>&1
if df -i >/dev/null 2>&1; then
  df -i > $TMPDIR/systeminfo/df-i 2>&1
fi
lsmod > $TMPDIR/systeminfo/lsmod 2>&1
mount > $TMPDIR/systeminfo/mount 2>&1
cat /etc/fstab > $TMPDIR/systeminfo/fstab 2>&1
ps auxfww > $TMPDIR/systeminfo/ps-auxfww 2>&1
top d 5 n 4 b > $TMPDIR/systeminfo/top 2>&1
lsof -Pn > $TMPDIR/systeminfo/lsof-Pn 2>&1
if $(command -v sysctl >/dev/null 2>&1); then
  sysctl -a > $TMPDIR/systeminfo/sysctl-a 2>/dev/null
fi
uname -a > $TMPDIR/systeminfo/uname-a 2>&1
# OS: Ubuntu
if [ -f /etc/lsb-release ]; then
  cat /etc/lsb-release > $TMPDIR/systeminfo/lsb-release 2>&1
fi
if $(command -v ufw >/dev/null 2>&1); then
  ufw status > $TMPDIR/systeminfo/ubuntu-ufw-status 2>&1
fi
if $(command -v apparmor_status >/dev/null 2>&1); then
  apparmor_status > $TMPDIR/systeminfo/ubuntu-apparmor_status 2>&1
fi
# OS: RHEL
if [ -f /etc/redhat-release ]; then
  cat /etc/redhat-release > $TMPDIR/systeminfo/redhat-release 2>&1
  systemctl status NetworkManager > $TMPDIR/systeminfo/rhel-status-Networkmanager 2>&1
  systemctl status firewalld > $TMPDIR/systeminfo/rhel-status-firewalld 2>&1
  if $(command -v getenforce >/dev/null 2>&1); then
  getenforce > $TMPDIR/systeminfo/rhel-getenforce 2>&1
  fi
fi
echo " Done! "
echo


# Docker
echo " Shield Support: Collecting Docker Info ....."
mkdir -p $TMPDIR/docker
docker info > $TMPDIR/docker/docker-info 2>&1
docker ps -a > $TMPDIR/docker/docker-ps-a 2>&1
docker stats -a --no-stream > $TMPDIR/docker/docker-stats-a 2>&1
docker node ls > $TMPDIR/docker/docker-node-ls 2>&1
docker image ls -a > $TMPDIR/docker/docker-image-ls-a 2>&1
docker system df > $TMPDIR/docker/docker-system-df 2>&1
if [ -f /etc/docker/daemon.json ]; then
  cat /etc/docker/daemon.json > $TMPDIR/docker/etc-docker-daemon.json
fi
if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
  cat /etc/systemd/system/docker.service.d/http-proxy.conf > $TMPDIR/docker/http-proxy.conf
fi
echo " Done! "
echo

# Networking
echo " Shield Support: Collecting Networking Info ....."
mkdir -p $TMPDIR/networking
netstat -ano > $TMPDIR/networking/netstat-ano 2>&1
netstat -r > $TMPDIR/networking/netstat-r 2>&1
iptables-save > $TMPDIR/networking/iptablessave 2>&1
cat /proc/net/xfrm_stat > $TMPDIR/networking/procnetxfrmstat 2>&1
if $(command -v ip >/dev/null 2>&1); then
  ip addr show > $TMPDIR/networking/ipaddrshow 2>&1
  ip route > $TMPDIR/networking/iproute 2>&1
fi
if $(command -v ifconfig >/dev/null 2>&1); then
  ifconfig -a > $TMPDIR/networking/ifconfiga
fi
echo " Done! "
echo

# System logging
echo " Shield Support: Collecting System logging ....."
mkdir -p $TMPDIR/systemlogs
cp /var/log/syslog /var/log/messages /var/log/docker* /var/log/system-docker* $TMPDIR/systemlogs 2>/dev/null
echo " Done! "
echo

# Rancher logging
if [ $(docker ps |grep -c rancher) -ge 1 ]; then
   echo " Shield Support: Collecting Rancher Info ....."
   # Discover any server or agent running
   mkdir -p $TMPDIR/rancher/containerinspect
   mkdir -p $TMPDIR/rancher/containerlogs
   RANCHERSERVERS=$(docker ps -a | grep -E "rancher/rancher:|rancher/rancher " | awk '{ print $1 }')
   RANCHERAGENTS=$(docker ps -a | grep -E "rancher/rancher-agent:|rancher/rancher-agent " | awk '{ print $1 }')

   for RANCHERSERVER in $RANCHERSERVERS; do
     docker inspect $RANCHERSERVER > $TMPDIR/rancher/containerinspect/server-$RANCHERSERVER 2>&1
     docker logs -t $RANCHERSERVER > $TMPDIR/rancher/containerlogs/server-$RANCHERSERVER 2>&1
   done
   echo " Done! "
   echo
fi

# Shield
mkdir -p $TMPDIR/shield
echo " Shield Support: Collecting Shield Info ....."

# for k8s
if [ -f shield-setup.sh ];then 
    if which kubectl > /dev/null 2>&1 ; then
      kubectl get namespaces > $TMPDIR/shield/k8s-namespaces
      kubectl get nodes > $TMPDIR/shield/k8s-nodes
      kubectl get pods -o wide --all-namespaces > $TMPDIR/shield/k8s-pods
    fi

    if which helm > /dev/null 2>&1 ; then
      helm list > $TMPDIR/shield/k8s-helm-list
      helm repo list > $TMPDIR/shield/k8s-helm-repo-list
      helm search shield > $TMPDIR/shield/k8s-helm-search-sheild
    fi

    if [ -f custom-management.yaml ]; then
       LOCALBACKUPPATH=$(grep [^#]localPath custom-management.yaml | cut -d : -f 2)
       REMORTBACKUPPATH=$(grep [^#]remortPath custom-management.yaml | cut -d : -f 2)
       if [[ "${LOCALBACKUPPATH}" -eq "" ]]; then
            LOCALBACKUPPATH="/home/ericom/"
       fi
       cp -r ${LOCALBACKUPPATH}backup/  $TMPDIR/shield/ 2>/dev/null
       echo ${LOCALBACKUPPATH} > $TMPDIR/shield/k8s-backup-localPath
       echo ${REMORTBACKUPPATH} > $TMPDIR/shield/k8s-backup-remortPath
    fi
    cp -r ./logs/  $TMPDIR/shield/ 2>/dev/null
    cp ./*.log  $TMPDIR/shield/ 2>/dev/null
    cp ./*.yaml  $TMPDIR/shield/ 2>/dev/null
    cp ./.es*  $TMPDIR/shield/ 2>/dev/null
    cp ./.ra*  $TMPDIR/shield/ 2>/dev/null
    cp ./*.sh  $TMPDIR/shield/ 2>/dev/null
fi

# for swarm
if [ -d /usr/local/ericomshield/ ]; then
   /usr/local/ericomshield/status.sh -a >$TMPDIR/shield/swarm-status-a
   if [ "$?" -eq "0" ]; then
     /usr/local/ericomshield/status.sh -n >$TMPDIR/shield/swarm-status-n
     /usr/local/ericomshield/status.sh -s >$TMPDIR/shield/swarm-status-s
     /usr/local/ericomshield/status.sh -e >$TMPDIR/shield/swarm-status-e
   fi
   cp /usr/local/ericomshield/*.log  $TMPDIR/shield 2>/dev/null
   cp /usr/local/ericomshield/*.yml  $TMPDIR/shield 2>/dev/null
   cp /usr/local/ericomshield/*.txt  $TMPDIR/shield 2>/dev/null
   cp /usr/local/ericomshield/backup/*.json  $TMPDIR/shield 2>/dev/null
fi
echo " Done! "
echo

FILENAME="$(hostname)-$(date +'%Y-%m-%d_%H_%M_%S').tgz"
echo " Preparing the tar file: /tmp/$FILENAME "
tar czf /tmp/$FILENAME -C ${TMPDIR}/ .
rm -rf ${TMPDIR}
echo " Done! "
echo
echo "Created /tmp/${FILENAME}"

# all var log collect
VARLOGSIZE=$(du -sh /var/log/ --exclude='journal' --exclude="*.db" | awk '{print $1}')

if [[ y_flg -eq 0 ]]; then
    while :
    do
        echo ""
        echo -n "Do you want to collect logs under /var/log　(except journal) ? (The target log size is about ${VARLOGSIZE}.) [Y/n]:"
            read ANSWER
            case $ANSWER in
                "" | "Y" | "y" | "yse" | "Yes" | "YES" )
                    varlog_flg=1
                    break
                    ;;
                "n" | "N" | "no" | "No" | "NO" )
                    varlog_flg=0
                    break
                    ;;
                * )
                    echo "Please input Y or N "
                    ;;
            esac
    done
else
    varlog_flg=1
fi
if [[ varlog_flg -eq 1 ]];then
    echo " Preparing the tar file: /tmp/varlog_$FILENAME "
    tar czf /tmp/varlog_$FILENAME -C /var/log/ .
    echo " Done! "
    echo
    echo "Created /tmp/varlog_${FILENAME}"
fi

# report log collect
if [[ y_flg -eq 0 ]]; then
    while :
    do
        echo ""
        echo -n "Do you want to collect logs in the Report ? [Y/n]:"
            read ANSWER
            case $ANSWER in
                "" | "Y" | "y" | "yse" | "Yes" | "YES" )
                    getlog_flg=1
                    break
                    ;;
                "n" | "N" | "no" | "No" | "NO" )
                    getlog_flg=0
                    break
                    ;;
                * )
                    echo "Please input Y or N "
                    ;;
            esac
    done
else
    getlog_flg=1
fi
if [[ getlog_flg -eq 1 ]];then
    echo " Shield Support: Collecting Report logs ....."
    echo " >>> It takes a lot of time. Please wait patiently. ....."
    YESTERDAY=$(date --date "$(date +"%Y-%m-%d %H:%M:%S") +15:00" +%Y-%m-%d)
    TMPDIR=$(mktemp -d)
    mkdir -p $TMPDIR/getlogs
    curl -sOL ${SCRIPTS_URL}/sup/getlog.sh 
    chmod +x getlog.sh
    for L in allsystemstats applications connectioninfo connections errors feedback file-download file-preview file-sanitization file-transfer raw reports scalebrowser systemalert systemtest systemmsage
    do
        ./getlog.sh -L $L -O $TMPDIR/getlogs
        ./getlog.sh -L $L -D ${YESTERDAY} -O $TMPDIR/getlogs
    done
    echo " Preparing the tar file: /tmp/getlog_$FILENAME "
    tar czf /tmp/getlog_$FILENAME -C $TMPDIR/getlogs/ .
    rm -rf $TMPDIR
    echo " Done! "
    echo
    echo "Created /tmp/getlog_${FILENAME}"
fi

# finish
echo
echo "Please get these files"
echo
echo  "/tmp/${FILENAME} "
if [[ varlog_flg -eq 1 ]];then
    echo "/tmp/varlog_${FILENAME} "
fi
if [[ getlog_flg -eq 1 ]];then
    echo "/tmp/getlog_${FILENAME} "
fi
echo
echo "And send to Support Center."
echo