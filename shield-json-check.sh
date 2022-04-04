#!/bin/bash

####################
### K.K. Ashisuto
### VER=20220405a
####################

##### 変数 #####===================================================
BACKUP_DIR=/home/ericom/ericomshield/config-backup/backup
BACKUP_DIR_b=/home/ericom/ericomshield/consul-backup/backup

if [[ ! -d $BACKUP_DIR ]];then
    if [[ -d $BACKUP_DIR_b ]];then
        BACKUP_DIR=$BACKUP_DIR_b
    else
        echo "BACKUP_DIR の存在が確認できません。"
        exit 9
    fi
fi

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
#CM_IP="192.168.1.1"
#SETUP_USER="ubuntu"
#USER_PASS=""
################===================================================

# SSH_ASKPASSで設定したプログラム(本ファイル自身)が返す内容
if [ -n "$PASSWORD" ]; then
  cat <<< "$PASSWORD"
  exit 0
fi

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

if [[ $(ps -ef | grep -v grep | grep -c kube-apiserver) -eq 1 ]] ; then
    CONSUL_BACKUP_POD=$(kubectl get pods --namespace=management | grep consul-backup | awk {'print $1'})
    kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/backup.py > /dev/null 2>&1
    sleep 10s
else
    if [[ -z $CM_IP ]];then
        echo -n "CMノードのIPアドレスを入力: "
        read CM_IP
        echo ""
    fi
    if [[ -z $SETUP_USER ]];then
        echo -n "CMノードセットアップユーザ のユーザ名を入力: "
        read SETUP_USER
        echo ""
    fi
    if [[ -z $USER_PASS ]];then
        while :
        do
            echo -n "リモートユーザ $SETUP_USER のパスワードを入力: "
            read -s USER_PASS
            echo ""
            echo -n '(確認)再度入力してください。: '
            read -s USER_PASS2
            echo ""
            if [[ "${USER_PASS}" != "${USER_PASS2}" ]];then
                echo "入力が一致しません。再度入力してください。"
            else
                break
            fi
        done
    fi

    # SSH_ASKPASSで呼ばれるシェルにパスワードを渡すために変数を設定
    export PASSWORD=$USER_PASS

    # SSH_ASKPASSに本ファイルを設定
    export SSH_ASKPASS=$0
    # ダミーを設定
    export DISPLAY=dummy:0
    CONSUL_BACKUP_POD=$(exec setsid ssh -t -oStrictHostKeyChecking=no $SETUP_USER@$CM_IP 'kubectl get pods --namespace=management | grep consul-backup | cut -f1 -d" "')
    CONSUL_BACKUP_POD=`echo ${CONSUL_BACKUP_POD} | sed -e "s/[\r\n]\+//g"`
    RET=$(exec setsid ssh -t -oStrictHostKeyChecking=no $SETUP_USER@$CM_IP "kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/backup.py > /dev/null 2>&1")
    sleep 10
fi

BACKUP_JSON=${BACKUP_DIR}/$(ls -1t ${BACKUP_DIR} | grep backup | head -1)

jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not) and (.key | test("system-test")| not) and (.key | test("prefetch-codec-support-list")| not)) ' ${MASTER_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>" $7 "\n" }' > ${MASTER_TMP}

while read line
do
    line=${line//<<>>/,}
    key=$(cut -d ',' -f 1 <<<${line})
    value=$(cut -d ',' -f 2 <<<${line})
    value=$(echo ${value//'"'/} | base64 -d)
        echo "${key}<<>>${value}" >> ${MASTER_TMP2}
done < ${MASTER_TMP}

jq -c '.[]  | select((.key | test("license_last_login")| not) and (.key | test("ldap_cache_lastUpdate")| not) and (.key | test("last-restore")| not) and (.key | test("users_info")| not) and (.key | test("system-test")| not) and (.key | test("prefetch-codec-support-list")| not)) ' ${BACKUP_JSON} | awk -F'[{:,}]' '{ printf $3 "<<>>" $7 "\n" }' > ${BACKUP_TMP}

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


RESULT=0
diff -q ${MASTER_TMP2} ${BACKUP_TMP2} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_TMP2} ${BACKUP_TMP2} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" > ${ERROR_FILE}
fi

RESULT=0
diff -q ${MASTER_JP_TMP} ${BACKUP_JP_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_JP_TMP} ${BACKUP_JP_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

RESULT=0
diff -q ${MASTER_UK_TMP} ${BACKUP_UK_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_UK_TMP} ${BACKUP_UK_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

RESULT=0
diff -q ${MASTER_US_TMP} ${BACKUP_US_TMP} 2>&1 > /dev/null || {
    RESULT=$? 
    OUTPUT=$(diff ${MASTER_US_TMP} ${BACKUP_US_TMP} 2>&1)
}

if [ "$RESULT" = "1" ]; then
    echo "$OUTPUT" >> ${ERROR_FILE}
fi

rm -f ${BACKUP_JSON}
rm -f ${JSON_CHECK_DIR}/*.tmp

