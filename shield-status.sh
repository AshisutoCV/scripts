#!/bin/bash

####################
### K.K. Ashisuto
### VER=20240228a-dev
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

function usage() {
    echo "USAGE: $0 "
    exit 0
    ### for Develop only
    # [--system] [-q]
    ##
}

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

if [[ "$(echo "$BUILD < 5000" | bc)" -eq 1 ]]; then
    ####23.05まで###############################################################
    if [[ system_flg -ne 1 ]];then
        PROJECTNAME="Default"
        if [ "$BRANCH" == "Rel-19.07" ] || [ "$BRANCH" == "Rel-19.07.1" ];then
            NAMESPACES="management proxy elk farm-services"
        else
            NAMESPACES="management proxy elk farm-services common"
        fi
    else
        PROJECTNAME="System"
        NAMESPACES="cattle-system ingress-nginx kube-system"
    fi
    PROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=${PROJECTNAME}" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -r '.data[].id')



    WORKLOADS=()
    #ERR_NSs=()
    for NAMESPACE in $NAMESPACES
    do
        WORKLOADS+=($(curl -s -k "${RANCHERURL}/v3/cluster/${CLUSTERID}/namespaces/${NAMESPACE}/yaml" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            | jq -c ' .items[] | [ .kind, .metadata.namespace,.metadata.name ]' 2> /dev/null | grep -v Service | grep -v ConfigMap)) || {
            if [[ $quiet_flg -ne 1 ]]; then
                echo "Not deploy ${NAMESPACE}."
            fi
            ERR_FLG=1
            #ERR_NSs+="$NAMESPACE"
        }
    done

    if [[ $ERR_FLG -eq 1 ]];then
        if [[ $quiet_flg -ne 1 ]]; then
            echo "exit."
        fi
        exit 99
    fi

    STATELIST=()
    for WORKLOAD in "${WORKLOADS[@]}"
    do
            KIND=$(echo $WORKLOAD | jq -c .[0] | sed -e s/\"//g)
            SPACE=$(echo $WORKLOAD | jq -c .[1] | sed -e s/\"//g)
            NAME=$(echo $WORKLOAD | jq -c .[2] | sed -e s/\"//g)
            STATELIST+=($(curl -s -k "${RANCHERURL}/v3/project/${PROJECTID}/workloads/${KIND,,}:${SPACE,,}:${NAME,,}" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            | jq -c '[ .namespaceId, .name, .state ] '))
    done
else
####23.13以降###############################################################
    if [[ system_flg -ne 1 ]];then
        PROJECTNAME="Shield"
        #NAMESPACES="management proxy elk farm-services common"
    else
        PROJECTNAME="System"
        #NAMESPACES="cattle-system ingress-nginx kube-system"
    fi
    PROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=${PROJECTNAME}" \
        -H 'Accept: application/json' \
        -H 'Content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -c '.data[].id' | grep -v local |sed 's/"//g' )


    WORKLOADS=()
    #ERR_NSs=()
    #for NAMESPACE in $NAMESPACES
    #do
        WORKLOADS+=($(curl -s -k "${RANCHERURL}/v3/project/${PROJECTID}/workloads" \
            -H 'Accept: application/json' \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            | jq -c ' .data[].id' | sed 's/"//g')) || {
            if [[ $quiet_flg -ne 1 ]]; then
                echo "Not deploy ${NAMESPACE}."
            fi
            ERR_FLG=1
            #ERR_NSs+="$NAMESPACE"
        }
    #done

    if [[ $ERR_FLG -eq 1 ]];then
        if [[ $quiet_flg -ne 1 ]]; then
            echo "exit."
        fi
        exit 99
    fi

    STATELIST=()
    for WORKLOAD in "${WORKLOADS[@]}"
    do
            STATELIST+=($(curl -s -k "${RANCHERURL}/v3/project/${PROJECTID}/workloads/${WORKLOAD}" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            | jq -c '[ .namespaceId, .name, .state ] '))
    done
fi

if [[ $quiet_flg -ne 1 ]]; then
    echo "${STATELIST[@]}" | jq -c . | grep -w "active"
    echo ""
fi
NONACTIVE=$(echo "${STATELIST[@]}" | jq -c . |  grep -c -w -v "active")

if [ $NONACTIVE -eq 0 ]; then
    if [[ $quiet_flg -ne 1 ]]; then
        echo "All workloads are Active !"
    fi
        exit 0
else
    if [[ $quiet_flg -ne 1 ]]; then
        echo "----------------------------------------------------------"
        echo "${STATELIST[@]}" | jq -c . |  grep -w -v "active"
        echo "----------------------------------------------------------"
        echo "$NONACTIVE workload are not Active."
        echo "----------------------------------------------------------"
    fi
    exit 10
fi
