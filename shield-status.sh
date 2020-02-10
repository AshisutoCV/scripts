#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200210a
####################

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi

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
        | jq -c ' .items[] | [ .kind, .metadata.namespace,.metadata.name ]' | grep -v Service | grep -v ConfigMap)) || {
        echo "Not deploy ${NAMESPACE}."
        ERR_FLG=1
    }
done

if [[ $ERR_FLG -eq 1 ]];then
    echo "exit."
    exit 1
fi

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

echo "${STATELIST[@]}" | jq -c . | grep "active"
NONACTIVE=$(echo "${STATELIST[@]}" | jq -c . |  grep -c -v "active")

echo ""
if [ $NONACTIVE -eq 0 ]; then
        echo "All workloads are Active !"
else
        echo "----------------------------------------------------------"
        echo "${STATELIST[@]}" | jq -c . |  grep -v "active"
        echo "----------------------------------------------------------"
        echo "$NONACTIVE workload are not Active."
        echo "----------------------------------------------------------"
fi
