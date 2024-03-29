#!/bin/bash
############################################
#####   Ericom Shield Support          #####
#######################################BH###

####################
### K.K. Ashisuto
### VER=20200702a
####################

####-----------------
TTZ="Asia/Tokyo"    # getlog.sh利用のため
####-----------

#Check if we are root
if ((EUID != 0)); then
    #    sudo su
    echo " Please run it as Root"
    echo "sudo" $0
    exit
fi

export HOME=$(eval echo ~${SUDO_USER})
export KUBECONFIG=${HOME}/.kube/config

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH/sup
fi

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

usage() {
   echo "$0 [-y]"
   echo "    -y   : All logs are collected without confirmation."
}

CURRENT_DIR=$(cd $(dirname $0); pwd)

if [[ $CURRENT_DIR =~ sup  ]]; then
        cd $(dirname $(cd $(dirname $0); pwd))
else
    if [ ! -d /usr/local/ericomshield ];then
        cd $(dirname $(find /home/ -name shield-start.sh 2>/dev/null))
    fi
fi


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

# Exec Ericom shield-support.sh
    sudo $ES_PATH/shield-support.sh


echo '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
echo
echo "(KKA origin) Shield Support: Collecting Info and Logs from System and Shield ....."
echo

# Create temp directory
TMPDIR=$(mktemp -d)

# System info
echo " Shield Support: Collecting System Info ....."
mkdir -p $TMPDIR/systeminfo
env > $TMPDIR/systeminfo/env 2>&1
systemd-resolve --status > $TMPDIR/systeminfo/systemd-resolve 2>&1
cat /proc/buddyinfo > $TMPDIR/systeminfo/proc-buddyinfo 2>&1
cat /proc/meminfo > $TMPDIR/systeminfo/proc-meminfo 2>&1
cat /proc/cpuinfo > $TMPDIR/systeminfo/proc-cpuinfo 2>&1
df -hT > $TMPDIR/systeminfo/df-hT 2>&1
ps auxfww > $TMPDIR/systeminfo/ps-auxfww 2>&1
top d 5 n 4 b > $TMPDIR/systeminfo/top 2>&1
cat /etc/fstab > $TMPDIR/systeminfo/fstab 2>&1
uname -a > $TMPDIR/systeminfo/uname-a 2>&1

# OS: Ubuntu
if [ -f /etc/lsb-release ]; then
  cat /etc/lsb-release > $TMPDIR/systeminfo/lsb-release 2>&1
fi
# OS: RHEL
if [ -f /etc/redhat-release ]; then
  cat /etc/redhat-release > $TMPDIR/systeminfo/redhat-release 2>&1
fi
echo " Done! "
echo

# Docker
echo " Shield Support: Collecting Docker Info ....."
mkdir -p $TMPDIR/docker
docker node ls > $TMPDIR/docker/docker-node-ls 2>&1
docker image ls -a > $TMPDIR/docker/docker-image-ls-a 2>&1
docker system df > $TMPDIR/docker/docker-system-df 2>&1
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
echo " Done! "
echo

# System logging
echo " Shield Support: Collecting System logging ....."
mkdir -p $TMPDIR/systemlogs
cp /var/log/messages $TMPDIR/systemlogs 2>/dev/null
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

   for RANCHERAGENT in $RANCHERAGENTS; do
     docker inspect $RANCHERAGENT > $TMPDIR/rancher/containerinspect/agent-$RANCHERAGENT 2>&1
     docker logs -t $RANCHERAGENT > $TMPDIR/rancher/containerlogs/agent-$RANCHERSERANCHERAGENTRVER 2>&1
   done
   echo " Done! "
   echo
fi

# Shield
mkdir -p $TMPDIR/shield
echo " Shield Support: Collecting Shield Info ....."

# for k8s
if [ -f ${ES_PATH}/shield-start.sh ];then 

    if which helm > /dev/null 2>&1 ; then
      helm list > $TMPDIR/shield/k8s-helm-list
      helm repo list > $TMPDIR/shield/k8s-helm-repo-list
      helm search shield > $TMPDIR/shield/k8s-helm-search-sheild
    fi

    if [ -f custom-management.yaml ]; then
       LOCALBACKUPPATH=$(grep [^#]localPath custom-management.yaml | cut -d : -f 2)
       REMORTBACKUPPATH=$(grep [^#]remortPath custom-management.yaml | cut -d : -f 2)
       if [[ "${LOCALBACKUPPATH}" == "" ]]; then
            LOCALBACKUPPATH="/home/ericom/"
       fi
       cp -r ${LOCALBACKUPPATH}backup/  $TMPDIR/shield/ 2>/dev/null
       echo ${LOCALBACKUPPATH} > $TMPDIR/shield/k8s-backup-localPath
       echo ${REMORTBACKUPPATH} > $TMPDIR/shield/k8s-backup-remortPath
    fi
    cp -r ./ericomshield/  $TMPDIR/shield/ 2>/dev/null
    cp -r ./logs/  $TMPDIR/shield/ 2>/dev/null
    cp ./*.log  $TMPDIR/shield/ 2>/dev/null
    cp ./*.yaml  $TMPDIR/shield/ 2>/dev/null
    cp ./.es*  $TMPDIR/shield/ 2>/dev/null
    cp ./.ra*  $TMPDIR/shield/ 2>/dev/null
    cp ./*.sh  $TMPDIR/shield/ 2>/dev/null

    #/var/lib/docker/containers log
    mkdir -p $TMPDIR/varlibdokcer-logs
    for TARGET in `ls /var/lib/docker/containers`
    do
            NAME=$(cat /var/lib/docker/containers/${TARGET}/config.v2.json 2>/dev/null | jq .Name | sed -e s/\"//g | sed -e s"/\///")
            cp /var/lib/docker/containers/${TARGET}/${TARGET}-json.log $TMPDIR/varlibdokcer-logs/${NAME}-json.log 2>/devnull
    done
fi

FILENAME="$(hostname)-$(date +'%Y-%m-%d_%H_%M_%S')"
echo " Preparing the tar file: /tmp/kka_${FILENAME}.tar.gz "
tar -czf /tmp/kka_${FILENAME}.tar.gz -C ${TMPDIR}/ .
rm -rf ${TMPDIR}
echo " Done! "
echo
echo "Created /tmp/kka_${FILENAME}.tar.gz"

# all var log collect
VARLOGSIZE=$(du -sb /var/log/ --exclude='journal' --exclude="*.db" | awk '{print $1}')

# for swarm
if [ -d /usr/local/ericomshield/ ]; then
    VARLOGSIZE2=$(du -sb /var/lib/docker/containers/ | awk '{print $1}')
    VARLOGSIZE=$(($VARLOGSIZE+$VARLOGSIZE2))
fi

VARLOGSIZE=$(numfmt --to=iec $VARLOGSIZE)

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
    # for swarm
    if [ -d /usr/local/ericomshield/ ]; then
        echo " Collecting container logs. "    
        mkdir -p $TMPDIR/dockerlogs
        docker ps --format "{{.Names}}" | xargs -I {} bash -c "sudo docker logs {} > $TMPDIR/dockerlogs/{}.log 2>&1"
    fi
    echo " Preparing the tar file: /tmp/kka_varlog_${FILENAME}.tar.zg "
    tar --exclude='journal' -chf /tmp/kka_varlog_${FILENAME}.tar -C /var/log/ . --warning=no-file-changed --warning=no-file-removed --warning=no-file-shrank
    # for swarm
    if [ -d /usr/local/ericomshield/ ]; then
        tar -chf /tmp/kka_varlog_${FILENAME}.tar -C $TMPDIR dockerlogs --warning=no-file-changed --warning=no-file-removed --warning=no-file-shrank
    fi
    gzip /tmp/kka_varlog_${FILENAME}.tar
    rm -rf ${TMPDIR}
    echo " Done! "
    echo
    echo "Created /tmp/kka_varlog_${FILENAME}.tar.gz"
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
    YESTERDAY=$(env TZ=${TTZ} date --date "1 day ago" +%Y-%m-%d)
    TMPDIR=$(mktemp -d)
    mkdir -p $TMPDIR/getlogs

    cd $ES_PATH/sup
    if [ -f getlog.sh ];then
        if [ ! -f getlog.sh_backup ];then
            mv getlog.sh getlog.sh_backup
        fi
    fi
    curl -sOL ${SCRIPTS_URL}/sup/getlog.sh 
    chmod +x getlog.sh
    for L in connections applications file-sanitization file-transfer file-preview file-download systemusage systemalert systemtest errors feedback phishing reports allsystemstats connectioninfo scalebrowser raw
    do
        ./getlog.sh -L $L -O $TMPDIR/getlogs
        ./getlog.sh -L $L -D ${YESTERDAY} -O $TMPDIR/getlogs
    done
    if [ -f getlog.sh_backup ];then
            mv -f getlog.sh_backup getlog.sh
    fi
    echo " Preparing the tar file: /tmp/kka_getlog_${FILENAME}.tar.gz "
    tar czf /tmp/kka_getlog_${FILENAME}.tar.gz -C $TMPDIR/getlogs/ .
    rm -rf $TMPDIR
    echo " Done! "
    echo
    echo "Created /tmp/kka_getlog_${FILENAME}.tar.gz"
fi

# finish
echo
echo "Please get these files"
echo
echo  "/tmp/kka_${FILENAME}.tar.gz "
if [[ varlog_flg -eq 1 ]];then
    echo "/tmp/kka_varlog_${FILENAME}.tar.gz "
fi
if [[ getlog_flg -eq 1 ]];then
    echo "/tmp/kka_getlog_${FILENAME}.tar.gz "
fi
echo
echo "And send to Support Center."
echo