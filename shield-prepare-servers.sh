#!/bin/bash

####################
### K.K. Ashisuto
### VER=20210730c
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

LOGFILE="${ES_PATH}/logs/install.log"
TEMP_ANSIBLE="/tmp/shield-prepare-servers.log"
BRANCH="Rel"
ERICOMPASS="Ericom123$"
ERICOMPASS2="Ericom98765$"
CLUSTERNAME="shield-cluster"
STEP_BY_STEP="false"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/develop"
SCRIPTS_URL_PREPARE="https://ericom-tec.ashisuto.co.jp/shield-prepare-servers"
SCRIPTS_URL_ES="https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Kube/scripts"


# SSH_ASKPASSで設定したプログラム(本ファイル自身)が返す内容
if [ -n "$PASSWORD" ]; then
  cat <<< "$PASSWORD"
  exit 0
fi

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

if [ -f ${ES_PATH}/.es_offline ] ;then
    offline_flg=1
else
    offline_flg=0
fi

function usage() {
    echo "USAGE: $0 "
    ### for Develop only
    # [ーv | --version <Chart version>]
    ##
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
    log_message "An error occurred during the shield-prepare-servers.sh: $1, exiting"
    fin 1
}

function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}

function check_docker-ce(){
    cd $CURRENT_DIR
    echo -n 'ericomユーザのパスワードを入力: '
    read ERI_PASS
    # SSH_ASKPASSで呼ばれるシェルにパスワードを渡すために変数を設定
    export PASSWORD=$ERI_PASS

    # SSH_ASKPASSに本ファイルを設定
    export SSH_ASKPASS=$0
    # ダミーを設定
    export DISPLAY=dummy:0

    TARGET_LIST=""
    while [ "$1" != "" ]
    do
        RET_NUM=$(exec setsid ssh -t -oStrictHostKeyChecking=no ericom@$1 'echo `dpkg -l | grep docker-ce | grep -ce ii -ce hi`')
        if [[ $? -ne 0 ]];then
            log_message "[ERROR] 接続に失敗しました。ericomユーザのパスワード、またはノードへのssh権限をご確認ください。"
            fin 1
        fi

        RET_NUM=`echo ${RET_NUM} | sed -e "s/[\r\n]\+//g"`
        if [[ $RET_NUM -gt 0 ]];then
            TARGET_LIST+=" $1"
        fi
        shift
    done

    if [[ $(dpkg -l | grep docker-ce | grep -ce ii -ce hi) -gt 0 ]];then
        TARGET_LIST+=" 127.0.0.1"
    fi

    echo "TARGET_LIST: ${TARGET_LIST}"
    if [[ ${TARGET_LIST} != "" ]];then
        log_message "[WARN] docker-ce が検出されました。"
        echo "docker-ce をアンインストールして、再起動します。"
        echo "再起動後、改めてshield-prepare-servers.shを実行してください。"
        echo ""
        while :
        do
            echo -n 'よろしいですか？ [y/N]:'
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

        for t in $TARGET_LIST ;
        do
            echo "T: $t"
            log_message "[start] delete docker-ce on $t"
            if [[ "$t" == "127.0.0.1" ]];then
                RET=$(exec setsid ssh -t -oStrictHostKeyChecking=no ericom@$t "sudo systemctl disable --now docker && sudo apt-get -y --allow-change-held-packages remove docker-ce* containerd.io && sudo systemctl unmask docker.service && sudo systemctl unmask docker.socket")
            else
                RET=$(exec setsid ssh -t -oStrictHostKeyChecking=no ericom@$t "sudo systemctl disable --now docker && sudo apt-get -y --allow-change-held-packages remove docker-ce* containerd.io && sudo systemctl unmask docker.service && sudo systemctl unmask docker.socket && sudo reboot")
            fi
            echo $RET
        done
        log_message "[end] delete docker-ce"
        change_dir
        echo "対象ノードが全て再起動されたことを確認し、改めてshield-prepare-servers.shを実行してください。"
        if [[ `echo "$TARGET_LIST" | grep '127.0.0.1'` ]] ; then 
            echo ""
            echo "このノードも再起動します。"
            echo ""
            while :
            do
                echo ""
                echo -n 'よろしいですか？ [y/N]:'
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
            sudo reboot
        fi
        fin 1
    fi
}

function get_shield-prepare-servers() {
    log_message "[start] Geting shield-prepaer-servers."
    if [[ -f ${ES_PATH}/shield-prepare-servers ]]; then
        if [ ! -e ./org/ ];then
            mkdir org
        fi
        mv -f ./shield-prepare-servers ./org/shield-prepare-servers
    fi
    #curl -sfo ${ES_PATH}/shield-prepare-servers ${SCRIPTS_URL_PREPARE}/Rel-${S_APP_VERSION}/shield-prepare-servers || curl -sfo ${ES_PATH}/shield-prepare-servers ${SCRIPTS_URL_PREPARE}/master/shield-prepare-servers
    curl -sfo ${ES_PATH}/shield-prepare-servers ${SCRIPTS_URL_PREPARE}/Rel-21.04.758/shield-prepare-servers
    chmod +x ${ES_PATH}/shield-prepare-servers
    log_message "[end] Geting shield-prepaer-servers."
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
    ver_flg=0
    S_APP_VERSION=""

    echo "args: $@" >> $LOGFILE

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--pre-use" ]; then
            pre_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
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
    echo "ver_flg: $ver_flg" >> $LOGFILE
    echo "S_APP_VERSION: $S_APP_VERSION" >> $LOGFILE
    echo "////////////////////////////////" >> $LOGFILE
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
        BUILD=${BUILD[2]}
        GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
        if [[ $GIT_BRANCH == "Rel-" ]];then
            GIT_BRANCH="Rel-${GBUILD}"
        fi
        log_message "現在インストールされているバージョン: ${GIT_BRANCH}_Build:${BUILD}"
    fi
    echo "=================================================================="


    if [ -f "$ES_PATH/.es_prepare" ]; then
        log_message "実行済みのshield-prepare-serversバージョン: $(cat $ES_PATH/.es_prepare)"
    else
        #log_message "[error] shield-prepare-serversが未実行のようです。"
        #echo "=================================================================="
        #failed_to_install "select_version check_prepare"
        #for shield-prepare-servers.sh
        log_message "[info] shield-prepare-serversは未実行。"
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
            BUILD=${BUILD[2]}
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
                    GBUILD=${BUILD[0]}.${BUILD[1]}
                    BUILD=${BUILD[2]}
                    GIT_BRANCH="Rel-$(curl -sL ${SCRIPTS_URL}/k8s-rel-ver-git.txt | grep ${BUILD} | awk '{print $2}')"
                    if [[ $GIT_BRANCH == "Rel-" ]];then
                        GIT_BRANCH="Rel-${GBUILD}"
                    fi
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
        BUILD=()
        BUILD=(${S_APP_VERSION//./ })
        CHKBRANCH=${BUILD[0]}${BUILD[1]}
        GBUILD=${BUILD[0]}.${BUILD[1]}
        BUILD=${BUILD[2]}
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
    BUILD=${BUILD[2]}
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

function shield_prepare_servers() {
    if [ -f $TEMP_ANSIBLE ];then
        rm -f $TEMP_ANSIBLE
    fi
    echo ""
    echo "他のノードに対する事前処理を行います。"
    echo "自ノードに対する事前処理は別のノードから実行してください。"
    echo ""
    echo "====================================================="
    echo '追加するノードのIPアドレスを半角スペースで区切って入力してください。'
    echo -n '    [ex:) 192.168.100.22　192.168.100.33]: '
    read ANSWERips

    check_docker-ce ${ANSWERips}

    sudo ${ES_PATH}/shield-prepare-servers -u ericom ${ANSWERips} | tee $TEMP_ANSIBLE
    echo ""
    echo "================================================================================="
}


function check_shield_prepare_servers() {
    FAILED_CNT=$(grep failed= $TEMP_ANSIBLE | grep -cv failed=0)
    UNREACH_CNT=$(grep unreachable= $TEMP_ANSIBLE | grep -cv unreachable=0)
    if [[ $FAILED_CNT -ne 0 ]] || [[ $UNREACH_CNT -ne 0 ]]; then
        log_message "実行時にエラーが検出されました。ノード間通信・prepare-servers.shによる事前準備、パスワードを確認の上、再度実行を試みてください。"
        log_message "パスワードに間違いがない状態でエラーが継続する場合には、サポートに問い合わせをしてください。"
        failed_to_install "check shield-prepare-servers"
    fi
}

######START#####
log_message "###### START ###########################################################"

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

# version select
select_version

export BRANCH
export BUILD
echo $BRANCH > .es_branch
log_message "BRANCH: $BRANCH"
log_message "BUILD: $BUILD"


# get operation scripts
get_shield-prepare-servers

shield_prepare_servers
check_shield_prepare_servers

#All fin
echo ${S_APP_VERSION} > .es_prepare
fin 0
