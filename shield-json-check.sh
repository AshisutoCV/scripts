#!/bin/bash

####################
### K.K. Ashisuto
### VER=20210618a
####################

##### 変数 #####===================================================
BACKUP_DIR=/home/ericom/ericomshield/config-backup/backup
JSON_CHECK_DIR=${BACKUP_DIR}/json-check
MASTER_JSON=${JSON_CHECK_DIR}/master.json
ERROR_FILE=${JSON_CHECK_DIR}/error.txt
MASTER_TMP=${BACKUP_DIR}/json-check/master.tmp
MASTER_TMP2=${BACKUP_DIR}/json-check/master2.tmp
BACKUP_TMP=${BACKUP_DIR}/json-check/backup.tmp
BACKUP_TMP2=${BACKUP_DIR}/json-check/backup2.tmp
MASTER_JP_TMP=${BACKUP_DIR}/json-check/master-jp.tmp
BACKUP_JP_TMP=${BACKUP_DIR}/json-check/backup-jp.tmp
MASTER_UK_TMP=${BACKUP_DIR}/json-check/master-uk.tmp
BACKUP_UK_TMP=${BACKUP_DIR}/json-check/backup-uk.tmp
MASTER_US_TMP=${BACKUP_DIR}/json-check/master-us.tmp
BACKUP_US_TMP=${BACKUP_DIR}/json-check/backup-us.tmp
################===================================================


if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 "
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit 1
fi

if [ ! -f ${MASTER_JSON} ]; then
    echo "Error! No master.json "
    exit 1 
fi

rm -f ${ERROR_FILE}

CONSUL_BACKUP_POD=$(kubectl get pods --namespace=management | grep consul-backup | awk {'print $1'})
kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/backup.py > /dev/null 2>&1
sleep 10s

BACKUP_JSON=${BACKUP_DIR}/$(ls -1t ${BACKUP_DIR} | head -1)

jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not) and (.key | test("system-test")| not)) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${MASTER_TMP}

while read line
do
    line=${line//<<>>/,}
    key=$(cut -d ',' -f 1 <<<${line})
    value=$(cut -d ',' -f 2 <<<${line})
    value=$(echo ${value//'"'/} | base64 -d)
        echo "${key}<<>>${value}" >> ${MASTER_TMP2}
done < ${MASTER_TMP}

jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not) and (.key | test("system-test")| not)) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${BACKUP_TMP}

while read line
do
    line=${line//<<>>/,}
    key=$(cut -d ',' -f 1 <<<${line})
    value=$(cut -d ',' -f 2 <<<${line})
    value=$(echo ${value//'"'/} | base64 -d)
        echo "${key}<<>>${value}" >> ${BACKUP_TMP2}
done < ${BACKUP_TMP}

jq -c '.[] | select(.key | test("translations/ja-jp")) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${MASTER_JP_TMP}
jq -c '.[] | select(.key | test("translations/ja-jp")) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${BACKUP_JP_TMP}
jq -c '.[] | select(.key | test("translations/en-uk")) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${MASTER_UK_TMP}
jq -c '.[] | select(.key | test("translations/en-uk")) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${BACKUP_UK_TMP}
jq -c '.[] | select(.key | test("translations/en-us")) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${MASTER_US_TMP}
jq -c '.[] | select(.key | test("translations/en-us")) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $7 }' | sed -e 's/"//g' | base64 -d | sed -e "s/,/,\n/g" > ${BACKUP_US_TMP}


diff -q ${MASTER_TMP} ${BACKUP_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_TMP} ${BACKUP_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" > ${ERROR_FILE}
fi

diff -q ${MASTER_JP_TMP} ${BACKUP_JP_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_JP_TMP} ${BACKUP_JP_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

diff -q ${MASTER_UK_TMP} ${BACKUP_UK_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_UK_TMP} ${BACKUP_UK_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

diff -q ${MASTER_US_TMP} ${BACKUP_US_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_US_TMP} ${BACKUP_US_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

rm -f ${BACKUP_JSON}
rm -f ${JSON_CHECK_DIR}/*.tmp

