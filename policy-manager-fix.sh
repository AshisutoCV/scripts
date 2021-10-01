#!/bin/bash

####################
### K.K. Ashisuto
### VER=20211001a
####################

export HOME=$(eval echo ~${SUDO_USER})
export ES_PATH="$HOME/ericomshield"

echo "Waiting for workload."
while :
do
    ${ES_PATH}/shield-status.sh -q
    if [[ $? -eq 0 ]]; then
        echo "Complete."
        break
    fi
    echo "Waiting..."
    sleep 10s
done


POLICY_MANAGER_PODS=$(kubectl get pods --namespace=farm-services | grep policy | awk {'print $1'})


echo "Deliting Polocy manager pods."
for POD in ${POLICY_MANAGER_PODS[@]};
do
    kubectl --namespace=farm-services delete pods $POD
done
echo "Done."


echo "Waiting new Policy Manager pods."
while :
do
    ${ES_PATH}/shield-status.sh -q
    if [[ $? -eq 0 ]]; then
        echo "ALL Done!"
        break
    fi
    echo "Waiting..."
    sleep 10s
done