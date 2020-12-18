#!/bin/bash

####################
### K.K. Ashisuto
### VER=20201218a
####################


##### 変数 #####===================================================
BACKUP_DIR=/home/ericom/ericomshield/consul-backup/backup
MASTER_JSON=${BACKUP_DIR}/master.json
ERROR_FILE=./error.txt
################===================================================

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 "
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

rm -f ${ERROR_FILE}

CONSUL_BACKUP_POD=$(kubectl get pods --namespace=management | grep consul-backup | awk {'print $1'})
kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/backup.py > /dev/null 2>&1
sleep 3s

BACKUP_JSON=${BACKUP_DIR}/$(ls -1t ${BACKUP_DIR} | head -1)

jq -c '.[]  | select(.key | test("license_last_login")| not) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${BACKUP_DIR}/0-master.tmp
jq -c '.[]  | select(.key | test("license_last_login")| not) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${BACKUP_DIR}/0-backup.tmp

diff -q ${BACKUP_DIR}/0-master.tmp ${BACKUP_DIR}/0-backup.tmp 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${BACKUP_DIR}/0-master.tmp ${BACKUP_DIR}/0-backup.tmp 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" > ${ERROR_FILE}
fi

rm -f ${BACKUP_JSON}


