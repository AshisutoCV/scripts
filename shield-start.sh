#!/bin/bash

####################
### K.K. Ashisuto
### VER=20240317a-dev
####################

export HOME=$(eval echo ~${SUDO_USER})
export KUBECONFIG=${HOME}/.kube/config

ES_PATH="$HOME/ericomshield"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi
if [ ! -e ${ES_PATH}/logs/ ];then
    mkdir -p ${ES_PATH}/logs
    mv -f ./*.log ${ES_PATH}/logs/ > /dev/null 2>&1
    mv -f ./logs/ ${ES_PATH}/logs/ > /dev/null 2>&1
fi

LOGFILE="${ES_PATH}/logs/stop-start.log"
FLGFILE="${ES_PATH}/.for_pm-fix_flg"
CURRENT_DIR=$(cd $(dirname $0); pwd)
PARENT_DIR=$(dirname $(cd $(dirname $0); pwd))

cd $CURRENT_DIR

#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/develop"
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/feature/2315"
SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Kube/scripts"


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

BRANCH="master"
if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
fi
if [ -f ${ES_PATH}/.es_offline ] ;then
    offline_flg=1
else
    offline_flg=0
fi

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

deploy_flg=0
spell_flg=0
ses_limit_flg=1
elk_snap_flg=0
old_flg=0

export BRANCH

if [[ "$BRANCH" == "Rel-20.03" ]] || [[ "$BRANCH" == "Rel-20.01.2" ]] || [[ "$BRANCH" == "Rel-19.12.1" ]] || [[ "$BRANCH" == "Rel-19.11" ]] || [[ "$BRANCH" == "Rel-19.09.5" ]] || [[ "$BRANCH" == "Rel-19.09.1" ]]  || [[ "$BRANCH" == "Rel-19.07.1" ]] ;then
    old_flg=1
    SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts"
fi

function usage() {
    echo "USAGE: $0 [-f | --force-start]"
    echo "    -f       : SYSTEM系Podの起動ステータスを待たずに展開を開始します。"

    exit 0
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

function check_ha(){
    #dummy
    echo "" >/dev/null
}

function deploy_shield_old() {
    log_message "[start] deploy shield online"

    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/deploy-shield.sh
    chmod +x deploy-shield.sh

    if [[ $(grep -c ^ES_PATH deploy-shield.sh) -eq 0 ]];then
        sed -i -e '/###BH###/a ES_PATH="$HOME/ericomshield"' deploy-shield.sh 
    fi
    sed -i -e '/^VERSION_REPO/d' deploy-shield.sh
    sed -i -e '/^SET_LABELS=\"/s/yes/no/g' deploy-shield.sh
    sed -i -e '/^BRANCH=/d' deploy-shield.sh
    sed -i -e '/^helm search/d' deploy-shield.sh
    sed -i -e '/helm upgrade --install/s/SHIELD_REPO\/shield/SHIELD_REPO\/shield --version \${VERSION_REPO}/g' deploy-shield.sh
    sed -i -e '/helm upgrade --install/s/shield-repo\/shield/shield-repo\/shield --version \${VERSION_REPO}/g' deploy-shield.sh
    sed -i -e '/VERSION_DEPLOYED/s/\$9/\$10/g' deploy-shield.sh
    sed -i -e '/VERSION_DEPLOYED/s/helm list shield/helm list shield-management/g' deploy-shield.sh
    sed -i -e '/^LOGFILE/s/=.*last_deploy.log.*/="\${ES_PATH}\/logs\/last_deploy.log"/'  deploy-shield.sh
    sed -i -e '/^BRANCH=/s/BRANCH=/#BRANCH=/'  deploy-shield.sh
    sed -i -e 's/TZ=":/TZ="/g' deploy-shield.sh
    sed -i -e 's/s\/\\\/usr\\\/share\\\/zoneinfo/s\/.*\\\/usr\\\/share\\\/zoneinfo/' deploy-shield.sh
    sed -i -e "s/| tee -a/\>\>/g" deploy-shield.sh
    VERSION_REPO=$S_APP_VERSION
    export VERSION_REPO

    log_message "[start] deploieng shield"
    ./deploy-shield.sh | tee -a $LOGFILE
    log_message "[end] deploieng shield"

    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/deploy-shield.sh

    log_message "[end] deploy shield online"
}

function deploy_shield() {
    ### attention common setup&start ###
    log_message "[start] deploy shield"
    sed -i -e '/helm upgrade --install/s/SHIELD_REPO\/shield/SHIELD_REPO\/shield --version \${VERSION_REPO}/g' deploy-shield.sh
    sed -i -e '/^LAST_DEPLOY_LOGFILE/s/\$ES_PATH\/last_deploy.log/\$ES_PATH\/logs\/last_deploy.log/'  deploy-shield.sh
    sed -i -e '/^LOGFILE/s/\$ES_PATH\/ericomshield.log/\$ES_PATH\/logs\/ericomshield.log/'  deploy-shield.sh
    sed -i -e '/^BRANCH=/s/BRANCH=/#BRANCH=/'  deploy-shield.sh
    sed -i -e 's/TZ=":/TZ="/g' deploy-shield.sh
    sed -i -e "s/| tee -a/\>\>/g" deploy-shield.sh
    sed -i -e 's/^exit 0/#exit 0/g' deploy-shield.sh

    if [ $spell_flg -ne 1 ]; then
        sed -i -e 's/^#farm-services/farm-services/' custom-farm.yaml
        sed -i -e 's/^#.*DISABLE_SPELL_CHECK/  DISABLE_SPELL_CHECK/' custom-farm.yaml
    fi
    if [ $ses_limit_flg -ne 1 ]; then
        sed -i -e 's/^#shield-proxy/shield-proxy/' custom-proxy.yaml
        sed -i -e 's/^#.*checkSessionLimit/  checkSessionLimit/' custom-proxy.yaml
    fi
    if [ $elk_snap_flg -eq 1 ]; then
        sed -i -e '/#.*enableSnapshots/s/^.*#.*enableSnapshots/    enableSnapshots/g' custom-values-elk.yaml
    fi

    if [ $deploy_flg -eq 1 ]; then
        sed -i -e '/Up to date/{n;n;s/exit/\: #exit/}' deploy-shield.sh
    fi

    VERSION_REPO=$S_APP_VERSION
    export VERSION_REPO

    # check number of management and farm
    check_ha

    log_message "[start] deploieng shield"
    if [[ $stg_flg -eq 1 ]] || [[ $dev_flg -eq 1 ]];then
        ./deploy-shield.sh | tee -a $LOGFILE
    else
        ./deploy-shield.sh -L . | tee -a $LOGFILE
    fi
    log_message "[end] deploieng shield"

    log_message "[end] deploy shield"
}

function move_to_project() {
    ### attention common setup&start ###
    if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
        log_message ".raファイルがありません。"
        failed_to_install "move_to_project" "all"
    fi
    if [[ "$(echo "$BUILD < 5000" | bc)" -eq 1 ]]; then
        PROJECTNAME="Default"
    else
        PROJECTNAME="Shield"
    fi

    log_message "[start] get ${PROJECTNAME} project id"
    TOPROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=${PROJECTNAME}" \
        -H 'Accept: application/json' \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -r '.data[].id')
    log_message "TOPROJECTID: $TOPROJECTID"
    log_message "[end] get ${PROJECTNAME} project id"

    # move namespases to Target project
    log_message "[start] Move namespases to ${PROJECTNAME} project"

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
                "projectId":"'$TOPROJECTID'"
              }' \
           >>"$LOGFILE" 2>&1

        log_message "move namespases to ${PROJECTNAME} project/ ${NAMESPACE} "
    done

    log_message "[end] Move namespases to ${PROJECTNAME} project"
}

function check_start() {
    ### attention common setup&start ###
    log_message "[start] Waiting All namespaces are Deploied"
    for i in 1 2 3 4
    do
        ./shield-status.sh -q
        export nRET${i}=$?
        if [[ ${i} -eq 4 ]] && [[ nRET${i} -eq 99 ]];then
                echo ""
                echo "【※確認※】 展開に失敗しました。 ${ES_PATH}/shield-start.sh 実行し、"            
                echo "          全てのワークロードが 展開されることをご確認ください。"
            failed_to_install "deploy namespaces"
        fi
        if [[ nRET${i} -eq 99 ]];then
            log_message "[re-start] Start ReDeploy. ${i}"
            deploy_shield
            move_to_project
            continue
        else
            break
        fi
    done
    log_message "[end] Waiting All namespaces are Deploied"

    if [[ ! -z $BR_REQ_MEM ]] || [[ ! -z $BR_REQ_CPU ]] || [[ ! -z $BR_LIMIT_MEM ]] || [[ ! -z $BR_LIMIT_CPU ]];then
        if [ -z $BR_REQ_MEM ]; then BR_REQ_MEM="200Mi"; fi
        if [ -z $BR_REQ_CPU ]; then BR_REQ_CPU="200m"; fi
        if [ -z $BR_LIMIT_MEM ]; then BR_LIMIT_MEM="1280Mi"; fi
        if [ -z $BR_LIMIT_CPU ]; then BR_LIMIT_CPU="1"; fi
        echo "///// resources /////////////////////" >> $LOGFILE
        echo "BR_REQ_MEM: $BR_REQ_MEM" >> $LOGFILE
        echo "BR_REQ_CPU: $BR_REQ_CPU" >> $LOGFILE
        echo "BR_LIMIT_MEM: $BR_LIMIT_MEM" >> $LOGFILE
        echo "BR_LIMIT_CPU: $BR_LIMIT_CPU" >> $LOGFILE
        echo "///// resources /////////////////////" >> $LOGFILE
        change_resource
    fi

    echo ""
    echo "【※確認※】 Rancher UI　${RANCHERURL} をブラウザで開くか、"
    echo "          ${ES_PATH}/shield-status.sh 実行し、"
    echo "          全てのワークロードが Acriveになることをご確認ください。"
    echo ""

    date > $FLGFILE
}

function change_resource() {
    ### attention common setup&start ###
    log_message "[start] change remort browser resource"
    kubectl get cm -n farm-services shield-farm-services-remote-browser-spec -o yaml > remote-browser-spec.yaml
    cp -f remote-browser-spec.yaml remote-browser-spec.yaml_bak
    cat remote-browser-spec.yaml | sed -e '/^    .*/'d | sed -e '/^data:/d' | sed -e '/^  remote-browser-spec.json.*/d' > remote-browser-spec.yaml_tmp1
    kubectl get cm -n farm-services shield-farm-services-remote-browser-spec -o json |jq -r '.data."remote-browser-spec.json" | . ' | \
      jq -r ".spec.template.spec.containers[].resources.requests.memory|=\"$BR_REQ_MEM\"" | \
      jq -r ".spec.template.spec.containers[].resources.requests.cpu|=\"$BR_REQ_CPU\"" | \
      jq -r ".spec.template.spec.containers[].resources.limits.memory|=\"$BR_LIMIT_MEM\"" | \
      jq -r ".spec.template.spec.containers[].resources.limits.cpu|=\"$BR_LIMIT_CPU\"" | \
    sed -e s'/"/\\"/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' > remote-browser-spec.yaml_tmp2
    cat <(echo -n '"') remote-browser-spec.yaml_tmp2  <(echo -n '"') > remote-browser-spec.yaml_tmp3
    cat remote-browser-spec.yaml_tmp1 <(echo data:) <(echo -n "  remote-browser-spec.json: ") remote-browser-spec.yaml_tmp3 > remote-browser-spec.yaml
    rm -f remote-browser-spec.yaml_tmp*
    kubectl replace -f remote-browser-spec.yaml
    kubectl delete jobs -n farm-services --all
    log_message "[end] change remort browser resource"
}


log_message "###### START ###########################################################"

#check_args
    #namespace_flg=0
    force_flg=0
    args=""

    echo "args: $1" >> $LOGFILE

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--force-start" ] || [ "$1" == "-f" ]; then
            force_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
#        elif [ "$1" == "--namespace" ] || [ "$1" == "-n" ] ; then
#            shift
#            $TARGET_NAME="$1"
#            namespace_flg=1
        else
            args="${args} ${1}"
        fi
        shift
    done

    if [ ! -z ${args} ]; then
        log_message "${args} は不正な引数です。"
        usage
        fin 1
    fi

    echo "///// args /////////////////////" >> $LOGFILE
    echo "force_flg: $force_flg" >> $LOGFILE
    echo "args: $args" >> $LOGFILE
    echo "////////////////////////////////" >> $LOGFILE

#read ra files
if [ -f .ra_rancherurl ] && [ -f .ra_clusterid ] && [ -f .ra_apitoken ];then
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
else
    failed_to_start "read ra files"
fi

#read custom_env file
if [ -f ${CURRENT_DIR}/.es_custom_env ] ; then
    BR_REQ_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_mem | awk -F'[: ]' '{print $NF}')
    BR_REQ_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_cpu | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_mem | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_cpu | awk -F'[: ]' '{print $NF}')
elif [ -f ${PARENT_DIR}/.es_custom_env ];then
    BR_REQ_MEM=$(cat ${PARENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_mem | awk -F'[: ]' '{print $NF}')
    BR_REQ_CPU=$(cat ${PARENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_cpu | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_MEM=$(cat ${PARENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_mem | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_CPU=$(cat ${PARENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_cpu | awk -F'[: ]' '{print $NF}')
fi

S_APP_VERSION=$(cat .es_version)

log_message "[start] Waiting System Project is Actived"
j=0

if [[ $force_flg -eq 1 ]];then
    n=10
else
    n=999
fi
while [ $j -ne $n ]
do
    j=`expr 1 + $j`
    for i in 1 2 3 
    do
        ./shield-status.sh --system -q
        export RET${i}=$?
    done
    if [[ RET1 -eq 0 ]] && [[ RET2 -eq 0 ]] && [[ RET3 -eq 0 ]]; then
        break
    fi
done
echo "n: $n" >> $LOGFILE
echo "j: $j" >> $LOGFILE
if [[ $j -eq $n ]];then
    log_message "[end] Waiting System Project BUT all pods is NOT Actived"
    if [[ $force_flg -ne 1 ]];then
        fin 9
    fi
else
    log_message "[end] Waiting System Project is Actived"
fi

log_message "[start] Start Shield"
if [[ $old_flg -eq 1 ]];then
    deploy_shield_old
else
    deploy_shield
fi
move_to_project
check_start

fin 0
