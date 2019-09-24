#!/bin/bash

####################
### K.K. Ashisuto
### VER=20190919b
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

function stop_shield() {
    log_message "[start] Stop shield"

    curl -s -o delete-shield.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/delete-shield.sh

    chmod +x delete-shield.sh
    sed -i -e '/Are you sure you want to delete the deployment/d' delete-shield.sh
    sed -i -e '/case/d' delete-shield.sh
    sed -i -e '/yes/d' delete-shield.sh
    sed -i -e 's/Uninstalling/Stopping/' delete-shield.sh
    sed -i -e '/;;/d' delete-shield.sh
    sed -i -e '/*)/d' delete-shield.sh
    sed -i -e '/no/d' delete-shield.sh
    sed -i -e '/Ok!/d' delete-shield.sh
    sed -i -e '/esac/d' delete-shield.sh
    sed -i -e 's/shield-common/common/g' delete-shield.sh
    sed -i -e '/helm delete --purge "shield-common"/d' delete-shield.sh
    sed -i -e '/kubectl delete namespace "shield-common"/d' delete-shield.sh
    sed -i -e '/helm delete --purge "common"/a \    helm delete --purge "shield-common"' delete-shield.sh
    sed -i -e '/kubectl delete namespace "common"/a \    kubectl delete namespace "shield-common"' delete-shield.sh

    ./delete-shield.sh | tee -a $LOGFILE

    curl -s -o delete-shield.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/delete-shield.sh

    log_message "[end] Stope shield"
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

log_message "###### START ###########################################################"

stop_shield
fin 0


