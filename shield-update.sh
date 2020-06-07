#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200607a-dev
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

elk_snap_flg=0
LOGFILE="${ES_PATH}/logs/update.log"
BRANCH="Rel"
ERICOMPASS="Ericom123$"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR
#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/feature/re-new_setup"
SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Kube/scripts"

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi

function usage() {
    echo "USAGE: $0 [--pre-use]"
    exit 0
    ### for Develop only
    # [--staging | --dev] [--pre-use]
    ##
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

if [ -f ${ES_PATH}/.es_offline ] ;then
    offline_flg=1
    REGISTRY_OVA=$(cat ${ES_PATH}/.es_offline)
    REGISTRY_OVA_DOCKER=$(docker info 2>/dev/null | grep :5000 | cut -d' ' -f3)
    if [ "$REGISTRY_OVA" != "$REGISTRY_OVA_DOCKER" ];then
        REGISTRY_OVA=$REGISTRY_OVA_DOCKER
        echo "$REGISTRY_OVA" > ${ES_PATH}/.es_offline
    fi
    REGISTRY_OVA_IP=${REGISTRY_OVA%%:*}
    REGISTRY_OVA_PORT=${REGISTRY_OVA##*:}
    SCRIPTS_URL_ES="http://$REGISTRY_OVA_IP/ericomshield"
    SCRIPTS_URL="http://$REGISTRY_OVA_IP/scripts"
    export ES_OFFLINE_REGISTRY="$REGISTRY_OVA"
else
    offline_flg=0
fi

function check_args(){
    pre_flg=0
    args=""
    dev_flg=0
    stg_flg=0
    ver_flg=0
    S_APP_VERSION=""

    echo "args: $1" >> $LOGFILE

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--pre-use" ]; then
            pre_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
        elif [ "$1" == "--dev" ] || [ "$1" == "--Dev" ] ; then
            dev_flg=1
        elif [ "$1" == "--staging" ] || [ "$1" == "--Staging" ] ; then
            stg_flg=1
        elif [ "$1" == "-v" ] || [ "$1" == "--version" ] || [ "$1" == "--Version" ]; then
            shift
            S_APP_VERSION="$1"
            ver_flg=1
        else
            args="${args} ${1}"
        fi
        shift
    done

    if [ ! -z ${args} ]; then
        log_message "${args} は不正な引数です。"
        fin 1
    fi

    echo "///// args /////////////////////" >> $LOGFILE
    echo "pre_flg: $pre_flg" >> $LOGFILE
    echo "args: $args" >> $LOGFILE
    echo "dev_flg: $dev_flg" >> $LOGFILE
    echo "stg_flg: $stg_flg" >> $LOGFILE
    echo "ver_flg: $ver_flg" >> $LOGFILE
    echo "S_APP_VERSION: $S_APP_VERSION" >> $LOGFILE
    echo "offline_flg: $offline_flg" >> $LOGFILE
    echo "REGISTRY_OVA: $REGISTRY_OVA" >> $LOGFILE
    echo "REGISTRY_OVA_IP: $REGISTRY_OVA_IP" >> $LOGFILE
    echo "REGISTRY_OVA_PORT: $REGISTRY_OVA_PORT" >> $LOGFILE
    echo "SCRIPTS_URL_ES: $SCRIPTS_URL_ES" >> $LOGFILE
    echo "SCRIPTS_URL: $SCRIPTS_URL" >> $LOGFILE
    echo "////////////////////////////////" >> $LOGFILE

    if [ $dev_flg -eq 1 ] ; then
        if [ $BRANCH != "Dev" ] ; then
            BRANCH="Dev"
        fi
    elif [ $stg_flg -eq 1 ] ; then
        if  [ $BRANCH != "Staging" ] ; then
            BRANCH="Staging"
        fi
    fi
}

function select_version() {
    ### attention common setup&update ###
    CHART_VERSION=""
    VERSION_DEPLOYED=""
    if which helm >/dev/null 2>&1 ; then
        VERSION_DEPLOYED=$(helm list shield-management 2>&1 | awk '{ print $10 }')
        VERSION_DEPLOYED=$(echo ${VERSION_DEPLOYED} | sed -e "s/[\r\n]\+//g")
    fi
    if [[ "VERSION_DEPLOYED" == "" ]] && [ -f ".es_version" ] ; then
        VERSION_DEPLOYED=$(cat .es_version)
    elif [[ "VERSION_DEPLOYED" == "" ]] && [ -f "$ES_PATH/.es_version" ] ; then
        VERSION_DEPLOYED=$(cat $ES_PATH/.es_version)
    fi
    echo "=================================================================="
    if [ -z $VERSION_DEPLOYED ] || [[ "$VERSION_DEPLOYED" == "request" ]] ; then
        log_message "現在インストールされているバージョン: N/A"
    else
        BUILD=()
        BUILD=(${VERSION_DEPLOYED//./ })
        BUILD=${BUILD[2]}
        GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
        log_message "現在インストールされているバージョン: ${GIT_BRANCH}_Build:${BUILD}"
    fi
    echo "=================================================================="

    if [ $pre_flg -eq 1 ] ; then
        CHART_VERSION=$(curl -sL ${SCRIPTS_URL}/k8s-pre-rel-ver.txt | awk '{ print $1 }')
        S_APP_VERSION=$(curl -sL ${SCRIPTS_URL}/k8s-pre-rel-ver.txt | awk '{ print $2 }')

        if [ "$CHART_VERSION" == "NA" ]; then
            log_message "現在ご利用可能なリリース前先行利用バージョンはありません。"
            fin 1
        else
            BUILD=()
            BUILD=(${S_APP_VERSION//./ })
            BUILD=${BUILD[2]}
            GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
            echo -n "リリース前先行利用バージョン ${GIT_BRANCH}_Build:${BUILD} をセットアップします。[Y/n]:"
            read ANSWER
            echo "pre-use: $S_APP_VERSION" >> $LOGFILE
            echo "ANSWER: $ANSWER" >> $LOGFILE
            case $ANSWER in
                "" | "Y" | "y" | "yes" | "Yes" | "YES" ) echo "Start."
                                                         ;;
                * ) echo "STOP."
                    fin 1
                    ;;
            esac
        fi
    elif [ $ver_flg -eq 1 ] ; then
            CHART=(${S_APP_VERSION//./ })
            CHART_VERSION="${CHART[0]}.$(( 10#${CHART[1]} )).${CHART[2]}"
    else
        declare -A vers_c
        declare -A vers_a
        n=0
        m=0

        if [ "$BRANCH" == "Dev" ]; then
            VER=$(curl -s "https://ericom:${ERICOMPASS}@helmrepo.shield-service.net/dev/index.yaml" | grep ersion | grep -v api | sed -e ':loop; N; $!b loop; s/\n\s*version/ /g' | awk '{printf "%s %s\n", $4,$2}')
        elif [ "$BRANCH" == "Staging" ]; then
            VER=$(curl -s "https://ericom:${ERICOMPASS}@helmrepo.shield-service.net/staging/index.yaml" | grep ersion | grep -v api | sed -e ':loop; N; $!b loop; s/\n\s*version/ /g' | awk '{printf "%s %s\n", $4,$2}')
        else
            VER=$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver.txt | grep -v CHART | awk '{printf "%s %s\n", $2,$3}')
        fi

        echo "どのバージョンをセットアップしますか？"
        for i in $VER
        do
            n=$(( $n + 1 ))
            if [ $((${n} % 2)) = 0 ]; then
                m=$(( $n / 2 ))
                S_APP_VERSION=$i
                vers_a[$m]=$S_APP_VERSION
                if [ "$BRANCH" != "Staging" ] && [ "$BRANCH" != "Dev" ] ; then
                    BUILD=()
                    BUILD=(${S_APP_VERSION//./ })
                    BUILD=${BUILD[2]}
                    GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
                    echo "$m: ${GIT_BRANCH}_Build:${BUILD}"
                else
                    echo "$m: Rel-$S_APP_VERSION" 
                fi
            else
                if [ $n = 1 ]; then
                    m=1
                else
                    m=$(( $n - $m ))
                fi
                CHART_VERSION=$i
                vers_c[$m]=$CHART_VERSION
            fi
        done

        while :
        do
            echo
            echo -n " 番号で指定してください: "
            read answer
            echo "selected versio#: $answer" >> $LOGFILE
            if [[ -z ${vers_c[$answer]} ]] ; then
                    echo "番号が違っています。"
            else
                    CHART_VERSION=${vers_c[$answer]}
                    S_APP_VERSION=${vers_a[$answer]}
                    break
            fi
        done
    fi

    if [ "$BRANCH" != "Staging" ] && [ "$BRANCH" != "Dev"  ]; then
        BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${S_APP_VERSION} | awk '{print $2}')"
        BUILD=()
        BUILD=(${S_APP_VERSION//./ })
        CHKBRANCH=${BUILD[0]}${BUILD[1]}
        BUILD=${BUILD[2]}
        GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"

        log_message "${GIT_BRANCH}_Build:${BUILD} をセットアップします。"
    else
        log_message "Rel-${S_APP_VERSION} をセットアップします。"
    fi

    change_dir

    echo ${S_APP_VERSION} > .es_version
}

function change_dir(){
    BUILD=()
    BUILD=(${S_APP_VERSION//./ })
    CHKBRANCH=${BUILD[0]}${BUILD[1]}
    if [[ $CHKBRANCH -lt 1911 ]];then
        log_message "pwd: $(pwd)"        
    else
        log_message "[start] change dir"
        log_message "pwd: $(pwd)"
        find ${CURRENT_DIR} -maxdepth 1 -name \*.sh -not -name shield-setup.sh -not -name shield-update.sh | xargs -I {} mv -f {} ${ES_PATH}/ > /dev/null 2>&1
        find ${CURRENT_DIR} -maxdepth 1 -name .es_\* -not -name .es_custom_env | xargs -I {} mv -f {} ${ES_PATH}/ > /dev/null 2>&1
        find ${CURRENT_DIR} -maxdepth 1 -name .ra_\* | xargs -I {} mv -f {} ${ES_PATH}/ > /dev/null 2>&1
        find ${CURRENT_DIR} -maxdepth 1 -name \*.yaml\* | xargs -I {} mv -f {} ${ES_PATH}/ > /dev/null 2>&1
        mv -f ${CURRENT_DIR}/command.txt ${ES_PATH}/ > /dev/null 2>&1
        mv -f ${CURRENT_DIR}/sup ${ES_PATH}/ > /dev/null 2>&1
        cd ${ES_PATH}
        log_message "pwd: $(pwd)"        
        log_message "[end] change dir"
    fi
}

function mv_rancher_store(){
    if [[ $CHKBRANCH -lt 1911 ]];then
        : 
    else
        if [ -d ${CURRENT_DIR}/rancher-store ];then
            log_message "[start] move rancher-store"
            log_message "[stop] stop rancher server"
            docker stop $(docker ps | grep "rancher/rancher" | cut -d" " -f1)
            mv -f ${CURRENT_DIR}/rancher-store ${ES_PATH}/
            log_message "[end] move rancher-store"
        else
            #log_message "[start] restart rancher server"
            log_message "[stop] stop rancher server"
            docker stop $(docker ps | grep "rancher/rancher" | cut -d" " -f1)
        fi
    fi
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
    log_message "###### DONE (update)############################################################"
    exit $1
}

function get_scripts() {
    log_message "[start] get install scripts"
    curl -s -o ${CURRENT_DIR}/shield-setup.sh -L ${SCRIPTS_URL}/shield-setup.sh
    chmod +x ${CURRENT_DIR}/shield-setup.sh
    cp -fp configure-sysctl-values.sh configure-sysctl-values.sh_backup
    if [[ $offline_flg -eq 0 ]]; then
        curl -s -OL ${SCRIPTS_URL}/configure-sysctl-values.sh
    else
        curl -s -OL ${SCRIPTS_URL_ES}/configure-sysctl-values.sh
    fi
    chmod +x configure-sysctl-values.sh

    if [[ $offline_flg -eq 0 ]] && [[ ! -f ${ES_PATH}/delete-shield.sh ]]; then
        curl -s -o ${ES_PATH}/delete-shield.sh -L https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/Rel-20.03/Kube/scripts/shield-setup.sh
        chmod +x ${ES_PATH}/delete-shield.sh
    fi
    log_message "[end] get install scripts"
}

function check_sysctl() {
    log_message "[start] check sysctl file"
    if [ $(diff -c configure-sysctl-values.sh configure-sysctl-values.sh_backup | wc -l) -gt 0 ]; then
        log_message "[start] exec sysctl script"
        sudo ./configure-sysctl-values.sh
        echo '------------------------------------------------------------'
        echo "(下記を他のノードでも実行してください。)"
        echo ""
        if [[ $offline_flg -eq 0 ]]; then
            echo "curl -s -OL ${SCRIPTS_URL}/configure-sysctl-values.sh"
        else
            echo "curl -s -OL ${SCRIPTS_URL_ES}/configure-sysctl-values.sh"
        fi
        echo 'chmod +x configure-sysctl-values.sh'
        echo 'sudo ./configure-sysctl-values.sh'
        echo ""
        echo '------------------------------------------------------------'
        while :
        do
            echo ""
            echo "================================================================================="
            echo -n '先へ進んでよろしいですか？ [y/N]:'
                read ANSWER
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
        done
        log_message "[end] exec sysctl script"
    fi
    log_message "[end] check sysctl file"
}

function get_yaml() {
    log_message "[start] get yaml files"
    COMPONENTS=(farm proxy management values-elk common)
    for yamlfile in "${COMPONENTS[@]}"
    do
        cp -fp custom-${yamlfile}.yaml custom-${yamlfile}.yaml_backup
        if [[ $offline_flg -eq 0 ]];then
            curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/custom-${yamlfile}.yaml
        else
            curl -s -OL ${SCRIPTS_URL_ES}/custom-${yamlfile}.yaml
        fi
    done
    log_message "[end] get yaml files"
    
    log_message "[start] check yaml files"
    check_yaml
    for yamlfile in "${COMPONENTS[@]}"
    do
        if [ $(diff -c custom-${yamlfile}.yaml custom-${yamlfile}.yaml_backup | wc -l) -gt 0 ]; then
               diff -c custom-${yamlfile}.yaml custom-${yamlfile}.yaml_backup > diff_custom-${yamlfile}.yaml
        fi
    done
    
    if [[ $(ls diff_*.yaml 2>/dev/null | wc -l) -ne 0 ]]; then
        echo "新しいyamlファイルと既存のファイルに差分がある可能性があります。下記ファイルを確認し、適切に編集後、$0 ${ALL_ARGS} を再実行してください。"
        echo "※基本的にはユーザが意図して設定変更した箇所以外は新しいyamlファイルの記述を採用してください。"

        for difffile in $(ls diff_*.yaml)
        do
            echo ${ES_PATH}/${difffile}
        done
    else
        echo "yamlファイルに更新はありませんでした。そのまま再度　$0 ${ALL_ARGS} を再実行してください。"
    fi

    log_message "[end] check yaml files"
}

function check_yaml() {
    mng_anti_flg=$(cat custom-management.yaml_backup | grep -v "#" | grep antiAffinity | grep -c hard)
    if [[ $mng_anti_flg -ge 1 ]];then
        sed -i -e '/#.*antiAffinity/s/^.*#.*antiAffinity/  antiAffinity/g' custom-management.yaml
    fi

    farm_anti_flg=$(cat custom-farm.yaml_backup | grep -v "#" | grep antiAffinity | grep -c hard)   
    if [[ $farm_anti_flg -ge 1 ]];then
        sed -i -e '/#.*antiAffinity/s/^.*#.*antiAffinity/  antiAffinity/g' custom-farm.yaml
    fi

    spell_flg=$(cat custom-farm.yaml_backup | grep -v "#" | grep DISABLE_SPELL_CHECK | grep -c true)
    if [ $spell_flg -eq 1 ]; then
        sed -i -e 's/^#farm-services/farm-services/' custom-farm.yaml
        sed -i -e 's/^#.*DISABLE_SPELL_CHECK/  DISABLE_SPELL_CHECK/' custom-farm.yaml
    fi

    ses_limit_flg=$(cat custom-proxy.yaml_backup | grep -v "#" | grep checkSessionLimit | grep -c true)
    if [ $ses_limit_flg -eq 1 ]; then
        sed -i -e 's/^#shield-proxy/shield-proxy/' custom-proxy.yaml
        sed -i -e 's/^#.*checkSessionLimit/  checkSessionLimit/' custom-proxy.yaml
    fi
    if [ $elk_snap_flg -eq 1 ]; then
        sed -i -e '/#.*enableSnapshots/s/^.*#.*enableSnapshots/    enableSnapshots/g' custom-values-elk.yaml
    fi
}


function exec_update(){
    if [ $dev_flg -eq 1 ]; then
        /bin/bash $CURRENT_DIR/shield-setup.sh --update --version ${S_APP_VERSION} --Dev
    elif [ $stg_flg -eq 1 ]; then
        /bin/bash $CURRENT_DIR/shield-setup.sh --update --version ${S_APP_VERSION} --Staging
    else
        /bin/bash $CURRENT_DIR/shield-setup.sh --update --version ${S_APP_VERSION}
    fi
}

######START#####
log_message "###### START (update)###########################################################"

# check args and set flags
ALL_ARGS="$@"
check_args $@

export BRANCH
log_message "BRANCH: $BRANCH"


if [ ! -f .es_update ] && [ ! -f ${ES_PATH}/.es_update ]; then
    select_version

    export BRANCH
    echo $BRANCH > .es_branch
    log_message "BRANCH: $BRANCH"

    if [[ "$BRANCH" == "Rel-20.03" ]] || [[ "$BRANCH" == "Rel-20.01.2" ]] || [[ "$BRANCH" == "Rel-19.12.1" ]] || [[ "$BRANCH" == "Rel-19.11" ]] || [[ "$BRANCH" == "Rel-19.09.5" ]] || [[ "$BRANCH" == "Rel-19.09.1" ]]  || [[ "$BRANCH" == "Rel-19.07.1" ]] ;then
        old_flg=1
        if [[ $offline_flg -eq 0 ]]; then
            log_message "###### for OLD version Re-START ###########################################################"
            curl -s -o ${ES_PATH}/shield-update-online-old.sh -L ${SCRIPTS_URL}/shield-update-online-old.sh 
            chmod +x ${ES_PATH}/shield-update-online-old.sh
            ${ES_PATH}/shield-update-online-old.sh $@ --version $S_APP_VERSION
            rm -f ${ES_PATH}/shield-update-online-old.sh
            exit 0
        fi
    fi

    # get install scripts
    get_scripts
    check_sysctl    
    #get_yaml
    echo ${S_APP_VERSION} > .es_update
    cd ${CURRENT_DIR}
    $0 ${ALL_ARGS}
    fin 0
else
    if [[ "$BRANCH" == "Rel-20.03" ]] || [[ "$BRANCH" == "Rel-20.01.2" ]] || [[ "$BRANCH" == "Rel-19.12.1" ]] || [[ "$BRANCH" == "Rel-19.11" ]] || [[ "$BRANCH" == "Rel-19.09.5" ]] || [[ "$BRANCH" == "Rel-19.09.1" ]]  || [[ "$BRANCH" == "Rel-19.07.1" ]] ;then
        old_flg=1
        if [[ $offline_flg -eq 0 ]]; then
            log_message "###### for OLD version Re-START ###########################################################"
            curl -s -o ${ES_PATH}/shield-update-online-old.sh -L ${SCRIPTS_URL}/shield-update-online-old.sh 
            chmod +x ${ES_PATH}/shield-update-online-old.sh
            ${ES_PATH}/shield-update-online-old.sh $@ --version $S_APP_VERSION
            rm -f ${ES_PATH}/shield-update-online-old.sh
            exit 0
        fi
    fi
    while :
    do
        echo ""
        echo "================================================================================="
        echo -n 'updateを実行します。よろしいですか？(Update前にShieldシステムを停止します。) [y/N]:'
            read ANSWER
            case $ANSWER in
                "Y" | "y" | "yse" | "Yes" | "YES" )
                    break
                    ;;
                "" | "n" | "N" | "no" | "No" | "NO" )
                    ;;
                * )
                    echo "YまたはNで答えて下さい。"
                    ;;
            esac
    done
    if [ -f .es_update ];then
        S_APP_VERSION=$(cat .es_update)
    else
        S_APP_VERSION=$(cat ${ES_PATH}/.es_update)
    fi
    change_dir
    rm -f .es_update
    ./shield-stop.sh
    mv_rancher_store
    exec_update
fi

fin 0


