#!/bin/bash

####################
### K.K. Ashisuto
### VER=20240317a-dev
####################

export HOME=$(eval echo ~${SUDO_USER})
export KUBECONFIG=${HOME}/.kube/config

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi

BRANCH="Rel"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi

if [ -f .es_version ]; then
    S_APP_VERSION=$(cat .es_version)
    BUILD=()
    BUILD=(${S_APP_VERSION//./ })
    GBUILD=${BUILD[0]}.${BUILD[1]}
    if [[ ${BUILD[3]} ]] ;then
        BUILD=${BUILD[2]}.${BUILD[3]}
    else
        BUILD=${BUILD[2]}
    fi
fi

if [ -f .es_branch-tmp ]; then
    BRANCH=$(cat .es_branch-tmp)
elif [ -f ${ES_PATH}/.es_branch-tmp ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch-tmp)
fi

if [ -f .es_version-tmp ]; then
    S_APP_VERSION=$(cat .es_version-tmp)
    BUILD=()
    BUILD=(${S_APP_VERSION//./ })
    GBUILD=${BUILD[0]}.${BUILD[1]}
    if [[ ${BUILD[3]} ]] ;then
        BUILD=${BUILD[2]}.${BUILD[3]}
    else
        BUILD=${BUILD[2]}
    fi
fi

function usage() {
    echo "USAGE: $0 "
    exit 0
    ### for Develop only
    # [--system] [-q]
    # status list
    #  99 not start
    #  
    #  
    ##
}

rancher_ps_allactive_cnt=1
rancher_ps_str=""
system_flg=0
quiet_flg=0
args=""

for i in `seq 1 ${#}`
do
    if [ "$1" == "--system" ]; then
        system_flg=1
    elif [ "$1" == "--quiet" ] || [ "$1" == "-q" ] ; then
        quiet_flg=1
    elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
        usage
    else
        args="${args} ${1}"
    fi
    shift
done


function check_start_shield(){
    #Shieldが開始されているか確認して変数に格納。(0の場合は、Shield停止中)
    shield_deploy_str=`kubectl get namespaces` >/dev/null 2>&1
    shield_deploy_common=`echo "$shield_deploy_str" | grep -c -e common`
    shield_deploy_elk=`echo "$shield_deploy_str" | grep -c -e elk`
    shield_deploy_farmservices=`echo "$shield_deploy_str" | grep -c -e farm-services`
    shield_deploy_management=`echo "$shield_deploy_str" | grep -c -e management`
    shield_deploy_proxy=`echo "$shield_deploy_str" | grep -c -e proxy`

    #ステータス結果を表示
    if { [ "$shield_deploy_common" -eq 0 ] || [ "$shield_deploy_elk" -eq 0 ] || [ "$shield_deploy_farmservices" -eq 0 ] || [ "$shield_deploy_management" -eq 0 ] || [ "$shield_deploy_proxy" -eq 0 ]; } && [ "$system_flg" -eq 0 ]; then
        if [[ $quiet_flg -ne 1 ]]; then
            echo "----------------------------------------------------------"
            echo "Shield is Stopped."
            echo "To start Shield, run ~/ericomshield/shield-start.sh"
            echo
            if [ $shield_deploy_common == 0 ]; then echo "Not deploy common."; fi
            if [ $shield_deploy_elk == 0 ]; then echo "Not deploy elk."; fi
            if [ $shield_deploy_farmservices == 0 ]; then echo "Not deploy farm-services."; fi
            if [ $shield_deploy_management == 0 ]; then echo "Not deploy management."; fi
            if [ $shield_deploy_proxy == 0 ]; then echo "Not deploy proxy."; fi
            echo "----------------------------------------------------------"
            echo "exit."
            exit 99
        else
            exit 99
        fi
    fi
}

function check_start_system(){
    #systemが開始されているか確認して変数に格納。(0の場合は、system停止中)
    system_deploy_str=`kubectl get namespaces` >/dev/null 2>&1
    system_deploy_cattle=`echo "$system_deploy_str" | grep -c -e cattle-system`
    system_deploy_ingress=`echo "$system_deploy_str" | grep -c -e ingress-nginx`
    system_deploy_kube=`echo "$system_deploy_str" | grep -c -e kube-system`

    #ステータス結果を表示
    if { [ "$system_deploy_cattle" -eq 0 ] || [ "$system_deploy_ingress" -eq 0 ] || [ "$system_deploy_kube" -eq 0 ]; } && [ "$system_flg" -eq 0 ]; then
        if [[ $quiet_flg -ne 1 ]]; then
            echo "----------------------------------------------------------"
            echo "System is Stopped."
            echo
            if [ $system_deploy_cattle == 0 ]; then echo "Not deploy cattle-system."; fi
            if [ $system_deploy_ingress == 0 ]; then echo "Not deploy ingress-nginx."; fi
            if [ $system_deploy_kube == 0 ]; then echo "Not deploy kube-system."; fi
            echo "----------------------------------------------------------"
            echo "exit."
            exit 99
        else
            exit 99
        fi
    fi
}


function check_count(){
    rancher_ps_str=`rancher ps --project $(rancher projects | grep ${PROJECTNAME} | awk '{print $1}')`

    #activeステータス以外の数をカウントして変数に格納。
    rancher_ps_allactive_cnt=`echo "$rancher_ps_str" | awk '{print $4}' | grep -c -v -e active -e STATE -e succeeded`

}

function check_login(){
    #Rancher未ログインの場合、ログイン処理を行う。
    rancher_login_flg=`rancher ps | grep -c NAMESPACE` >/dev/null 2>&1
    if [ $rancher_login_flg == 0 ]; then
        rancher login --token $(cat ${ES_PATH}/.ra_apitoken) --skip-verify $(cat ${ES_PATH}/.ra_rancherurl) </dev/null >/dev/null 2>&1
    fi
}


function check_status(){
    if [[ $quiet_flg -ne 1 ]]; then
        echo "----------------------------------------------------------"
        echo "▼All Workload Status List▼"
        echo
        echo "$rancher_ps_str" | head -n 1; echo "$rancher_ps_str" | tail -n +2 | sort
        echo "----------------------------------------------------------"

        if [ $rancher_ps_allactive_cnt == 0 ]; then
            echo "All workloads are Active !"
            echo "----------------------------------------------------------"
            exit 0
        else
            echo "▼Not Active Workload List▼"
            echo
            echo "$rancher_ps_str" | head -n 1; echo "$rancher_ps_str" | tail -n +2 | sort | grep -v -e active -e succeeded
            echo "----------------------------------------------------------"
            echo "$rancher_ps_allactive_cnt workload are not Active."
            echo "----------------------------------------------------------"
            exit 10
        fi
    else
        if [ $rancher_ps_allactive_cnt == 0 ]; then
            exit 0
        else
            exit 10
        fi
    fi

}


######START#####

#read ra files
if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
    echo ".raファイルがありません。"
    exit 1
else
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
fi

check_login

if [[ system_flg -eq 1 ]];then
        PROJECTNAME="System"
else
    if [[ "$(echo "$BUILD < 5000" | bc)" -eq 1 ]]; then
        ####23.05まで#######################################
        PROJECTNAME="Default"
    else
        ####23.13以降#######################################
        PROJECTNAME="Shield"
    fi
fi


if [[ system_flg -eq 1 ]];then
    check_start_system
else
    check_start_system
    check_start_shield
fi
check_count
check_status

exit
