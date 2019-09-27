#!/bin/bash

####################
### K.K. Ashisuto
### VER=20190926-dev
####################

LOGFILE="stop-start.log"
BRANCH="Staging"
if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
fi

export BRANCH

function usage() {
    echo "USAGE: $0"
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

function deploy_shield() {
    log_message "[start] deploy shield"

    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/deploy-shield.sh
    chmod +x deploy-shield.sh

    sed -i -e '/^VERSION_REPO/d' deploy-shield.sh
    sed -i -e '/^SET_LABELS=\"/s/yes/no/g' deploy-shield.sh
    sed -i -e '/^BRANCH=/d' deploy-shield.sh
    sed -i -e '/^helm search/d' deploy-shield.sh
    sed -i -e '/helm upgrade --install/s/SHIELD_REPO\/shield/SHIELD_REPO\/shield --version \${VERSION_REPO}/g' deploy-shield.sh
    sed -i -e '/helm upgrade --install/s/shield-repo\/shield/shield-repo\/shield --version \${VERSION_REPO}/g' deploy-shield.sh
    sed -i -e '/VERSION_DEPLOYED/s/\$9/\$10/g' deploy-shield.sh
    sed -i -e '/VERSION_DEPLOYED/s/helm list shield/helm list shield-management/g' deploy-shield.sh
    #sed -i -e '/curl.*yaml/d' deploy-shield.sh

    VERSION_REPO=$S_APP_VERSION
    export VERSION_REPO

    log_message "[start] deploieng shield"
    ./deploy-shield.sh | tee -a $LOGFILE
    log_message "[end] deploieng shield"

    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/deploy-shield.sh

    log_message "[end] deploy shield"
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

function failed_to_start() {
    log_message "An error occurred during the shield starting: $1, exiting"
    fin 1
}

function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}


function move_to_project() {
    if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
        log_message ".raファイルがありません。"
        failed_to_install "move_to_project" "all"
    fi
    log_message "[start] get Default project id"
    DEFPROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=Default" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -r '.data[].id')
    log_message "DEFPROJECTID: $DEFPROJECTID"
    log_message "[end] get Default project id"

    # move namespases to Default project
    log_message "[start] Move namespases to Default project"


    if [ "$BRANCH" == "Rel-19.07" ] || [ "$BRANCH" == "Rel-19.07.1" ];then
        NAMESPACES="management proxy elk farm-services"
    else
        NAMESPACES="management proxy elk farm-services common"
    fi

    for NAMESPACE in $NAMESPACES
    do
        curl -s -k "${RANCHERURL}/v3/cluster/${CLUSTERID}/namespaces/${NAMESPACE}?action=move" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            --data-binary '{
                "projectId":"'$DEFPROJECTID'"
              }' \
           >>"$LOGFILE" 2>&1

        log_message "move namespases to Default project/ ${NAMESPACE} "
    done

    log_message "[end] Move namespases to Default project"
}




log_message "###### START ###########################################################"

#read ra files
if [ -f .ra_rancherurl ] && [ -f .ra_clusterid ] && [ -f .ra_apitoken ];then
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
else
    failed_to_start "read ra files"
fi


S_APP_VERSION=$(cat .es_version)

log_message "[start] Start Shield"

deploy_shield
move_to_project

log_message "[end] Start Shield"

fin 0


