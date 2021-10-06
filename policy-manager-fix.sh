#!/bin/bash

####################
### K.K. Ashisuto
### VER=20211001a
####################

export HOME=$(eval echo ~${SUDO_USER})
export ES_PATH="$HOME/ericomshield"

LOGFILE="${ES_PATH}/logs/pm-fix.log"
FLGFILE="${ES_PATH}/.for_pm-fix_flg"

function log_message() {
    local PREV_RET_CODE=$?
    echo "$@"
    echo "$(LC_ALL=C date): $@" >>"$LOGFILE"
    if ((PREV_RET_CODE != 0)); then
        return 1
    fi
    return 0
}

if [ -f $FLGFILE ];then
    log_message "The flag file was detected."
    log_message "Waiting for workload."
    for i in 1 2 3 4 5 6
    do
        ${ES_PATH}/shield-status.sh -q
        if [[ $? -eq 0 ]]; then
            log_message "ALL workloads are Active."

            POLICY_MANAGER_PODS=$(/usr/local/bin/kubectl get pods --namespace=farm-services | grep policy | awk {'print $1'})

            log_message "Deliting Polocy manager pods."
            for POD in ${POLICY_MANAGER_PODS[@]};
            do
                /usr/local/bin/kubectl --namespace=farm-services delete pods $POD
            done
            log_message "All Policy Manager Pods Deleted."

            log_message "Waiting the new Policy Manager pods."
            while :
            do
                ${ES_PATH}/shield-status.sh -q
                if [[ $? -eq 0 ]]; then
                    log_message "ALL Done!"
                    rm -f $FLGFILE
                    break
                fi
                log_message "Waiting the new pods."
                sleep 10s
            done
            break
        else
            log_message "Not all workloads are Active. ${i}"
            sleep 10s
        fi
    done
else
    log_message "The flag file does not exist."    
fi
