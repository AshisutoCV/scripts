#!/bin/bash

####################
### K.K. Ashisuto
### VER=20240214a-dev
####################

function usage() {
    echo ""
    echo "USAGE: $0 [--pre-use] [--deploy] [--get-custom-yaml] [--uninstall] [--delete-all] [--offline --registry <Registry IP>:<Port>]"
    echo "    --pre-use         : 日本での正式リリースに先立ち、1バージョン先のものをβ扱いでご利用いただけます。"
    echo "                        ※ただし、先行利用バージョンについては、一切のサポートがございません。"
    echo "    --deploy          : Rancherクラスタが構成済みの環境で、Shieldの展開のみを行います。"
    echo "    --spell-check-on  : ブラウザのスペルチェック機能をONの状態でセットアップします。"
    echo "                        ※日本語環境ではメモリリークの原因になるためデフォルトOFFです。"
    echo "    --ses-chek-off    : 認証を行わない場合のセッション数チェックを行う機能をOFFでセットアップします。"
    echo "                        デフォルト ONの状態でセットアップされます。"
    echo "                        認証利用時にはOFFにすることで若干のレスポンス改善が見込まれます。"
    echo "    --get-custom-yaml : helm展開時のcustom yamlファイルを新規に取得して上書きします。"
    echo "                        独自に加えた変更が保持されませんのでご注意ください。"
    echo "    --uninstall       : Shield のみをアンインストールします。 --deploy により再展開できます。"
    echo "    --delete-all      : Rancherを含めて全てのコンテナを削除します。クラスタも破棄します。"
    echo "    --offline         : Registry OVA を用いた、オフラインセットアップを行います。"
    echo "                        --registry を必ずあわせて指定してください。"
    echo "    --registry        : Registry OVA のレジストリIPアドレスを指定します。"
    echo ""
    exit 0
    ### for Develop only
    # [--version <Chart version>]
    # [--spare]
    # [--change-spare]
    ##
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi


export HOME=$(eval echo ~${SUDO_USER})
export KUBECONFIG=${HOME}/.kube/config

export ES_PATH="$HOME/ericomshield"
export ES_PATH_ERICOM="/home/ericom/ericomshield"
export ERICOM_PATH="/home/ericom"
if [ ! -e $ES_PATH ];then
    mkdir -p $ES_PATH
fi

if [ ! -e ${ES_PATH}/logs/ ];then
    mkdir -p ${ES_PATH}/logs
    mv -f ./*.log ${ES_PATH}/logs/ > /dev/null 2>&1
    mv -f ./logs/ ${ES_PATH}/logs/ > /dev/null 2>&1
fi

LOGFILE="${ES_PATH}/logs/install.log"
FLGFILE="${ES_PATH}/.for_pm-fix_flg"
CMDFILE="command.txt"
BRANCH="Rel"
ERICOMPASS="Ericom123$"
ERICOMPASS2="Ericom98765$"
DOCKER_USER="ericomshield1"
DOCKER_USER_SPARE="ericomshield9"
CLUSTERNAME="shield-cluster"
STEP_BY_STEP="false"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR
#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/feature/2315"
SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Kube/scripts"

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi

if [ -f ${ES_PATH}/.es_offline ] ;then
    offline_flg=1
else
    offline_flg=0
fi

function apt-unlock(){
    sudo rm /var/lib/apt/lists/lock
    sudo rm /var/lib/dpkg/lock
    sudo rm /var/lib/dpkg/lock-frontend
}

function check_ericom_user(){
    # ericomユーザ存在確認
    if [[ $(cat /etc/passwd | grep -c ericom) -eq 0 ]];then
            log_message "[ERROR] ericomユーザが存在しません。prepare-node.shを実行したか確認してください。"        
            failed_to_install "check_ericom_user"
    else
        # es_prepareを移動
        if [[ -f ${ES_PATH}/.es_prepare ]];then
            log_message "[info] Move .es_prepare flg file..."
            sudo mv -f ${ES_PATH}/.es_prepare ${ERICOM_PATH}/.es_prepare
            sudo chown ericom:ericom ${ERICOM_PATH}/.es_prepare
        fi
        if [[ -f ${ES_PATH_ERICOM}/.es_prepare ]];then
            log_message "[info] Move .es_prepare flg file..."
            sudo mv -f ${ES_PATH_ERICOM}/.es_prepare ${ERICOM_PATH}/.es_prepare
            sudo chown ericom:ericom ${ERICOM_PATH}/.es_prepare
        fi

        ES_PREPARE="$ERICOM_PATH/.es_prepare"    
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

function failed_to_install() {
    log_message "An error occurred during the installation: $1, exiting"
    if [ "$2" == "es" ]; then
        log_message "[start] rollback"
        uninstall_shield
        log_message "[end] rollback"
    elif [ "$2" == "all" ]; then
        log_message "[start] rollback"
        delete_all_old
        log_message "[end] rollback"
    elif [ "$2" == "ver" ]; then
        log_message "[start] rollback"
        delete_ver
        log_message "[end] rollback"
    fi
    fin 1
}

function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}

function step() {
    if [ $STEP_BY_STEP = "true" ]; then
        read -p 'Press Enter to continue...' ENTER
    fi
}

function ln_resolv() {
    log_message "[start] Changing to the symbolic link."
    if [[ ! -L /etc/resolv.conf ]];then
        log_message "[WARN]/etc/resolv.conf is NOT symlink"
        if [[ $(cat /etc/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
            log_message "[WARN] nameserver is local stub!"
            if [[ -f /run/systemd/resolve/resolv.conf ]];then
                log_message "[INFO] /run/systemd/resolve/resolv.conf exist!"
                if [[ $(cat /run/systemd/resolve/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                    log_message "[WARN] /run/systemd/resolve/resolv.conf が local stub になっています。確認してください。"
                    fin 1
                else
                    sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                    sudo systemctl restart systemd-resolved
                    log_message "[INFO] Changed to symlink"
                    log_message "ノードを再起動してから、再度スクリプトを実行してください。"
                    fin 0
                fi
            else
                log_message "[WARN]　/run/systemd/resolve/resolv.conf が存在しません。確認してください。"
                fin 1
            fi
        else
            log_message "[INFO ] nameserver is not local stub! Continue!"
        fi
    else
        log_message "[INFO]/etc/resolv.conf is symlink"
        if [[ $(cat /etc/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
            log_message "[WARN] nameserver is local stub!"
            if [[ -f /run/systemd/resolve/resolv.conf ]];then
                log_message "[INFO] /run/systemd/resolve/resolv.conf exist!"
                if [[ $(cat /run/systemd/resolve/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                    log_message "[WARN] /run/systemd/resolve/resolv.conf が local stub になっています。確認してください。"
                    fin 1
                else
                    sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                    sudo systemctl restart systemd-resolved
                    log_message "[INFO] Changed to symlink"
                    log_message "ノードを再起動してから、再度スクリプトを実行してください。"
                    fin 0
                fi
            else
                log_message "/run/systemd/resolve/resolv.conf が存在しません。確認してください。"
                fin 1
            fi
        else
            log_message "[INFO ] nameserver is not local stub! Continue!"
        fi
    fi
    log_message "[end] Changing to the symbolic link."
}

function check_args(){
    pre_flg=0
    args=""
    dev_flg=0
    stg_flg=0
    ver_flg=0
    update_flg=0
    deploy_flg=0
    yamlget_flg=0
    spell_flg=0
    ses_limit_flg=0
    elk_snap_flg=0
    uninstall_flg=0
    deleteall_flg=0
    old_flg=0
    multi_flg=0
    lowres_flg=0
    spare_flg=0
    change_spare_flg=0
    #offline_flg=0
    S_APP_VERSION=""

    echo "args: $@" >> $LOGFILE

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--pre-use" ]; then
            pre_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
        elif [ "$1" == "--update" ] || [ "$1" == "--Update" ] ; then
            update_flg=1
        elif [ "$1" == "--spare" ] || [ "$1" == "--Spare" ] ; then
            spare_flg=1
        elif [ "$1" == "--change-spare" ] || [ "$1" == "--Change-Spare" ] || [ "$1" == "--Change-spare" ] ; then
            change_spare_flg=1
        elif [ "$1" == "--deploy" ] || [ "$1" == "--Deploy" ] ; then
            deploy_flg=1
        elif [ "$1" == "--get-custom-yaml" ] || [ "$1" == "--Get-custom-yaml" ] ; then
            yamlget_flg=1
        elif [ "$1" == "--spell-check-on" ] || [ "$1" == "--Spell-check-on" ] ; then
            spell_flg=1
        elif [ "$1" == "--ses-check-off" ] || [ "$1" == "--Ses-check-off" ] ; then
            ses_limit_flg=1
        elif [ "$1" == "--uninstall" ] || [ "$1" == "--Uninstall" ] ; then
            uninstall_flg=1
        elif [ "$1" == "--offline" ] || [ "$1" == "--Offline" ] || [ "$1" == "--OffLine" ]; then
            offline_flg=1
        elif [ "$1" == "--registry" ] || [ "$1" == "--Registry" ] ; then
            shift
            REGISTRY_OVA="$1"
            REGISTRY_OVA_IP=${REGISTRY_OVA%%:*}
            REGISTRY_OVA_PORT=${REGISTRY_OVA##*:}
            export ES_OFFLINE_REGISTRY="$REGISTRY_OVA"
        elif [ "$1" == "--delete-all" ] || [ "$1" == "--Delete-all" ] || [ "$1" == "--Delete-All" ] ; then
            deleteall_flg=1
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

    if [[ $offline_flg -eq 1 ]] && [[ -f ${ES_PATH}/.es_offline ]]; then
        REGISTRY_OVA=$(cat ${ES_PATH}/.es_offline)
        REGISTRY_OVA_IP=${REGISTRY_OVA%%:*}
        REGISTRY_OVA_PORT=${REGISTRY_OVA##*:}
        export ES_OFFLINE_REGISTRY="$REGISTRY_OVA"
    fi

    echo "///// args /////////////////////" >> $LOGFILE
    echo "pre_flg: $pre_flg" >> $LOGFILE
    echo "args: $args" >> $LOGFILE
    echo "dev_flg: $dev_flg" >> $LOGFILE
    echo "stg_flg: $stg_flg" >> $LOGFILE
    echo "ver_flg: $ver_flg" >> $LOGFILE
    echo "update_flg: $update_flg" >> $LOGFILE
    echo "deploy_flg: $deploy_flg" >> $LOGFILE
    echo "noget_flg: $noget_flg" >> $LOGFILE
    echo "spell_flg: $spell_flg" >> $LOGFILE
    echo "spare_flg: $spare_flg" >> $LOGFILE
    echo "change_spare_flg: $change_spare_flg" >> $LOGFILE
    echo "uninstall_flg: $uninstall_flg" >> $LOGFILE
    echo "deleteall_flg: $deleteall_flg" >> $LOGFILE
    echo "offline_flg: $offline_flg" >> $LOGFILE
    echo "lowres_flg: $lowres_flg" >> $LOGFILE
    echo "S_APP_VERSION: $S_APP_VERSION" >> $LOGFILE
    echo "REGISTRY_OVA: $REGISTRY_OVA" >> $LOGFILE
    echo "REGISTRY_OVA_IP: $REGISTRY_OVA_IP" >> $LOGFILE
    echo "REGISTRY_OVA_PORT: $REGISTRY_OVA_PORT" >> $LOGFILE
    echo "////////////////////////////////" >> $LOGFILE
}

function flg_check(){
    if [ $dev_flg -eq 1 ] ; then
        if [ $BRANCH != "Dev" ] ; then
            BRANCH="Dev"
        fi
    elif [ $stg_flg -eq 1 ] ; then
        if  [ $BRANCH != "Staging" ] ; then
            BRANCH="Staging"
        fi
    fi

    #uninstall
    if [ $uninstall_flg -eq 1 ]; then
        if  [ $BRANCH == "Rel" ] ; then
            export BRANCH="Rel-20.03"
        fi
        while :
        do
            echo ""
            echo "================================================================================="
            echo -n 'Shieldのみアンインストールしてよろしいですか？（クラスタはそのままです。） [y/N]:'
                read ANSWER
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        fin 9
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
        done
        uninstall_shield
        fin 0
    fi

    #delete all
    if [ $deleteall_flg -eq 1 ]; then
        if  [ $BRANCH == "Rel" ] ; then
            export BRANCH="Rel-20.03"
        fi
        while :
        do
            echo ""
            echo "================================================================================="
            echo -n '全てを削除してよろしいですか？ [y/N]:'
                read ANSWER
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        fin 9
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
        done
        uninstall_shield
        delete_all
    fi
    # update_flg parent check
    if [ $update_flg -eq 1 ];then
        PARENTCMD=$(ps -o args= $PPID)
        if [[ ! ${PARENTCMD} =~ shield-update.sh ]] && [[ ! ${PARENTCMD} =~ shield-update-online-old.sh ]]; then
            log_message "--update は直接利用できません。 shield-update.sh をご利用ください。"
            fin 1
        fi
    fi

    if [[ $offline_flg -eq 1 ]] && [[ ! -f ${ES_PATH}/.es_offline ]]; then
        if [[ -z $REGISTRY_OVA ]]; then
            log_message "--offline を指定したい場合、--registry は必須です。"
            fin 1
        fi
        if [ "$BRANCH" == "Dev" ] || [ "$BRANCH" == "Staging" ] ; then
            log_message "--offline を指定したい場合、DevおよびStagingの指定はできません。"
            fin 1
        fi
        echo "$REGISTRY_OVA" > ${ES_PATH}/.es_offline
        SCRIPTS_URL_ES="http://$REGISTRY_OVA_IP/ericomshield"
        SCRIPTS_URL="http://$REGISTRY_OVA_IP/scripts"
    elif [[ -f ${ES_PATH}/.es_offline ]]; then
        SCRIPTS_URL_ES="http://$REGISTRY_OVA_IP/ericomshield"
        SCRIPTS_URL="http://$REGISTRY_OVA_IP/scripts"
    fi
}

function uninstall_shield() {
    log_message "[start] uninstall shield"

    if [[ $offline_flg -eq 0 ]] && [[ ! -f ${ES_PATH}/delete-shield.sh ]]; then
        curl -s https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/delete-shield.sh -o ${ES_PATH}/delete-shield.sh
        chmod +x ${ES_PATH}/delete-shield.sh
    fi
    ${ES_PATH}/delete-shield.sh -s | tee -a $LOGFILE
    rm -f .es_version
    rm -f .es_branch

    log_message "[end] uninstall shield"
}

function delete_all() {
    echo "[start] deletel all object"

    if [[ $offline_flg -eq 0 ]] ; then
        curl -s -L ${SCRIPTS_URL}/delete-all.sh -o ${ES_PATH}/delete-all.sh
        chmod +x ${ES_PATH}/delete-all.sh
    fi
    sudo -E ${ES_PATH}/delete-all.sh | tee -a $LOGFILE

    echo "[end] deletel all object"

    echo '------------------------------------------------------------'
    echo "(【必要に応じて】, 下記を他のノードでも実行してください。)"
    echo ""
    if [[ $offline_flg -eq 0 ]]; then
        echo "curl -s -OL ${SCRIPTS_URL}/delete-all.sh"
        echo 'chmod +x delete-all.sh'
    fi
    echo 'sudo -E ./delete-all.sh'
    echo ""
    echo '------------------------------------------------------------'
    exit 0
}

function delete_all_old() {
    log_message "[start] deletel all object"

    if [[ $offline_flg -eq 0 ]] && [[ ! -f ${ES_PATH}/delete-all-1.sh ]]; then
        curl -s -L ${SCRIPTS_URL}/delete-all-1.sh -o ${ES_PATH}/delete-all-1.sh
        chmod +x ${ES_PATH}/delete-all-1.sh
    fi
    sudo -E ${ES_PATH}/delete-all-1.sh | tee -a $LOGFILE

    log_message "[end] deletel all object"

    echo '------------------------------------------------------------'
    echo "(【必要に応じて】, 下記を他のノードでも実行してください。)"
    echo ""
    if [[ $offline_flg -eq 0 ]]; then
        echo "curl -s -OL ${SCRIPTS_URL}/delete-all-1.sh"
        echo 'chmod +x delete-all-1.sh'
    fi
    echo 'sudo -E ./delete-all-1.sh'
    echo ""
    echo '------------------------------------------------------------'
}

function select_version() {
    ### attention common setup&update&shield-prepare-servers ###
    CHART_VERSION=""
    VERSION_DEPLOYED=""
    if which helm >/dev/null 2>&1 ; then
        VERSION_DEPLOYED=$(helm list shield-management 2>&1 | awk '{ print $10 }')
        VERSION_DEPLOYED=$(echo ${VERSION_DEPLOYED} | sed -e "s/[\r\n]\+//g")
    fi
    if [[ "$VERSION_DEPLOYED" == "" ]] && [ -f ".es_version" ] ; then
        VERSION_DEPLOYED=$(cat .es_version)
    elif [[ "$VERSION_DEPLOYED" == "" ]] && [ -f "$ES_PATH/.es_version" ] ; then
        VERSION_DEPLOYED=$(cat $ES_PATH/.es_version)
    fi
    echo "=================================================================="
    if [ -z $VERSION_DEPLOYED ] || [[ "$VERSION_DEPLOYED" == "request" ]] ; then
        log_message "現在インストールされているバージョン: N/A"
    else
        BUILD=()
        BUILD=(${VERSION_DEPLOYED//./ })
        GBUILD=${BUILD[0]}.${BUILD[1]}
        if [[ ${BUILD[3]} ]] ;then
            BUILD=${BUILD[2]}.${BUILD[3]}
        else
            BUILD=${BUILD[2]}
        fi
        GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
        if [[ $GIT_BRANCH == "Rel-" ]];then
            GIT_BRANCH="Rel-${GBUILD}"
        fi
        log_message "現在インストールされているバージョン: ${GIT_BRANCH}_Build:${BUILD}"
    fi
    echo "=================================================================="


    if [ -f "$ES_PREPARE" ]; then
        log_message "実行済みのshield-prepare-serversバージョン: $(cat $ES_PREPARE)"
    else
        log_message "[error] shield-prepare-serversが未実行のようです。"
        echo "=================================================================="
        failed_to_install "select_version check_prepare"
        #for shield-prepare-servers.sh
        #log_message "[info] shield-prepare-serversは未実行。"
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
            GBUILD=${BUILD[0]}.${BUILD[1]}
            if [[ ${BUILD[3]} ]] ;then
                BUILD=${BUILD[2]}.${BUILD[3]}
            else
                BUILD=${BUILD[2]}
            fi
            GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
            if [[ $GIT_BRANCH == "Rel-" ]];then
                GIT_BRANCH="Rel-${GBUILD}"
            fi
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
            if [[ ${CHART[3]} ]] ;then
                CHART_VERSION="${CHART[0]}.$(( 10#${CHART[1]} )).${CHART[2]}.${CHART[3]}"
            else
                CHART_VERSION="${CHART[0]}.$(( 10#${CHART[1]} )).${CHART[2]}"
            fi
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
            VER=$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver.txt | grep -v CHART | awk '{printf "%s %s %s\n", $2,$3,$4}')
        fi

        echo "どのバージョンをセットアップしますか？"
        for i in $VER
        do
            n=$(( $n + 1 ))
            if [ $((${n} % 3)) = 1 ]; then
                if [ $n = 1 ]; then
                    m=1
                else
                    m=$(( $m + 1 ))
                fi
                CHART_VERSION=$i
                vers_c[$m]=$CHART_VERSION
            elif [ $((${n} % 3)) = 2 ]; then
                S_APP_VERSION=$i
                vers_a[$m]=$S_APP_VERSION
                if [ "$BRANCH" != "Staging" ] && [ "$BRANCH" != "Dev" ] ; then
                    BUILD=()
                    BUILD=(${S_APP_VERSION//./ })
                    GBUILD=${BUILD[0]}.${BUILD[1]}
                    if [[ ${BUILD[3]} ]] ;then
                        BUILD=${BUILD[2]}.${BUILD[3]}
                    else
                        BUILD=${BUILD[2]}
                    fi
                    GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
                    if [[ $GIT_BRANCH == "Rel-" ]];then
                        GIT_BRANCH="Rel-${GBUILD}"
                    fi
                    #echo "$m: ${GIT_BRANCH}_Build:${BUILD}"
                else
                    : #echo "$m: Rel-$S_APP_VERSION" 
                fi
            elif [ $((${n} % 3)) = 0 ]; then
                if [ "$BRANCH" != "Staging" ] && [ "$BRANCH" != "Dev" ] ; then
                    if [[ $i == "eol" ]]; then
                        echo "$m: ${GIT_BRANCH}_Build:${BUILD} ※サポート終了"
                    else
                        echo "$m: ${GIT_BRANCH}_Build:${BUILD}"
                    fi
                else
                    echo "$m: Rel-$S_APP_VERSION" 
                fi
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
        BUILD=()
        BUILD=(${S_APP_VERSION//./ })
        CHKBRANCH=${BUILD[0]}${BUILD[1]}
        GBUILD=${BUILD[0]}.${BUILD[1]}
        if [[ ${BUILD[3]} ]] ;then
            BUILD=${BUILD[2]}.${BUILD[3]}
        else
            BUILD=${BUILD[2]}
        fi
        BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${S_APP_VERSION} | awk '{print $2}')"
        if [[ $BRANCH == "Rel-" ]];then
            BRANCH="Rel-${GBUILD}"
        fi
        GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
        if [[ $GIT_BRANCH == "Rel-" ]];then
            GIT_BRANCH="Rel-${GBUILD}"
        fi
        log_message "${GIT_BRANCH}_Build:${BUILD} をセットアップします。"
    else
        log_message "Rel-${S_APP_VERSION} をセットアップします。"
    fi

    change_dir
}

function change_dir(){
    BUILD=()
    BUILD=(${S_APP_VERSION//./ })
    CHKBRANCH=${BUILD[0]}${BUILD[1]}
    if [[ ${BUILD[3]} ]] ;then
        BUILD=${BUILD[2]}.${BUILD[3]}
    else
        BUILD=${BUILD[2]}
    fi
    if [[ $CHKBRANCH -lt 1911 ]];then
        log_message "pwd: $(pwd)"        
    else
        log_message "[start] change dir"
        log_message "pwd: $(pwd)"        
        cd ${ES_PATH}
        log_message "pwd: $(pwd)"        
        log_message "[end] change dir"
    fi
}

function get_scripts() {
    log_message "[start] get operation scripts"
    if [[ $offline_flg -eq 0 ]] && [[ ! -f clean-rancher-agent.sh ]]; then
        curl -s -O ${SCRIPTS_URL_ES}/clean-rancher-agent.sh
        chmod +x clean-rancher-agent.sh
    fi

    curl -s -OL ${SCRIPTS_URL}/delete-all.sh
    chmod +x delete-all.sh

    curl -s -OL ${SCRIPTS_URL}/shield-nodes.sh
    chmod +x shield-nodes.sh

    curl -s -OL ${SCRIPTS_URL}/shield-start.sh
    chmod +x shield-start.sh

    curl -s -OL ${SCRIPTS_URL}/shield-stop.sh
    chmod +x shield-stop.sh

    curl -s -OL ${SCRIPTS_URL}/shield-status.sh
    chmod +x shield-status.sh

    curl -s -o ${CURRENT_DIR}/shield-update.sh -L ${SCRIPTS_URL}/shield-update.sh
    chmod +x ${CURRENT_DIR}/shield-update.sh
  
    if [ ! -e ./sup/ ];then
        mkdir sup
    fi
    curl -s -o ./sup/shield-sup.sh -L ${SCRIPTS_URL}/sup/shield-sup.sh
    chmod +x ./sup/shield-sup.sh

    curl -s -o ./sup/getlog.sh -L ${SCRIPTS_URL}/sup/getlog.sh
    chmod +x ./sup/getlog.sh

    if [ ! -e ./org/ ];then
        mkdir org
    fi
    mv -f ./start.sh ./org/start.sh
    mv -f ./stop.sh ./org/stop.sh
    mv -f ./status.sh ./org/status.sh

    log_message "[end] get operation scripts"
}

function choose_network_interface() {
    local INTERFACES=($(find /sys/class/net -type l -not -lname '*virtual*' -printf '%f\n'))
    local INTERFACE_ADDRESSES=()
    local OPTIONS=()
    
    if [ -f "/etc/netplan/00-installer-config.yaml" ]; then
        INTERFACES+=($(cat /etc/netplan/00-installer-config.yaml | python3 -c "import yaml; import json; import sys; print(json.dumps(yaml.load(sys.stdin, Loader=yaml.SafeLoader), indent=2))" | jq -r '.network.vlans | keys' | jq -r '.[]'))
    fi
    
    if [ -f "/sys/class/net/bonding_masters" ]; then
        INTERFACES+=($(cat /sys/class/net/bonding_masters))
    fi

    for IFACE in "${INTERFACES[@]}"; do
        local IF_ADDR="$(/sbin/ip address show scope global dev $IFACE | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+')"
        if [ ! -z "$IF_ADDR" ]; then
            OPTIONS+=("Name: \"$IFACE\", IP address: $IF_ADDR")
            INTERFACE_ADDRESSES+=("$IF_ADDR")
        fi
    done

    if ((${#OPTIONS[@]} == 0)); then
        log_message "No network interface cards detected. Aborting!"
        exit 1
    elif ((${#OPTIONS[@]} == 1)); then
        local REPLY=1
        log_message "Using ${INTERFACES[$((REPLY - 1))]} with address ${INTERFACE_ADDRESSES[$((REPLY - 1))]} as an interface for Shield"
        MY_IP="${INTERFACE_ADDRESSES[$((REPLY - 1))]}"
        return
    fi

    echo "Choose a network card to be used by Shield"
    PS3="Enter your choice: "
    select opt in "${OPTIONS[@]}" "Quit"; do

        case "$REPLY" in

        [1-$((${#OPTIONS[@]}))]*)
            log_message "Using ${INTERFACES[$((REPLY - 1))]} with address ${INTERFACE_ADDRESSES[$((REPLY - 1))]} as an interface for Shield"
            MY_IP="${INTERFACE_ADDRESSES[$((REPLY - 1))]}"
            return
            ;;
        $((${#OPTIONS[@]} + 1)))
            break
            ;;
        *)
            echo "Invalid option. Try another one."
            continue
            ;;
        esac
    done

    failed_to_install "choose_network_interface" "ver"
}

function check_docker() {

    if [ ! -z $DOCKER_VER ]; then
        sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"${DOCKER_VER}\"/" install-docker.sh
    fi

    APP_VERSION=$(cat ./install-docker.sh | grep APP_VERSION= |cut -d= -f2)
    APP_VERSION=$(echo $APP_VERSION | sed "s/\"//g")
    APP_VER=(${APP_VERSION//./ })
    if [ -x "/usr/bin/docker" ]; then
        if ! $(docker info > /dev/null 2>&1) ; then
            check_group
        fi
        INSTALLED_VERSION=$(docker info |grep "Server Version" | awk '{print $3}')
    else
        INSTALLED_VERSION="0.0.0"
    fi
    INSTALLED_VER=(${INSTALLED_VERSION//./ })

    if [[ ${INSTALLED_VER[0]#0}  -gt ${APP_VER[0]#0} ]]; then
        log_message "$INSTALLED_VERSION > $APP_VERSION"
    elif  [[ ${INSTALLED_VER[0]#0} -lt ${APP_VER[0]#0} ]]; then
        log_message "$INSTALLED_VERSION < $APP_VERSION"
        log_message "Install target is $APP_VERSION"
        ./install-docker.sh >>"$LOGFILE" 2>&1
    else
        if [[ ${INSTALLED_VER[1]#0}  -gt ${APP_VER[1]#0} ]]; then
            log_message "$INSTALLED_VERSION > $APP_VERSION"
        elif  [[ ${INSTALLED_VER[1]#0}  -lt ${APP_VER[1]#0} ]]; then
            log_message "$INSTALLED_VERSION < $APP_VERSION"
            log_message "Install target is $APP_VERSION"
            ./install-docker.sh >>"$LOGFILE" 2>&1
        elif [[ ${INSTALLED_VER[1]#0}  -eq ${APP_VER[1]#0} ]]; then
            log_message "$INSTALLED_VERSION = $APP_VERSION"
        fi
    fi

    if ! which docker > /dev/null 2>&1 ; then
        failed_to_install "install_docker" "ver"
    fi
}

function check_group() {
    log_message "[start] check group"
    docker_flg=0
    for GROUP in $(groups $USER | cut -d: -f2)
    do
        if [ "docker" == "$GROUP" ]; then
            if ! $(docker info > /dev/null 2>&1) ; then
                log_message "================================================================================="
                log_message "実行ユーザをdockerグループに追加する必要があります。"
                log_message "(グループへの追加は行われています。)"
                log_message "一度ログオフした後、ログインをしなおして、スクリプトを再度実行してください。"
                log_message "================================================================================="
                rm -f .es_version
                rm -f .es_branch
                fin 1
            fi
            docker_flg=1
            break
        fi
    done

    if [ $docker_flg -eq 0 ]; then
        echo ""
        log_message "================================================================================="
        log_message "実行ユーザをdockerグループに追加する必要があります。"
        log_message "追加後、セットアップスクリプトは中断します。"
        log_message "一度ログオフした後、ログインをしなおして、スクリプトを再度実行してください。"
        log_message "================================================================================="
        log_message "[start] add group"
        sudo -E usermod -aG docker "$USER"
        log_message "[end] add group"
        rm -f .es_version
        rm -f .es_branch
        fin 0
    fi

    log_message "[end] check group"
}

function run_rancher() {
    if [[ "pong" == $(curl -s -k "${RANCHERURL}/ping") ]]; then
        log_message "[info] already start rancher"
    else
        log_message "[start] run rancher"
        ./run-rancher.sh | tee -a $LOGFILE
        log_message "[end] run rancher"
    fi
}

function pre_create_cluster() {
    sudo -E chown -R $(whoami):$(whoami) ${HOME}/.kube
    rancher login --token $(cat ${ES_PATH}/.esranchertoken) --skip-verify $(cat ${ES_PATH}/.esrancherurl)
    echo -n 'getting k8s version.'
    K8S_VER=""
    wait_count=0
    while [ "$K8S_VER" == "" ] && ((wait_count < 36))
    do
        K8S_VER=$(rancher settings get k8s-version 2>/dev/null | grep k8s-version | awk '{print $4}') 
        echo -n "."
        sleep 5
        wait_count=$((wait_count + 1))
    done
    echo
    log_message "K8S_VER: $K8S_VER"
    step
}

function create_cluster() {
    if [ -f .ra_apitoken ]; then
        log_message "[info] already exist APITOKEN"  
    else
        cp -f .esranchertoken .ra_apitoken
    fi
    APITOKEN=$(cat .ra_apitoken)

    if [ -f .ra_clusterid ]; then
        log_message "[info] already exist CLUSTERID"
        CLUSTERID=$(cat .ra_clusterid)
    else
        # Create cluster
        if [[ $CLUSTERNAME == "" ]];then
            echo ""
            echo "================================================================================="
            echo -n 'クラスタ名を設定してください。(任意の名前) : '
            read CLUSTERNAME
        fi
        CLUSTERNAME=${CLUSTERNAME,,}
        echo "CLUSTERNAME: $CLUSTERNAME" >> $LOGFILE

        if [ -z $CLUSTER_CIDR ]; then CLUSTER_CIDR="10.42.0.0/16"; fi
        if [ -z $SERVICE_CLUSTER_IP_RANGE ]; then SERVICE_CLUSTER_IP_RANGE="10.43.0.0/16"; fi
        if [ -z $CLUSTER_DNS_SERVER ]; then CLUSTER_DNS_SERVER="10.43.0.10"; fi
        if [ -z $MAX_PODS ]; then MAX_PODS="110"; fi
        if [ -z $KUBE_RESERVED_CPU ]; then KUBE_RESERVED_CPU="1"; fi
        if [ -z $KUBE_RESERVED_MEM ]; then KUBE_RESERVED_MEM="1Gi"; fi
        if [ -z $SYS_RESERVED_CPU ]; then SYS_RESERVED_CPU="1"; fi
        if [ -z $SYS_RESERVED_MEM ]; then SYS_RESERVED_MEM="0.5Gi"; fi

        echo "CLUSTER_CIDR: $CLUSTER_CIDR" >> $LOGFILE
        echo "SERVICE_CLUSTER_IP_RANGE: $SERVICE_CLUSTER_IP_RANGE" >> $LOGFILE
        echo "CLUSTER_DNS_SERVER: $CLUSTER_DNS_SERVER" >> $LOGFILE
        echo "MAX_PODS: $MAX_PODS" >> $LOGFILE
        echo "KUBE_RESERVED_CPU: $KUBE_RESERVED_CPU" >> $LOGFILE
        echo "KUBE_RESERVED_MEM: $KUBE_RESERVED_MEM" >> $LOGFILE
        echo "SYS_RESERVED_CPU: $SYS_RESERVED_CPU" >> $LOGFILE
        echo "SYS_RESERVED_MEM: $SYS_RESERVED_MEM" >> $LOGFILE
        echo "K8S_VER: $K8S_VER" >> $LOGFILE

        CLUSTERRESPONSE=$(curl -s -k "${RANCHERURL}/v3/cluster" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            --data-binary '{
                "dockerRootDir": "/var/lib/docker",
                "enableNetworkPolicy": false,
                "type": "cluster",
                "localClusterAuthEndpoint": {
                  "type":"localClusterAuthEndpoint",
                  "enabled":true
                },
                "rancherKubernetesEngineConfig": {
                  "addonJobTimeout": 30,
                  "ignoreDockerVersion": true,
                  "sshAgentAuth": false,
                  "type": "rancherKubernetesEngineConfig",
                  "authentication": {
                    "type": "authnConfig",
                    "strategy": "x509"
                  },
                  "network": {
                    "options": {
                      "flannel_backend_type": "vxlan"
                     },
                    "type": "networkConfig",
                    "plugin": "flannel"
                  },
                  "ingress": {
                    "type": "ingressConfig",
                    "provider": "nginx"
                  },
                  "monitoring": {
                    "type": "monitoringConfig",
                    "provider": "metrics-server"
                  },
                  "services": {
                    "type": "rkeConfigServices",
                    "kubeApi": {
                      "serviceClusterIpRange": "'$SERVICE_CLUSTER_IP_RANGE'",
                      "podSecurityPolicy": false,
                      "type": "kubeAPIService"
                    },
                    "kubeController": {
                      "clusterCidr": "'$CLUSTER_CIDR'",
                      "serviceClusterIpRange": "'$SERVICE_CLUSTER_IP_RANGE'",
                      "type": "kubeControllerService"
                    },
                    "kubelet": {
                      "type": "kubeletService",
                      "clusterDnsServer": "'$CLUSTER_DNS_SERVER'",
                      "extraArgs": {
                         "max-pods": "'$MAX_PODS'",
                         "eviction-hard": "'memory.available\<0.2Gi,nodefs.available\<10%'",
                         "kube-reserved": "'cpu="$KUBE_RESERVED_CPU",memory="$KUBE_RESERVED_MEM"'",
                         "kube-reserved-cgroup": "'/system'",
                         "system-reserved": "'cpu="$SYS_RESERVED_CPU",memory="$SYS_RESERVED_MEM"'",
                         "system-reserved-cgroup": "'/system'"
                      }
                    },
                    "etcd": {
                      "snapshot": false,
                      "type": "etcdService",
                      "extraArgs": {
                        "heartbeat-interval": 500,
                        "election-timeout": 5000
                      }
                    }
                  }
                },
                "name": "'${CLUSTERNAME}'"
              }' \
            )
        echo "CLUSTERRESPONSE: $CLUSTERRESPONSE" >> $LOGFILE

        # Extract clusterid
        CLUSTERID=$(echo $CLUSTERRESPONSE | jq -r .id)
        echo $CLUSTERID > .ra_clusterid
        log_message "CLUSTERID: $CLUSTERID"
        if [ "$CLUSTERID" == "null" ] || [ -z $CLUSTERID ] ; then
            failed_to_install "Extract CLUSTERID " "all"
        fi
        log_message "[end] Extract clusterid "
    fi
}

function show_agent_cmd_old() {
     echo ""  | tee -a $CMDFILE
     if [[ $offline_flg -eq 0 ]];then
         echo "curl -s -O ${SCRIPTS_URL}/clean-rancher-agent.sh"  | tee -a $CMDFILE
     else
         echo "curl -s -OL ${SCRIPTS_URL_ES}/clean-rancher-agent.sh"  | tee -a $CMDFILE
     fi
     echo ""  | tee -a $CMDFILE
     echo "chmod +x clean-rancher-agent.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo "curl -s -OL ${SCRIPTS_URL}/delete-all.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo "chmod +x delete-all.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     if [[ $offline_flg -eq 0 ]];then
         echo "curl -s -O ${SCRIPTS_URL}/configure-sysctl-values.sh"  | tee -a $CMDFILE
     else
         echo "curl -s -OL ${SCRIPTS_URL_ES}/configure-sysctl-values.sh"  | tee -a $CMDFILE
     fi
     echo ""  | tee -a $CMDFILE
     echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo 'sudo -E ./configure-sysctl-values.sh'  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     if [[ $offline_flg -eq 0 ]]; then
         echo "curl -s -O ${SCRIPTS_URL}/install-docker.sh"  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         if [ ! -z $DOCKER_VER ]; then
             echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'  | tee -a $CMDFILE 
             echo ""  | tee -a $CMDFILE
         fi
         if [ ! -z $DOCKER0 ]; then 
             echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "sudo sh -c \"cat /etc/docker/daemon.json | jq '.bip |= \\\"${DOCKER0}\\\"' | sudo tee /etc/docker/daemon.json\"" | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
         fi
         echo './install-docker.sh'  | tee -a $CMDFILE
     else
         echo "scp ericom@${MY_IP}:/etc/docker/daemon.json ."  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         echo "sudo mv -f daemon.json /etc/docker/daemon.json"  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         echo "sudo systemctl restart docker"
     fi
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
}

function show_agent_cmd() {
     echo ""  | tee -a $CMDFILE
     if [[ $offline_flg -eq 0 ]];then
         echo "curl -s -O ${SCRIPTS_URL}/clean-rancher-agent.sh"  | tee -a $CMDFILE
     else
         echo "curl -s -OL ${SCRIPTS_URL_ES}/clean-rancher-agent.sh"  | tee -a $CMDFILE
     fi
     echo ""  | tee -a $CMDFILE
     echo "chmod +x clean-rancher-agent.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo "curl -s -OL ${SCRIPTS_URL}/delete-all.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo "chmod +x delete-all.sh"  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
     if [[ $offline_flg -eq 0 ]]; then
         if [ ! -z $DOCKER0 ]; then 
             echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "sudo sh -c \"cat /etc/docker/daemon.json | jq '.bip |= \\\"${DOCKER0}\\\"' | sudo tee /etc/docker/daemon.json\"" | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "sudo systemctl restart docker"
         fi
    else
         echo "scp ericom@${MY_IP}:/etc/docker/daemon.json ."  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         echo "sudo mv -f daemon.json /etc/docker/daemon.json"  | tee -a $CMDFILE
         echo ""  | tee -a $CMDFILE
         echo "sudo systemctl restart docker"
     fi
     echo ""  | tee -a $CMDFILE
     echo ""  | tee -a $CMDFILE
}

function create_cluster_cmd() {
    if [ -f $CMDFILE ]; then
        log_message "[info] already exist CMDFILE"
        cat ${CMDFILE}
    else
        # create cluster regist token
        curl -s -k "${RANCHERURL}/v3/clusterregistrationtoken" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            --data-binary '{
                "type":"clusterRegistrationToken",
                "clusterId":"'$CLUSTERID'"
              }' \
           >>"$LOGFILE" 2>&1

        # Set role flags
        declare -A roles
        roles[1]='--etcd --controlplane --worker'
        roles[2]='--etcd --controlplane'
        roles[3]='--worker'

        while :
        do
            echo ""
            echo "========================================================================================="
            echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
            echo '※この選択の後、複数台構成にする場合に他のノードで実行するコマンドが画面に表示されます。'
            echo '※必要に応じてコピーの上、他ノードで実行してください。'
            echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
            echo ""
            echo 'このノードに何をセットアップしますか？'
            echo '1) 全て (Rancher, Cluster Management および Ericom Shield)'
            echo '2) Rancher and Cluster Management (Ericom Shield を除く)'
            echo '3) Rancher のみ'
            echo ""
            echo -n "番号で選んでください："
            read ANSWERNO
            echo "AMSWERNO: $ANSWERNO" >> $LOGFILE
            if [[ -z ${roles[$ANSWERNO]} ]]; then
                echo "番号が正しくありません。"
                echo ""
            else
                :
                break
            fi
        done

        # Generate nodecommand
        AGENTCMD=$(curl -s -k "${RANCHERURL}/v3/clusterregistrationtoken?id=${CLUSTERID}" \
            -H 'content-type: application/json' \
            -H "Authorization: Bearer $APITOKEN" \
            | jq -r '.data[].nodeCommand' | head -1)
        if [ "$AGENTCMD" == "null" ] || [ -z "$AGENTCMD" ]; then
            failed_to_install "Extract AGENTCMD " "all"
        fi

        # Concat commands
        DOCKERRUNCMD1="$AGENTCMD ${roles[1]}"
        DOCKERRUNCMD2="$AGENTCMD ${roles[2]}"
        DOCKERRUNCMD3="$AGENTCMD ${roles[3]}"

        echo "" >>"$LOGFILE"
        echo "=================================================================================" >>"$LOGFILE"
        echo "DOCKERRUNCMD1: $DOCKERRUNCMD1" >>"$LOGFILE"
        echo "" >>"$LOGFILE"
        echo "DOCKERRUNCMD2: $DOCKERRUNCMD2" >>"$LOGFILE"
        echo "" >>"$LOGFILE"
        echo "DOCKERRUNCMD3: $DOCKERRUNCMD3" >>"$LOGFILE"
        echo "=================================================================================" >>"$LOGFILE"
        echo "" >>"$LOGFILE"
        log_message "[end] Concat commands"

        # Exec docker command
        log_message "[start] Exec docker command "

        echo ""
        echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★" | tee $CMDFILE
        case $ANSWERNO in
            "1") DOCKERRUNCMD=$DOCKERRUNCMD1
                 echo '下記のコマンドがこのノードで実行されます。(確認用。実行の必要はありません。)' 
                 echo ""
                 echo "$DOCKERRUNCMD1"
                 echo "" 
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'そして、'
                 echo '(【必要に応じて】 下記コマンドを他の(Cluster Management + Worker)ノードで実行してください。)'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD1"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'または、'  | tee -a $CMDFILE
                 echo '(【必要に応じて】 下記コマンドを他の Cluster Management単体 ノードで実行してください。)'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'または、'  | tee -a $CMDFILE
                 echo '(【必要に応じて】 下記コマンドを他の Worker単体 ノードで実行してください。)'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD3"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 ;;
            "2") DOCKERRUNCMD=$DOCKERRUNCMD2
                 echo '下記のコマンドがこのノードで実行されます。(確認用。実行の必要はありません。)'  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'そして、'  | tee -a $CMDFILE
                 echo '(【必要に応じて】 下記コマンドを他の Cluster Management単体 ノードで実行してください。)'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'そして、'  | tee -a $CMDFILE
                 echo '(【必要に応じて】 下記コマンドを他の Worker単体 ノードで実行してください。)'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD3"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 ;;
            "3") DOCKERRUNCMD=""
                 echo '下記コマンドを他の(Cluster Management + Worker)ノードで実行してください。'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD1"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'または、'  | tee -a $CMDFILE
                 echo '下記コマンドを Cluster Management単体 ノードで実行してください。'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo '------------------------------------------------------------'  | tee -a $CMDFILE
                 echo 'そして'  | tee -a $CMDFILE
                 echo '下記コマンドを WORKER単体 ノードで実行してください。'  | tee -a $CMDFILE
                 if [[ $old_flg -eq 1 ]] || [[ "$BRANCH" == "Rel-20.05" ]]; then
                    show_agent_cmd_old
                 else
                    show_agent_cmd
                 fi
                 echo "$DOCKERRUNCMD3"  | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                ;;
        esac
        echo ""  | tee -a $CMDFILE
        echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"  | tee -a $CMDFILE
        echo ""

        $DOCKERRUNCMD >> $LOGFILE 2>&1
    fi
}

function wait_cluster_active() {
    while :
    do
    echo ""
    echo "================================================================================="
    echo 'それぞれのノードでコマンドの実行は完了しましたか？'
    echo -n '先に進んでもよろしいですか？ [y/N]:'
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

    log_message "[waiting] Cluster to active"
    if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
        log_message ".raファイルがありません。"
        failed_to_install "waiting cluster to active" "all"
    fi

    while :
        do
           CLUSTERSTATE=$(curl -s -k "${RANCHERURL}/v3/clusters/${CLUSTERID}" -H "Authorization: Bearer $APITOKEN" | jq -r .state)
           echo "Waiting for state to become active.: $CLUSTERSTATE" | tee -a $LOGFILE
           if [ "active" = "$CLUSTERSTATE" ] ;then
               sleep 5
               CLUSTERSTATE2=$(curl -s -k "${RANCHERURL}/v3/clusters/${CLUSTERID}" -H "Authorization: Bearer $APITOKEN" | jq -r .state)
               if [ "active" = "$CLUSTERSTATE2" ] ;then
                   break
               fi
           fi
           sleep 10
    done
    log_message "[end] Exec docker command "
    echo ""

    while :
    do
    echo ""
    echo "================================================================================="
    echo "【※確認※】 Rancher UI　${RANCHERURL} をブラウザで開き、"
    echo '追加したノードが全てActiveになっていることを確認してください。'
    echo -n '先に進んでもよろしいですか？ [y/N]:'
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
}

function reget_kubeconfig() {
    log_message "[start] Get kubectl config"
    if [ ! -d  ${HOME}/.kube ];then
        mkdir -p ${HOME}/.kube
    else
        sudo -E chown -R $(whoami):$(whoami) ${HOME}/.kube
    fi
    touch  ${HOME}/.kube/config
    chmod 600 ${HOME}/.kube/config
    echo 'waiting....'
    sleep 30

    if [ ! -f .ra_rancherurl ] || [ ! -f .ra_clusterid ] || [ ! -f .ra_apitoken ];then
        log_message ".raファイルがありません。"
        failed_to_install "Get kubectl config" "all"
    fi
    curl -s -k "${RANCHERURL}/v3/clusters/${CLUSTERID}?action=generateKubeconfig" \
        -X POST  \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -r .config > ~/.kube/config
    log_message "[end] Get kubectl config"
    log_message "$(kubectl version)"
}

function wait_for_tiller() {
    log_message "[start]  waiting tiller pod "
    log_message "Waiting for Tiller state to become available.: $TILLERSTATE"
    TILLERSTATE=0
    wait_count=0
    while [ "$TILLERSTATE" -lt 1 ] && ((wait_count < 60)); do
        echo -n .
        sleep 5
        wait_count=$((wait_count + 1))
        TILLERSTATE=$(kubectl -n kube-system get deployments | grep tiller-deploy | grep -c 1/1)
        # if after 150 sec still not available, try to re-install
        if [ wait_count = 30 ]; then
            bash "./install-helm.sh" -f -c
            if [ $? != 0 ]; then
                failed_to_install "re-install helm waiting tiller"
            fi
        fi
    done
    if [ "$TILLERSTATE" -lt 1 ]; then
        failed_to_install "Tiller Deployment is not available"
    else
        echo "ok!"
        log_message "[end]  waiting tiller pod "
        return 0
    fi
}

function add_repo() {
    if [ $stg_flg -eq 1 ] ; then
         BRANCHFLG="-s"
    elif [ $dev_flg -eq 1 ] ; then
         BRANCHFLG="-d"
    else
        BRANCHFLG=""
    fi
    REPO=$(echo $GIT_BRANCH | tr '[:upper:]' '[:lower:]')
    REPO=${REPO//[-.]/}
    export REPO
    log_message "[start] add shield repo"
    curl -s -O  https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/add-shield-repo.sh
    chmod +x add-shield-repo.sh
    if [[ $(grep -c ^ES_PATH add-shield-repo.sh) -eq 0 ]];then
        sed -i -e '/###BH###/a ES_PATH="$HOME/ericomshield"' add-shield-repo.sh 
    fi
    sed -i -e "/^SHIELD_REPO=/s/\/.*/\/${REPO}\"/"  add-shield-repo.sh
    sed -i -e '/^LOGFILE/s/=.*last_deploy.log.*/="\${ES_PATH}\/logs\/last_deploy.log"/'  add-shield-repo.sh
    sed -i -e '/^BRANCH=/s/BRANCH=/#BRANCH=/'  add-shield-repo.sh 
    ./add-shield-repo.sh ${BRANCHFLG} -p ${ERICOMPASS} >> $LOGFILE 2>&1
    log_message "[end] add shield repo"
}

function set_node_label() {
    NODELIST=($(kubectl get node -o json |jq -r .items[].metadata.name))
    adv_flg=0
    for NODENAME in ${NODELIST[@]};
    do
        echo ""
        while :
        do
            if [ $adv_flg -eq 0 ];then
                echo "================================================================================="
                echo ""
                echo "*** {$NODENAME} ***"
                echo ""
                echo '上記ノードにどのShieldコンポーネントを配置しますか？ '
                echo ""
                echo '0) Cluster Management のみ'
                echo '---------------------------------------------------------'
                echo '【System ComponentとBrowserを分ける場合】'
                echo '---------------------------------------------------------'
                echo '2) System Component + Farm-service (management, proxy, elk, farm-services)'
                echo '3) Browser のみ (remort-browsers)'
                echo '---------------------------------------------------------'
                echo '99) Advanced Option'
                echo ""
                echo -n "番号で選択してください："
                read LABELNO
                echo "NODENAME: $NODENAME / LABELNO: $LABELNO" >> $LOGFILE

                case $LABELNO in
                    "0")
                        break
                        ;;
                    "2")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        break
                        ;;
                    "3")
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "99")
                        adv_flg=1
                        continue
                        ;;
                    *)
                        echo "番号が正しくありません。"
                        ;;
                esac
            elif [ $adv_flg -eq 1 ];then
                echo ""
                echo "================================================================================="
                echo ""
                echo "*** {$NODENAME} ***"
                echo ""
                echo '上記ノードにどのShieldコンポーネントを配置しますか？ '
                echo '※オールインワンは正式サポートされません。(1,11,21,31)'
                echo ""
                echo '0) Cluster Management のみ'
                echo '---------------------------------------------------------'
                echo '【オールインワンの場合】'
                echo '---------------------------------------------------------'
                echo '1) 全て (management, proxy, elk, farm-services, remort-browsers)'
                echo '---------------------------------------------------------'
                echo '【System Componentにfarm-serviceを同居させる場合】'
                echo '---------------------------------------------------------'
                echo '2) System Component + Farm-service (management, proxy, elk, farm-services)'
                echo '3) Browser のみ (remort-browsers)'
                echo '---------------------------------------------------------'
                echo '【Browserにfarm-serviceを同居させる場合】'
                echo '---------------------------------------------------------'
                echo '4) System Componentのみ (management, proxy, elk)'
                echo '5) Browser Farm (farm-services, remort-browsers)'
                echo '---------------------------------------------------------'
                echo ''
                echo '///////////////////////////////////////////////////////////'
                echo '【elkを別出し】'
                echo '///////////////////////////////////////////////////////////'
                echo '---------------------------------------------------------'
                echo '11) 全て (management, proxy, farm-services, remort-browsers)'
                echo '19) ELK のみ (elk)'
                echo '---------------------------------------------------------'
                echo '12) System Component + Farm-service (management, proxy, farm-services)'
                echo '13) Browser のみ (remort-browsers)'
                echo '19) ELK のみ (elk)'
                echo '---------------------------------------------------------'
                echo '14) System Componentのみ (management, proxy)'
                echo '15) Browser Farm (farm-services, remort-browsers)'
                echo '19) ELK のみ (elk)'
                echo '---------------------------------------------------------'
                echo ''
                echo '///////////////////////////////////////////////////////////'
                echo '【proxyを別出し】'
                echo '///////////////////////////////////////////////////////////'
                echo '21) 全て (management, elk, farm-services, remort-browsers)'
                echo '29) Proxyのみ(proxy)'
                echo '---------------------------------------------------------'
                echo '22) System Component + Farm-service (management, elk, farm-services)'
                echo '23) Browser のみ (remort-browsers)'
                echo '29) Proxyのみ(proxy)'
                echo '---------------------------------------------------------'
                echo '24) System Componentのみ (management, elk)'
                echo '25) Browser Farm (farm-services, remort-browsers)'
                echo '29) Proxyのみ(proxy)'
                echo '---------------------------------------------------------'
                echo ''
                echo '///////////////////////////////////////////////////////////'
                echo '【elkとproxyを別出し】'
                echo '///////////////////////////////////////////////////////////'
                echo '---------------------------------------------------------'
                echo '31) 全て (management, farm-services, remort-browsers)'
                echo '38) ELK のみ (elk)'
                echo '39) Proxyのみ(proxy)'
                echo '---------------------------------------------------------'
                echo '32) Management + Farm-service (management, farm-services)'
                echo '33) Browser のみ (remort-browsers)'
                echo '38) ELK のみ (elk)'
                echo '39) Proxyのみ(proxy)'
                echo '---------------------------------------------------------'
                echo '34) Managementのみ (management)'
                echo '35) Browser Farm (farm-services, remort-browsers)'
                echo '38) ELK のみ (elk)'
                echo '39) Proxyのみ(proxy)'
                echo ""
                echo "*** {$NODENAME} ***"
                echo ""
                echo -n "番号で選択してください："
                read LABELNO
                echo "NODENAME: $NODENAME / LABELNO: $LABELNO" >> $LOGFILE

                case $LABELNO in
                    "0")
                        break
                        ;;
                    "1")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "2")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        break
                        ;;
                    "3")
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "4")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        break
                        ;;
                    "5")
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "11")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "12")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        break
                        ;;
                    "13")
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "14")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        break
                        ;;
                    "15")
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "19")
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        break
                        ;;
                    "21")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "22")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        break
                        ;;
                    "23")
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "24")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        break
                        ;;
                    "25")
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "29")
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        break
                        ;;
                    "31")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "32")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        break
                        ;;
                    "33")
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "34")
                        kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                        break
                        ;;
                    "35")
                        kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                        kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                        break
                        ;;
                    "38")
                        kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                        break
                        ;;
                    "39")
                        kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                        break
                        ;;
                    *)
                        echo "番号が正しくありません。"
                        ;;
                esac
            fi
        done
    done
}

function check_ha() {
    NUM_MNG=$(kubectl get nodes --show-labels |grep -c management)
    NUM_FARM=$(kubectl get nodes --show-labels |grep -c farm-services)
    NUM_PROXY=$(kubectl get nodes --show-labels |grep -c proxy)

    if [[ $NUM_MNG -eq 3 ]];then
        if [ -f custom-management.yaml ]; then
             if [[ $(grep -c antiAffinity custom-management.yaml) -ge 1 ]];then
                 sed -i -e '/#.*antiAffinity/s/^.*#.*antiAffinity/  antiAffinity/g' custom-management.yaml 
             else
                 sed -i -e '/^    forceNodeLabels/a \  antiAffinity: hard' custom-management.yaml
             fi
        fi
    elif [[ $NUM_MNG -eq 1 ]];then
             sed -i -e '/^\s[^#]*antiAffinity/s/^/#/g' custom-management.yaml
    fi
    if [[ $NUM_FARM -eq 3 ]];then
        if [ -f custom-farm.yaml ]; then
             if [[ $(grep -c antiAffinity custom-farm.yaml) -ge 1 ]];then
                 sed -i -e '/#.*antiAffinity/s/^.*#.*antiAffinity/  antiAffinity/g' custom-farm.yaml 
             else
                 sed -i -e '/^    forceNodeLabels/a \  antiAffinity: hard' custom-farm.yaml
             fi
        fi
    elif [[ $NUM_FARM -eq 1 ]];then
             sed -i -e '/^\s[^#]*antiAffinity/s/^/#/g' custom-farm.yaml
    fi
    if [[ $NUM_PROXY -eq 3 ]];then
        if [ -f custom-proxy.yaml ]; then
             if [[ $(grep -c antiAffinity custom-proxy.yaml) -ge 1 ]];then
                 sed -i -e '/#.*antiAffinity/s/^.*#.*antiAffinity/  antiAffinity/g' custom-proxy.yaml 
             else
                 sed -i -e '/^    forceNodeLabels/a \  antiAffinity: hard' custom-proxy.yaml
             fi
        fi
    elif [[ $NUM_PROXY -eq 1 ]];then
             sed -i -e '/^\s[^#]*antiAffinity/s/^/#/g' custom-proxy.yaml
    fi
}

function check_system_project() {
    log_message "[start] Waiting System Project is Actived"
    while :
    do
        for i in 1 2 3 
        do
            ./shield-status.sh --system -q
            export RET${i}=$?
        done
        if [[ RET1 -eq 0 ]] && [[ RET2 -eq 0 ]] && [[ RET3 -eq 0 ]]; then
            break
        fi
    done
    log_message "[end] Waiting System Project is Actived"
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
    else
        sed -i -e 's/^[^#].*checkSessionLimit/# checkSessionLimit/' custom-proxy.yaml
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

function install_helm() {
    sed -i -e 's/sudo/sudo -E env PATH=$PATH/' install-helm.sh
    if [[ "$BRANCH" == "Rel-20.05" ]] || [[ "$BRANCH" == "Rel-20.03" ]]  || [[ "$BRANCH" == "Rel-20.01" ]] ;then
        if [[ $offline_flg -eq 0 ]]; then
            sed -i -e 's/\$.ES_OFFLINE_REGISTRY_PREFIX.gcr.io\/kubernetes-helm/securebrowsing9/' install-helm.sh
        fi
    fi
    if which helm > /dev/null 2>&1 ; then
        log_message "[info] already installed helm"
        log_message "[start] re-install helm "
        ./install-helm.sh -f -c >> $LOGFILE 2>&1
        log_message "[end] re-install helm "
    else
        log_message "[start] install helm "
        ./install-helm.sh -i >> $LOGFILE 2>&1
        if ! which helm > /dev/null 2>&1 ; then
            failed_to_install "install helm"
        fi
        log_message "[end] install helm "
    fi
}

function mod_cluster_dns() {
    if [ ! -z $CLUSTER_DNS_SERVER ]; then 
        echo  "[dev] START mod cluster dns server address from es_custom_env" >> $LOGFILE
        TARGET1="${ES_PATH}/shield/charts/common/charts/shield-common/values.yaml"
        TARGET2="${ES_PATH}/shield/charts/common/values.yaml"
        sed -i -e "s/^clusterDNSsvc:.*$/clusterDNSsvc: \"${CLUSTER_DNS_SERVER}\"/" ${TARGET1}
        sed -i -e "s/^clusterDNSsvc:.*$/clusterDNSsvc: \"${CLUSTER_DNS_SERVER}\"/" ${TARGET2}
    else
        echo  "[dev] NO mod cluster dns server address" >> $LOGFILE
    fi
}


function check_prepare() {

    if [ -f ${ES_PREPARE} ] ;then
        PREPARE_VER=$(cat ${ES_PREPARE})
        if [[ ${PREPARE_VER} == $S_APP_VERSION ]]; then
            log_message "[info] shield-prepare was executed."
        else
            log_message "[error] バージョンにあったshield-prepare-serversが未実行のようです。"
            failed_to_install "check_prepare"
        fi
    else
        log_message "[error] shield-prepare-serversが未実行のようです。"
        failed_to_install "check_prepare"
    fi
}

function low_res_choice() {
        log_message "[start] resource choice."
        while :
        do
            echo ""
            echo "========================================================================================="
            echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
            echo 'Rel-21.11.816.2以降、高解像度_8Kディスプレイに対応したブラウザコンテナを選択するオプションが追加されています。'
            echo '構築されているBrowserサーバのリソース要件を確認の上、必要に応じて高解像度_8Kディスプレイ対応版を選択してください。'
            echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
            echo ""
            echo '1) 通常インストール'
            echo '2) 高解像度_8Kディスプレイ対応版インストール'
            echo ""
            echo -n "番号で選んでください："
            read ANSWERNORES
            echo "AMSWERNORES: $ANSWERNORES" >> $LOGFILE

            case $ANSWERNORES in
                "1")
                    lowres_flg=1
                    break
                    ;;
                "2")
                    lowres_flg=0
                    break
                    ;;
                *)
                    echo "番号が正しくありません。"
                    ;;
            esac
        done
        echo "lowres_flg: $lowres_flg" >> $LOGFILE
        log_message "[end] resource choice."
}

function change_spare(){
    if [[ $change_spare_flg -eq 1 ]];then
        if [[ $(grep -c securebrowsing9 $ES_PATH/install-shield-from-container.sh) -gt 1 ]];then
            sudo sed -i -e 's/securebrowsing9/securebrowsing/' $ES_PATH/install-shield-from-container.sh
            echo "docker login" $DOCKER_USER
            echo "$ERICOMPASS2" | docker login --username=$DOCKER_USER --password-stdin
        else
            sudo sed -i -e 's/securebrowsing/securebrowsing9/' $ES_PATH/install-shield-from-container.sh
            echo "docker login" $DOCKER_USER_SPARE
            echo "$ERICOMPASS2" | docker login --username=$DOCKER_USER_SPARE --password-stdin
        fi
        if [ $? == 0 ]; then
            echo "Login Succeeded!"
        else
            log_message "Cannot Login to docker, exiting"
            exit -1
        fi
        fin 0
    fi
}



######START#####
log_message "###### START ###########################################################"

#ericomユーザ存在チェック
check_ericom_user

#OS Check
if [ -f /etc/redhat-release ]; then
    OS="RHEL"
else
    OS="Ubuntu"
fi

if [[ $OS == "Ubuntu" ]]; then
    ln_resolv
fi

# check args and set flags
check_args $@
flg_check

change_spare

# version select
select_version

check_prepare

#read custom_env file
if [ -f ${CURRENT_DIR}/.es_custom_env ]; then
    CLUSTER_CIDR=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep cluster_cidr | awk -F'[: ]' '{print $NF}')
    DOCKER0=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep docker0 | awk -F'[: ]' '{print $NF}')
    SERVICE_CLUSTER_IP_RANGE=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep service_cluster_ip_range | awk -F'[: ]' '{print $NF}')
    CLUSTER_DNS_SERVER=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep cluster_dns_server | awk -F'[: ]' '{print $NF}')
    MAX_PODS=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep max-pods | awk -F'[: ]' '{print $NF}')
    DOCKER_VER=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep docker_version | awk -F'[: ]' '{print $NF}')
    BR_REQ_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_mem | awk -F'[: ]' '{print $NF}')
    BR_REQ_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_req_cpu | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_mem | awk -F'[: ]' '{print $NF}')
    BR_LIMIT_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep br_limit_cpu | awk -F'[: ]' '{print $NF}')
    KUBE_RESERVED_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep kube_reserved_cpu | awk -F'[: ]' '{print $NF}')
    KUBE_RESERVED_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep kube_reserved_mem | awk -F'[: ]' '{print $NF}')
    SYS_RESERVED_CPU=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep sys_reserved_cpu | awk -F'[: ]' '{print $NF}')
    SYS_RESERVED_MEM=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep sys_reserved_mem | awk -F'[: ]' '{print $NF}')
fi

#read ra files
if [ -f .ra_rancherurl ] || [ -f .ra_clusterid ] || [ -f .ra_apitoken ];then
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
fi

export BRANCH
export BUILD
log_message "BRANCH: $BRANCH"
log_message "BUILD: $BUILD"
#echo $BRANCH > .es_branch
#echo ${S_APP_VERSION} > .es_version

if [[ "$BRANCH" == "Rel-20.03" ]] || [[ "$BRANCH" == "Rel-20.01.2" ]] || [[ "$BRANCH" == "Rel-19.12.1" ]] || [[ "$BRANCH" == "Rel-19.11" ]] || [[ "$BRANCH" == "Rel-19.09.5" ]] || [[ "$BRANCH" == "Rel-19.09.1" ]]  || [[ "$BRANCH" == "Rel-19.07.1" ]] ;then
    old_flg=1
    if [[ $offline_flg -eq 0 ]]; then
        log_message "###### for OLD version Re-START ###########################################################"
        curl -s  -o ${CURRENT_DIR}/shield-setup-online-old.sh -L ${SCRIPTS_URL}/shield-setup-online-old.sh
        chmod +x ${CURRENT_DIR}/shield-setup-online-old.sh
        ${CURRENT_DIR}/shield-setup-online-old.sh $@ --version $S_APP_VERSION
        rm -f ${CURRENT_DIR}/shield-setup-online-old.sh
        exit 0
    fi
fi

if [[ "$BUILD" == "667" ]]; then
    ses_limit_flg=1
    log_message "ses_limit_flg: $ses_limit_flg"
fi

# 21.11.816.2 resource choice
if [[ "$(echo "$BUILD >= 816.2" | bc)" -eq 1 ]]; then
    low_res_choice
fi

# check ubuntu env
if [[ $OS == "Ubuntu" ]] && [[ $offline_flg -eq 0 ]] ; then
    if [[ $(grep -r --include '*.list' '^deb ' /etc/apt/sources.list* | grep -c universe) -eq 0 ]];then
        sudo add-apt-repository universe
    fi
    sudo apt-mark unhold docker-ce | tee -a $LOGFILE
    apt-unlock
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install libssl1.1 
fi

# install docker
if [[ $offline_flg -eq 0 ]];then
    log_message "[start] install docker"
    curl -s -O ${SCRIPTS_URL_ES}/install-docker.sh
    chmod +x install-docker.sh
    check_docker
    log_message "[end] install docker"
fi

# get&run install-shield-from-container
if [ ls "$ES_PATH/.*" ] &>/dev/null; then
    echo "Keeping dot files"
    mkdir -p /tmp/dot
    mv $ES_PATH/.* /tmp/dot/
fi
curl -s -OL ${SCRIPTS_URL_ES}/install-shield-from-container.sh
sudo chmod +x install-shield-from-container.sh
sudo sed -i -e '/.\/$ES_file_install_shield_local/d' install-shield-from-container.sh
if [[ $spare_flg -eq 1 ]];then
    sudo sed -i -e 's/securebrowsing/securebrowsing9/' install-shield-from-container.sh
    #docker logout
    echo "docker login" $DOCKER_USER_SPARE
    echo "$ERICOMPASS2" | docker login --username=$DOCKER_USER_SPARE --password-stdin
    if [ $? == 0 ]; then
        echo "Login Succeeded!"
    else
        log_message "Cannot Login to docker, exiting"
        exit -1
    fi
else
    #docker logout
    echo "docker login" $DOCKER_USER
    echo "$ERICOMPASS2" | docker login --username=$DOCKER_USER --password-stdin
    if [ $? == 0 ]; then
        echo "Login Succeeded!"
    else
        log_message "Cannot Login to docker, exiting"
        exit -1
    fi    
fi
if [[ $offline_flg -eq 1 ]];then
    sudo -E ./install-shield-from-container.sh -p $ERICOMPASS2 --version "Rel-${S_APP_VERSION}" --registry $REGISTRY_OVA | tee -a $LOGFILE
else
    sudo -E ./install-shield-from-container.sh -p $ERICOMPASS2 --version "Rel-${S_APP_VERSION}" | tee -a $LOGFILE    
fi
sudo -E chown -R $(whoami):$(whoami) ${ES_PATH}
sudo -E chown -R $(whoami):$(whoami) ${CURRENT_DIR}/.docker
chmod +x -R ${ES_PATH}/*.sh
if [ -d "/tmp/dot" ] &>/dev/null; then
    mv /tmp/dot/.* $ES_PATH
    sudo rm -rf /tmp/dot
fi

# get operation scripts
get_scripts

# mod cluster dns address from es_custom_env
mod_cluster_dns

# image replace for yaml HotFix
if [[ "$BUILD" == "758" ]]; then
    log_message "[start] fix for 21.04.758"
    sed -i -e 's/es-system-configuration:210426-Rel-21.04/es-system-configuration:210715-Rel-21.04/g' ${ES_PATH}/shield/values.yaml
    sed -i -e 's/icap-server:210426-Rel-21.04/icap-server:210819-Rel-21.04/g' ${ES_PATH}/shield/values.yaml
    log_message "[end] fix for 21.04.758"
fi
if [[ "$BRANCH" == "Rel-23.05" ]]; then
    log_message "[start] fix for 23.05"
    sed -i -e '/esRemoteBrowser:/c\    esRemoteBrowser: securebrowsing\/shield-cef:230718-Rel-23.05' ${ES_PATH}/shield/values.yaml
    #shield-cef:OnPrem23.05-230626-16.44
    sed -i -e '/esIcap:/c\    esIcap: securebrowsing\/icap-server:23.05-230927-SHIELD-19596' ${ES_PATH}/shield/values.yaml
    #icap-server:230329-07.17-2154
    log_message "[end] fix for 23.05"
elif [[ "$BRANCH" == "Rel-22.08" ]]; then
    log_message "[start] fix for 22.08"
    sed -i -e '/esLogStash:/c\    esLogStash: securebrowsing\/es-logstash:230108-OnPrem-22.08' ${ES_PATH}/shield/values.yaml
    log_message "[end] fix for 22.08"
elif [[ "$BRANCH" == "Rel-21.11" ]]; then
    log_message "[start] fix for 21.11"
    sed -i -e '/esLogStash:/c\    esLogStash: securebrowsing\/es-logstash:230111-Rel-21.11' ${ES_PATH}/shield/values.yaml
    log_message "[end] fix for 21.11"
elif [[ "$BRANCH" == "Rel-21.04" ]]; then
    log_message "[start] fix for 21.04"
    sed -i -e '/esLogStash:/c\    esLogStash: securebrowsing\/es-logstash:230111-Rel-21.04' ${ES_PATH}/shield/values.yaml
    log_message "[end] fix for 21.04"
elif [[ "$BRANCH" == "Rel-21.01" ]]; then
    log_message "[start] fix for 21.01"
    sed -i -e '/esLogStash:/c\    esLogStash: securebrowsing\/es-logstash:230111-Rel-21.01' ${ES_PATH}/shield/values.yaml
    log_message "[end] fix for 21.01"
fi

# br_res fix for 2305~ farm yaml
if [[ $(grep -c rb_resources custom-farm.yaml) != 0 ]]; then
    sed -i  -e 's/^#.*rb_resources/  rb_resources/' custom-farm.yaml
    sed -i  -e 's/^#.*rb_limits/    rb_limits/' custom-farm.yaml
    sed -i  -e 's/^#.*cpu:.*/      cpu: 4/' custom-farm.yaml
    sed -i  -e 's/^#.*memory:.*/      memory: 3Gi/' custom-farm.yaml
else
    sed -i -z 's/farm-services:\n/farm-services:\n  rb_resources:\n    rb_limits:\n      cpu: 4\n      memory: 3Gi\n/g' custom-farm.yaml
fi



#low resource
if [[ "$BUILD" == "934-3" ]] || [[ "$(echo "$BUILD > 934" | bc)" -eq 1 ]]; then
    sed -i -e '/remoteBrowserLowMemMode/d' ~/ericomshield/custom-farm.yaml
    sed -i -e 's/farm-services:.*\n/farm-services:\n/g' ~/ericomshield/custom-farm.yaml
    if [ $lowres_flg -eq 1 ]; then
        log_message "[start] fix for low resources"
        sed -z -i 's/farm-services:\n/farm-services:\n  remoteBrowserLowMemMode: true\n/g' ${ES_PATH}/custom-farm.yaml
        log_message "[end] fix for low resources"
    elif [ $lowres_flg -eq 0 ]; then
        sed -z -i 's/farm-services:\n/farm-services:\n  remoteBrowserLowMemMode: false\n/g' ${ES_PATH}/custom-farm.yaml
    fi    
else
    if [ $lowres_flg -eq 1 ]; then
        log_message "[start] fix for low resources"
        if [[ "$(echo "$BUILD < 921" | bc)" -eq 1 ]];then
            sed -i -e 's/shield-cef:.*/shield-cef:Rel-21.11-3840x2160/g' ${ES_PATH}/shield/values.yaml
        elif [[ "$(echo "$BUILD >= 921" | bc)" -eq 1 ]];then
            sed -i -e 's/shield-cef:.*/shield-cef:Rel-22.06-11.08-3840x2160/g' ${ES_PATH}/shield/values.yaml
            #shield-cef:220804-08.48-1141
        fi
        log_message "[end] fix for low resources"
    fi
fi

#if [[ "$BUILD" == "816.2" ]]; then
#    log_message "[start] fix for 21.11.816.2 votiro"
#    sed -i -e 's/es-system-settings:211219-Rel-21.11/es-system-settings:220214-11.30/g' ${ES_PATH}/shield/values.yaml
#    sed -i -e 's/shield-admin:211219-Rel-21.11/shield-admin:220213-14.06/g' ${ES_PATH}/shield/values.yaml
#    sed -i -e 's/shield-cdr-dispatcher:211219-Rel-21.11/shield-cdr-dispatcher:220213-14.02/g' ${ES_PATH}/shield/values.yaml
#    log_message "[end] fix for 21.11.816.2 votiro"
#fi

#update or deploy NOT offline
    if [ $update_flg -eq 1 ] || [ $deploy_flg -eq 1 ]; then
        chmod 600 ${HOME}/.kube/config
        run_rancher
        install_helm
        if [[ "$BRANCH" == "Rel-20.05" ]]; then
            wait_for_tiller
        fi
        if [[ $stg_flg -eq 1 ]] || [[ $dev_flg -eq 1 ]]; then
            add_repo
        fi
        #check_system_project
        check_system_project
        deploy_shield
        move_to_project
        check_start
        fin 0
    fi

# install jq
log_message "[start] install jq"
if ! which jq > /dev/null 2>&1 ;then
    if [[ $OS == "Ubuntu" ]]; then
        apt-unlock
        sudo apt-get install -y -qq jq >>"$LOGFILE" 2>&1
    elif [[ $OS == "RHEL" ]]; then
        sudo yum -y -q install epel-release
        sudo yum -y -q install jq >>"$LOGFILE" 2>&1
    fi
    if ! which jq > /dev/null 2>&1 ;then
        failed_to_install "install jq" "ver"
    fi
else
    log_message "jq is already installed"
fi
log_message "[end] install jq"

# set MY_IP
choose_network_interface

#docker daemon.json modify
if [ ! -z $DOCKER0 ]; then 
    echo "DOCKER0: $DOCKER0" >> $LOGFILE
    if [ ! -d /etc/docker/ ];then
        sudo mkdir -p /etc/docker
    fi
    if [[ $offline_flg -eq 1 ]];then
        sudo tee /etc/docker/daemon.json <<EOF >/dev/null
{
  "insecure-registries": ["$REGISTRY_OVA"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "bip": "${DOCKER0}"
}
EOF
    else
        sudo tee /etc/docker/daemon.json <<EOF >/dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "bip": "${DOCKER0}"
}
EOF
    fi

    if [ -x "/usr/bin/docker" ]; then
        sudo systemctl restart docker
    fi
fi

### install-shield-local.sh
##################      MAIN: EVERYTHING STARTS HERE: ##########################
log_message "***************     Ericom Shield Installer ..."

if [ ! -x "/usr/bin/docker" ]; then
   log_message "FATAL: Docker is not installed exiting..."
   fin 1
fi

if [ ! -f ~/.kube/config ] || [ $(cat ~/.kube/config | wc -l) -le 1 ]; then

    #1.  Run configure-sysctl-values.sh
    log_message "[start] setting sysctl-values"
    sudo -E ./configure-sysctl-values.sh | tee -a $LOGFILE
    if [ $? != 0 ]; then
           failed_to_install "install sysctl-values"
    fi
    log_message "[end] setting sysctl-values"
    step

    #2.  install-kubectl.sh
    if which kubectl > /dev/null 2>&1 ; then
        log_message "[info] already installed kubectl"
    else
        if [[ $offline_flg -eq 0 ]]; then
            log_message "[start] install kubectl "
            if [[ $OS == "Ubuntu" ]]; then
                sudo rm -f "/etc/apt/sources.list.d/kubernetes.list"
            elif  [[ $OS == "RHEL" ]]; then
                sudo rm -f "/etc/yum.repos.d/kubernetes.repo"
            fi
            ./install-kubectl.sh  >> $LOGFILE 2>&1
            if ! which kubectl > /dev/null 2>&1 ; then
                failed_to_install "install kubectl"
            fi
            log_message "[end] install kubectl "
        else
           failed_to_install "dose not exist kubectl"
        fi
    fi
    step

    ## set Rancer URL & ports(KKA Original)
    log_message "[start] set Rancer URL & ports"
    RANCHERHTTPSPORT="8443"
    RANCHERURL="https://${MY_IP}:${RANCHERHTTPSPORT}"
    echo $RANCHERURL > .ra_rancherurl
    echo "================================================================================="
    log_message "[set] RANCHERURL: $RANCHERURL"
    echo "================================================================================="
    log_message "[end] set Rancer URL & ports"

    #4.  run-rancher.sh
    run_rancher

    #5.  install-rancher-cli
    log_message "[start] install rancher cli"
    sudo -E -H ./install-rancher-cli.sh
    if [ $? != 0 ]; then
       failed_to_install "install rancher cli"
    fi
    log_message "[end] install rancher cli"
    step

    #6.  create-cluster.sh
    log_message "[start] create cluster"
    sed -i -e '/^wait_for_rancher$/a sleep 5' create-cluster.sh
#    sed -i -e 's/^create_rancher_cluster/ls dummy >\/dev\/null 2>\/dev\/null/' create-cluster.sh
    sed -i -e '/^configure_rancher_generate_token$/a exit' create-cluster.sh
    sudo -E ./create-cluster.sh
    if [ $? != 0 ]; then
       failed_to_install "create cluster"
    fi
    pre_create_cluster
    create_cluster
    create_cluster_cmd
    log_message "[end] create cluster"
    step

    # waiting cluster to active
    wait_cluster_active
fi

# Re Get kubectl config
reget_kubeconfig

if [ ! -f ~/.kube/config ] || [ $(cat ~/.kube/config | wc -l) -le 1 ]; then
    echo
    echo "Please Create your cluster, Set Labels, Set ~/.kube/config and come back...."
    exit 0
fi

#7. install-helm.sh
install_helm
step

# Wait until Tiller is available
if [[ "$BRANCH" == "Rel-20.05" ]]; then
    wait_for_tiller
    step
fi

#add repo for NOT Offline
if [[ $offline_flg -eq 0 ]]; then
    if [[ $stg_flg -eq 1 ]] || [[ $dev_flg -eq 1 ]]; then
        add_repo
    fi
    step
fi

# set node label
set_node_label

#check_system_project
check_system_project

#6. Deploy Shield
deploy_shield

# get Default project id
move_to_project

check_start

echo $BRANCH > .es_branch
echo ${S_APP_VERSION} > .es_version

#All fin
fin 0
