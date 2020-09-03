#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200821a
####################

export HOME=$(eval echo ~${SUDO_USER})
export KUBECONFIG=${HOME}/.kube/config

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi
if [ ! -e ${ES_PATH}/logs/ ];then
    mkdir -p ${ES_PATH}/logs
    mv -f ./*.log ${ES_PATH}/logs/ > /dev/null 2>&1
    mv -f ./logs/ ${ES_PATH}/logs/ > /dev/null 2>&1
fi

LOGFILE="${ES_PATH}/logs/stop-start.log"
BRANCH="master"
GITVER=1912
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR

#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/develop"
SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Kube/scripts"

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
fi
if [ -f .es_version ]; then
    GITVER=$(cat .es_version)
fi
if [ -f ${ES_PATH}/.es_offline ] ;then
    offline_flg=1
else
    offline_flg=0
fi

export BRANCH

old_flg=0
if [[ "$BRANCH" == "Rel-20.03" ]] || [[ "$BRANCH" == "Rel-20.01.2" ]] || [[ "$BRANCH" == "Rel-19.12.1" ]] || [[ "$BRANCH" == "Rel-19.11" ]] || [[ "$BRANCH" == "Rel-19.09.5" ]] || [[ "$BRANCH" == "Rel-19.09.1" ]]  || [[ "$BRANCH" == "Rel-19.07.1" ]] ;then
    old_flg=1
    SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts"
fi

#OS Check
if [ -f /etc/redhat-release ]; then
    OS="RHEL"
else
    OS="Ubuntu"
fi

function usage() {
    echo "USAGE: $0"
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

function stop_shield() {
    log_message "[start] Stop shield"

    if [[ $offline_flg -eq 0 ]] && [[ $old_flg -eq 1 ]];then
        curl -s -O ${SCRIPTS_URL_ES}/delete-shield.sh
        chmod +x delete-shield.sh
    fi
    if [[ $((1911 - ${GITVER:0:2}${GITVER:3:2})) -gt 0 ]];then
        sed -i -e '/Are you sure you want to delete the deployment/d' delete-shield.sh
        sed -i -e '/case/d' delete-shield.sh
        sed -i -e '/yes/d' delete-shield.sh
        sed -i -e 's/Uninstalling/Stopping/' delete-shield.sh
        sed -i -e '/;;/d' delete-shield.sh
        sed -i -e '/*)/d' delete-shield.sh
        sed -i -e '/no/d' delete-shield.sh
        sed -i -e '/Ok!/d' delete-shield.sh
        sed -i -e '/esac/d' delete-shield.sh
        sed -i -e '/helm delete --purge "common"/d' delete-shield.sh
        sed -i -e '/kubectl delete namespace "common"/d' delete-shield.sh
        sed -i -e '/helm delete --purge "shield-common"/d' delete-shield.sh
        sed -i -e '/kubectl delete namespace "shield-common"/d' delete-shield.sh
        ./delete-shield.sh | tee -a $LOGFILE
    else
        sed -i -e 's/Uninstalling/Stopping/' delete-shield.sh
        if [[ $((${GITVER:0:2}${GITVER:3:2} - 2007))  -ge 0 ]];then
            sed -i -e 's/helm delete "shield-${component}"/helm delete --namespace ${component} "shield-${component}"/' delete-shield.sh
        fi
        if [[ $(grep -c 'keep-namespace' delete-shield.sh) -gt 0 ]];then
            ./delete-shield.sh -s -k 2>>$LOGFILE | tee -a $LOGFILE
        else
            ./delete-shield.sh -s 2>>$LOGFILE | tee -a $LOGFILE
        fi
    fi

    if [[ $offline_flg -eq 0 ]] && [[ $old_flg -eq 1 ]];then
        curl -s -O ${SCRIPTS_URL_ES}/delete-shield.sh
    fi
    stop_abnormal_common
    kubectl delete jobs -n farm-services --all >> $LOGFILE
    log_message "[end] Stope shield"
}

function stop_abnormal_common() {
    if [ $(helm list | grep -c common) -ge 1 ];then
        RELEASE=$(helm list |grep common | awk '{print $1}')
        NAMESPRACE=$(helm list |grep common | awk '{print $11}')
        helm delete --purge "${RELEASE}"
        kubectl delete namespace "${NAMESPRACE}"
    fi
}


function log_message() {
    local PREV_RET_CODE=$?
    echo "$@"
    echo "$(LC_ALL=C date): $@" >>"$LOGFILE"
    if ((PREV_RET_CODE != 0)); then
        return 1
    fi
    return 0
}


function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}

function ln_resolv() {
    if [[ ! -L /etc/resolv.conf ]];then
        log_message "[start] Changing to the symbolic link."
        sudo mv -f /etc/resolv.conf /etc/resolv.conf_org
        sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
        if [[ $? -eq 0 ]];then
            log_message "[end] Changing to the symbolic link."
        else
            log_message "[WARNNING] Can NOT changined to the symbolic link !!!"
            while :
            do
            echo -n 'Do you want to continue? [y/N]:'
                read ANSWER
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
            done
        fi
    else
        if [[ $(ls -l /etc/resolv.conf | grep -c "/run/systemd/resolve") -eq 1 ]];then
            log_message "Already changed to the symbolic link."
        else
            log_message "[WARNNING] Already changed to the symbolic link. BUT But that is an unexpected PATH."
            while :
            do
            echo -n 'Do you want to continue? [y/N]:'
                read ANSWER
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
            done
        fi
    fi
}

log_message "###### START ###########################################################"

stop_shield
if [[ $OS == "Ubuntu" ]]; then
    ln_resolv
fi
fin 0


