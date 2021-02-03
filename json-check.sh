#!/bin/bash

####################
### K.K. Ashisuto
### VER=20210203b
####################

##### 変数 #####===================================================
BACKUP_DIR=/usr/local/ericomshield/backup
JSON_CHECK_DIR=${BACKUP_DIR}/json-check
MASTER_JSON=${JSON_CHECK_DIR}/master.json
ERROR_FILE=${JSON_CHECK_DIR}/error.txt
MASTER_TMP=${BACKUP_DIR}/json-check/master.tmp
BACKUP_TMP=${BACKUP_DIR}/json-check/backup.tmp
MASTER_JP_TMP=${BACKUP_DIR}/json-check/master-jp.tmp
BACKUP_JP_TMP=${BACKUP_DIR}/json-check/backup-jp.tmp
MASTER_UK_TMP=${BACKUP_DIR}/json-check/master-uk.tmp
BACKUP_UK_TMP=${BACKUP_DIR}/json-check/backup-uk.tmp
MASTER_US_TMP=${BACKUP_DIR}/json-check/master-us.tmp
BACKUP_US_TMP=${BACKUP_DIR}/json-check/backup-us.tmp
################===================================================

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 "
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit 1
fi

# install jq
if ! which jq > /dev/null 2>&1 ;then
    echo "installing jq."
    sudo apt-get update -qq
    sudo apt-get install -y jq
fi

if [ ! -f ${MASTER_JSON} ]; then
    echo "Error! No master.json "
    exit 1 
fi

rm -f ${ERROR_FILE}

all=($(docker ps | grep consul-server | awk {'print $1'}))

if [ ${#all[@]} -eq 0 ]; then
    echo "Please run this command on a management node"
    exit
fi
if [ ! -f json-check.py ];then
    curl -JOLsS ${SCRIPTS_URL}/json-check.py
fi
for container in ${all[@]}; do
    docker cp json-check.py  ${container}:/scripts/json-check.py
done
docker exec -t ${all[0]} python /scripts/json-check.py
sleep 10s

BACKUP_JSON=${BACKUP_DIR}/$(ls -1t ${BACKUP_DIR} | head -1)

jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not)) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${MASTER_TMP}
jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not)) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>\""; system("echo "$7" | base64 -d");printf "\"\n" }' > ${BACKUP_TMP}

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

