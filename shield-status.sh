#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200116a
####################

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi
if [ ! -e ${ES_PATH}/logs/ ];then
    mkdir -p ${ES_PATH}/logs
    mv -f ./*.log ${ES_PATH}/logs/ > /dev/null 2>&1
    mv -f ./logs/ ${ES_PATH}/logs/ > /dev/null 2>&1
fi


LOGFILE="${ES_PATH}/logs/status.log"
BRANCH="Rel"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi


function usage() {
    echo "USAGE: $0 "
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

function change_dir(){
    BUILD=()
    BUILD=(${S_APP_VERSION//./ })
    CHKBRANCH=${BUILD[0]}${BUILD[1]}
    if [[ $CHKBRANCH -lt 1911 ]];then
        log_message "pwd: $(pwd)"
    else
        log_message "[start] change dir"
        log_message "pwd: $(pwd)"
        cd ${ES_PATH}
        log_message "pwd: $(pwd)"
        log_message "[end] change dir"
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




######START#####

#read ra files
if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
    log_message ".raファイルがありません。"
    fin 1
else
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
fi

DEFPROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=Default" \
    -H 'content-type: application/json' \
    -H "Authorization: Bearer $APITOKEN" \
    | jq -r '.data[].id')

if [ "$BRANCH" == "Rel-19.07" ] || [ "$BRANCH" == "Rel-19.07.1" ];then
    NAMESPACES="management proxy elk farm-services"
else
    NAMESPACES="management proxy elk farm-services common"
fi

WORKLOADS=()
for NAMESPACE in $NAMESPACES
do
    WORKLOADS+=($(curl -s -k "${RANCHERURL}/v3/cluster/${CLUSTERID}/namespaces/${NAMESPACE}/yaml" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -c ' .items[] | [ .kind, .metadata.namespace,.metadata.name ]' | grep -v Service | grep -v ConfigMap))
done

#echo $WORKLOADS

STATELIST=()
for WORKLOAD in "${WORKLOADS[@]}"
do
        KIND=$(echo $WORKLOAD | jq -c .[0] | sed -e s/\"//g)
        SPACE=$(echo $WORKLOAD | jq -c .[1] | sed -e s/\"//g)
        NAME=$(echo $WORKLOAD | jq -c .[2] | sed -e s/\"//g)
        STATELIST+=($(curl -s -k "${RANCHERURL}/v3/project/${DEFPROJECTID}/workloads/${KIND,,}:${SPACE,,}:${NAME,,}" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -c '[ .namespaceId, .name, .state ] '))
done

echo "${STATELIST[@]}" | jq -c
NONACTIVE=$(echo "${STATELIST[@]}" | jq -c . |  grep -c -v "active")

echo ""
if [ $NONACTIVE -eq 0 ]; then
        echo "All workloads are Active !"
else
        echo "$NONACTIVE workload are not Active."
fi
