#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200109a
####################

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
CMDFILE="command.txt"
BRANCH="Rel"
ERICOMPASS="Ericom123$"
CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield/git/develop"

if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
elif [ -f ${ES_PATH}/.es_branch ]; then
    BRANCH=$(cat ${ES_PATH}/.es_branch)
fi


function usage() {
    echo "USAGE: $0 [--pre-use] [--update] [--deploy] [--get-custom-yaml] [--uninstall] [--delete-all]"
    echo "    --pre-use         : 日本での正式リリースに先立ち、1バージョン先のものをβ扱いでご利用いただけます。"
    echo "                        ※ただし、先行利用バージョンについては、一切のサポートがございません。"
    echo "    --update          : Shield のバージョンを変更できます。"
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
    exit 0
    ### for Develop only
    # [--staging | --dev] [--version <Chart version>]
    ##
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

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
    uninstall_flg=0
    deleteall_flg=0
    S_APP_VERSION=""

    echo "args: $1" >> $LOGFILE

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--pre-use" ]; then
            pre_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
        elif [ "$1" == "--update" ] || [ "$1" == "--Update" ] ; then
            update_flg=1
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
    echo "uninstall_flg: $uninstall_flg" >> $LOGFILE
    echo "deleteall_flg: $deleteall_flg" >> $LOGFILE
    echo "S_APP_VERSION: $S_APP_VERSION" >> $LOGFILE
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

    #uninstall
    if [ $uninstall_flg -eq 1 ]; then
        if  [ $BRANCH == "Rel" ] ; then
            export BRANCH="Staging"
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
            export BRANCH="Staging"
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
        fin 0
    fi
}

function select_version() {
    CHART_VERSION=""
    if which helm >/dev/null 2>&1 ;then
        VERSION_DEPLOYED=$(helm list shield-management 2>&1 | awk '{ print $10 }')
        VERSION_DEPLOYED=$(echo ${VERSION_DEPLOYED} | sed -e "s/[\r\n]\+//g")
    elif [ -f ".es_version" ]; then
        VERSION_DEPLOYED=$(cat .es_version)
    elif [ -f "$ES_PATH/.es_version" ]; then
        VERSION_DEPLOYED=$(cat $ES_PATH/.es_version)
    fi
    echo "=================================================================="
    if [ -z $VERSION_DEPLOYED ]; then
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
        cd ${ES_PATH}
        log_message "pwd: $(pwd)"        
        log_message "[end] change dir"
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
        sudo usermod -aG docker "$USER"
        log_message "[end] add group"
        rm -f .es_version
        rm -f .es_branch
        fin 0
    fi

    log_message "[end] check group"
}

function delete_ver() {
    log_message "[start] delete version file"
    rm -f .es_version
    rm -f .es_branch
    log_message "[end] delete version file"
}

function uninstall_shield() {
    log_message "[start] uninstall shield"

    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/delete-shield.sh
    chmod +x delete-shield.sh
    ./delete-shield.sh -s | tee -a $LOGFILE
    rm -f .es_version
    rm -f .es_branch

    log_message "[end] uninstall shield"
}

function delete_all() {
    log_message "[start] deletel all object"

    curl -s -OL ${SCRIPTS_URL}/delete-all.sh
    chmod +x delete-all.sh
    ./delete-all.sh | tee -a $LOGFILE

    log_message "[end] deletel all object"

    echo '------------------------------------------------------------'
    echo "(【必要に応じて】, 下記を他のノードでも実行してください。)"
    echo ""
    echo "curl -s -OL ${SCRIPTS_URL}/delete-all.sh"
    echo 'chmod +x delete-all.sh'
    echo './delete-all.sh'
    echo ""
    echo '------------------------------------------------------------'
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

function check_ha() {
    NUM_MNG=$(kubectl get nodes --show-labels |grep -c management)
    NUM_FARM=$(kubectl get nodes --show-labels |grep -c farm-services)

    if [[ $NUM_MNG -eq 3 ]];then
        if [ -f custom-management.yaml ]; then
             if [[ $(grep -c antiAffinity custom-management.yaml) -eq 1 ]];then
                 sed -i -e '/#.*antiAffinity/s/#//g' custom-management.yaml
             else
                 sed -i -e '/^    forceNodeLabels/a \  antiAffinity: hard' custom-management.yaml
             fi
        fi
    elif [[ $NUM_MNG -eq 1 ]];then
             sed -i -e '/^\s.*antiAffinity/s/^/#/g' custom-management.yaml
    fi
    if [[ $NUM_FARM -eq 3 ]];then
        if [ -f custom-farm.yaml ]; then
             if [[ $(grep -c antiAffinity custom-farm.yaml) -eq 1 ]];then
                 sed -i -e '/#.*antiAffinity/s/#//g' custom-farm.yaml
             else
                 sed -i -e '/^    forceNodeLabels/a \  antiAffinity: hard' custom-farm.yaml
             fi
        fi
    elif [[ $NUM_MNG -eq 1 ]];then
             sed -i -e '/^\s.*antiAffinity/s/^/#/g' custom-farm.yaml
    fi
}

function deploy_shield() {
    log_message "[start] deploy shield"

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

    if [ ! -f custom-farm.yaml ] || [ $yamlget_flg -eq 1 ]; then
        curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/custom-farm.yaml
    fi
    if [ ! -f custom-management.yaml ] || [ $yamlget_flg -eq 1 ]; then
        curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/custom-management.yaml
    fi
    if [ ! -f custom-proxy.yaml ] || [ $yamlget_flg -eq 1 ]; then
        curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/custom-proxy.yaml
    fi
    if [ ! -f custom-values-elk.yaml ] || [ $yamlget_flg -eq 1 ]; then
        curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/custom-values-elk.yaml
    fi

    if [ $spell_flg -ne 1 ]; then
        sed -i -e 's/^#farm-services/farm-services/' custom-farm.yaml
        sed -i -e 's/^#.*DISABLE_SPELL_CHECK/  DISABLE_SPELL_CHECK/' custom-farm.yaml
    fi
    if [ $ses_limit_flg -ne 1 ]; then
        sed -i -e 's/^#shield-proxy/shield-proxy/' custom-proxy.yaml
        sed -i -e 's/^#.*checkSessionLimit/  checkSessionLimit/' custom-proxy.yaml
    fi

    if [ $deploy_flg -eq 1 ]; then
        sed -i -e '/Same Versions/{n;s/exit/#exit/}' deploy-shield.sh
    fi

    VERSION_REPO=$S_APP_VERSION
    export VERSION_REPO

    # check number of management and farm
    check_ha

    log_message "[start] deploieng shield"
    ./deploy-shield.sh | tee -a $LOGFILE
    log_message "[end] deploieng shield"

    #curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/deploy-shield.sh

    log_message "[end] deploy shield"
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
    log_message "[start] rollback"
    if [ "$2" == "es" ]; then
        uninstall_shield
    elif [ "$2" == "all" ]; then
        delete_all
    elif [ "$2" == "ver" ]; then
        delete_ver
    fi
    log_message "[end] rollback"
    fin 1
}

function choose_network_interface() {
    local INTERFACES=($(find /sys/class/net -type l -not -lname '*virtual*' -printf '%f\n'))
    local INTERFACE_ADDRESSES=()
    local OPTIONS=()

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

function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}

function move_to_project() {
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

    curl -s -O  https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh

    if ! which docker > /dev/null 2>&1 ; then
        failed_to_install "install_docker" "ver"
    fi
}

function get_scripts() {
    log_message "[start] get operation scripts"
    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/clean-rancher-agent.sh
    chmod +x clean-rancher-agent.sh

    curl -s -OL ${SCRIPTS_URL}/delete-all.sh
    chmod +x delete-all.sh

    curl -s -OL ${SCRIPTS_URL}/shield-nodes.sh
    chmod +x shield-nodes.sh

    curl -s -OL ${SCRIPTS_URL}/shield-start.sh
    chmod +x shield-start.sh

    curl -s -OL ${SCRIPTS_URL}/shield-stop.sh
    chmod +x shield-stop.sh

    curl -s -o ${CURRENT_DIR}/shield-update.sh -L ${SCRIPTS_URL}/shield-update.sh
    chmod +x ${CURRENT_DIR}/shield-update.sh
  
    if [ ! -e ./sup/ ];then
        mkdir sup
    fi
    curl -s -o ./sup/shield-sup.sh -L ${SCRIPTS_URL}/sup/shield-sup.sh
    chmod +x ./sup/shield-sup.sh

    curl -s -o ./sup/getlog.sh -L ${SCRIPTS_URL}/sup/getlog.sh
    chmod +x ./sup/getlog.sh

    log_message "[end] get operation scripts"
}


######START#####
log_message "###### START ###########################################################"

#OS Check
if [ -f /etc/redhat-release ]; then
    OS="RHEL"
else
    OS="Ubuntu"
fi

# check args and set flags
check_args $@

select_version

#read custom_env file
if [ -f ${CURRENT_DIR}/.es_custom_env ]; then
    CLUSTER_CIDR=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep cluster_cidr | awk -F'[: ]' '{print $NF}')
    DOCKER0=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep docker0 | awk -F'[: ]' '{print $NF}')
    SERVICE_CLUSTER_IP_RANGE=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep service_cluster_ip_range | awk -F'[: ]' '{print $NF}')
    CLUSTER_DNS_SERVER=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep cluster_dns_server | awk -F'[: ]' '{print $NF}')
    MAX_PODS=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep max-pods | awk -F'[: ]' '{print $NF}')
    DOCKER_VER=$(cat ${CURRENT_DIR}/.es_custom_env | grep -v '^\s*#' | grep docker_version | awk -F'[: ]' '{print $NF}')
fi

#read ra files
if [ -f .ra_rancherurl ] || [ -f .ra_clusterid ] || [ -f .ra_apitoken ];then
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
fi

export BRANCH
echo $BRANCH > .es_branch
log_message "BRANCH: $BRANCH"

# get operation scripts
get_scripts

#update or deploy
if [ $update_flg -eq 1 ] || [ $deploy_flg -eq 1 ]; then
    #if [ $update_flg -eq 1 ];then
    #log_message "[start] stopping shield"
    #       bash ./shield-stop.sh
    #log_message "[end] stopping shield"
    #fi
    add_repo
    deploy_shield
    #if [ $deploy_flg -eq 1 ]; then
    move_to_project
    #fi
    fin 0
fi

# set MY_IP
choose_network_interface

# set sysctl
log_message "[start] setting sysctl-values"
curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh
chmod +x configure-sysctl-values.sh
sudo ./configure-sysctl-values.sh | tee -a $LOGFILE
log_message "[end] setting sysctl-values"

# check ubuntu env
if [[ $OS == "Ubuntu" ]]; then
    if [[ $(grep -r --include '*.list' '^deb ' /etc/apt/sources.list* | grep -c universe) -eq 0 ]];then
        sudo add-apt-repository universe
    fi
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install libssl1.1 
fi

# install docker
if [ ! -z $DOCKER0 ]; then 
    echo "DOCKER0: $DOCKER0" >> $LOGFILE
    if [ ! -d /etc/docker/ ];then
        sudo mkdir -p /etc/docker
    fi
    sudo sh -c "echo '{\"bip\": \"${DOCKER0}\"}' > /etc/docker/daemon.json"
fi
log_message "[start] install docker"
curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh
chmod +x install-docker.sh

check_docker

log_message "[end] install docker"

# docker guroup check
check_group

# install jq
log_message "[start] install jq"
if ! which jq > /dev/null 2>&1 ;then
    if [[ $OS == "Ubuntu" ]]; then
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

## set Rancer URL & ports
log_message "[start] set Rancer URL & ports"
RANCHERHTTPSPORT="8443"
RANCHERURL="https://${MY_IP}:${RANCHERHTTPSPORT}"
echo $RANCHERURL > .ra_rancherurl
echo "================================================================================="
log_message "[set] RANCHERURL: $RANCHERURL"
echo "================================================================================="
log_message "[end] set Rancer URL & ports"

# run rancher
if [[ "pong" == $(curl -s -k "${RANCHERURL}/ping") ]]; then
    log_message "[info] already start rancher"
else
    log_message "[start] run rancher"
    curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/run-rancher.sh
    chmod +x run-rancher.sh
    ./run-rancher.sh | tee -a $LOGFILE
    log_message "[end] run rancher"

    # wait launched rancher
    log_message "[waiting] launched rancher"
    while ! curl -s -k "${RANCHERURL}/ping"; do sleep 3; done
    echo ""
    sleep 1
    # Rancer first Login
    for i in `seq 5`
    do
        LOGINRESPONSE=$(curl -s -k "${RANCHERURL}/v3-public/localProviders/local?action=login" \
            -H 'content-type: application/json' \
            --data-binary '{
                "username":"admin",
                "password":"admin"
              }' \
            )
        echo "LOGINRESPONSE: $LOGINRESPONSE" >> $LOGFILE
        if [ $(echo $LOGINRESPONSE | grep -c error) -eq 0  ]; then
            break
        fi
    done
    LOGINTOKEN=$(echo $LOGINRESPONSE | jq -r .token)
    log_message "LOGINTOKEN: $LOGINTOKEN"
    if [ "$LOGINTOKEN" == "null" ] || [ -z $LOGINTOKEN ]; then
        failed_to_install "get LOGINTOKEN " "all"
    fi

    # Change password
    while :
    do
        echo ""
        echo "================================================================================="
        echo -n 'Rancher の admin ユーザのパスワードを新しくセットしてください。 : '
        read -s PASSWORD
        echo ""
        echo -n '確認の為もう一度入力してください。 : '
        read -s PASSWORD2
        if [ $PASSWORD = $PASSWORD2 ]; then
            break
        else
            echo ""
            echo "入力したパスワードが一致しません。"
        fi
    done

    curl -s -k "${RANCHERURL}/v3/users?action=changepassword" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $LOGINTOKEN" \
        --data-binary '{
            "currentPassword":"admin",
            "newPassword":"'$PASSWORD'"
          }' \
       >>"$LOGFILE" 2>&1
    log_message "[end] Change password"
fi


# Create API key
if [ -f .ra_apitoken ]; then
    log_message "[info] already exist APITOKEN"
else
    APIRESPONSE=$(curl -s -k "${RANCHERURL}/v3/token" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $LOGINTOKEN" \
        --data-binary '{
            "type":"token",
            "description":"automation"
          }' \
        )
    echo "APIRESPONSE: $APIRESPONSE" >> $LOGFILE

    # Extract and store token
    APITOKEN=$(echo $APIRESPONSE | jq -r .token)
    if [ "$APITOKEN" == "null" ] || [ -z $APITOKEN ]; then
        failed_to_install "get APITOKEN " "all"
    fi
    echo $APITOKEN > .ra_apitoken
    log_message "APITOKEN: $APITOKEN"
    log_message "[end] Create API key"

    # Set server-url
    curl -s -k "${RANCHERURL}/v3/settings/server-url" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        -X PUT \
        --data-binary '{
            "name":"server-url",
            "value":"'$RANCHERURL'"
          }' \
       >>"$LOGFILE" 2>&1
    log_message "[end] Set server-url"
fi
if [ -f .ra_clusterid ]; then
    log_message "[info] already exist CLUSTERID"
else
    # Create cluster
    echo ""
    echo "================================================================================="
    echo -n 'クラスタ名を設定してください。(任意の名前) : '
    read CLUSTERNAME
    CLUSTERNAME=${CLUSTERNAME,,}
    echo "CLUSTERNAME: $CLUSTERNAME" >> $LOGFILE

    if [ -z $CLUSTER_CIDR ]; then CLUSTER_CIDR="10.42.0.0/16"; fi
    if [ -z $SERVICE_CLUSTER_IP_RANGE ]; then SERVICE_CLUSTER_IP_RANGE="10.43.0.0/16"; fi
    if [ -z $CLUSTER_DNS_SERVER ]; then CLUSTER_DNS_SERVER="10.43.0.10"; fi
    if [ -z $MAX_PODS ]; then MAX_PODS="110"; fi

    echo "CLUSTER_CIDR: $CLUSTER_CIDR" >> $LOGFILE
    echo "SERVICE_CLUSTER_IP_RANGE: $SERVICE_CLUSTER_IP_RANGE" >> $LOGFILE
    echo "CLUSTER_DNS_SERVER: $CLUSTER_DNS_SERVER" >> $LOGFILE
    echo "MAX_PODS: $MAX_PODS" >> $LOGFILE

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
                     "max-pods": "'$MAX_PODS'"
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
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
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
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD1"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo '------------------------------------------------------------'  | tee -a $CMDFILE
             echo 'または、'  | tee -a $CMDFILE
             echo '(【必要に応じて】 下記コマンドを他の Cluster Management単体 ノードで実行してください。)'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
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
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo '------------------------------------------------------------'  | tee -a $CMDFILE
             echo 'または、'  | tee -a $CMDFILE
             echo '(【必要に応じて】 下記コマンドを他の Worker単体 ノードで実行してください。)'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
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
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo '------------------------------------------------------------'  | tee -a $CMDFILE
             echo 'そして、'  | tee -a $CMDFILE
             echo '(【必要に応じて】 下記コマンドを他の Worker単体 ノードで実行してください。)'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD3"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             ;;
        "3") DOCKERRUNCMD=""
             echo '下記コマンドを他の(Cluster Management + Worker)ノードで実行してください。'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD1"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo '------------------------------------------------------------'  | tee -a $CMDFILE
             echo 'または、'  | tee -a $CMDFILE
             echo '下記コマンドを Cluster Management単体 ノードで実行してください。'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD2"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo '------------------------------------------------------------'  | tee -a $CMDFILE
             echo 'そして'  | tee -a $CMDFILE
             echo '下記コマンドを WORKER単体 ノードで実行してください。'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/configure-sysctl-values.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo ./configure-sysctl-values.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-docker.sh"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'chmod +x install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             if [ ! -z $DOCKER_VER ]; then
                 echo 'sed  -i -e "/^APP_VERSION/s/.*/APP_VERSION=\"'${DOCKER_VER}'\"/" install-docker.sh'   | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             if [ ! -z $DOCKER0 ]; then 
                 echo "sudo mkdir -p /etc/docker" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
                 echo "sudo sh -c \"echo '{\\\"bip\\\": \\\"${DOCKER0}\\\"}' > /etc/docker/daemon.json\"" | tee -a $CMDFILE
                 echo ""  | tee -a $CMDFILE
             fi
             echo './install-docker.sh'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo 'sudo usermod -aG docker "$USER"'  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
             echo "$DOCKERRUNCMD3"  | tee -a $CMDFILE
             echo ""  | tee -a $CMDFILE
            ;;
    esac
    echo ""  | tee -a $CMDFILE
    echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"  | tee -a $CMDFILE
    echo ""

    $DOCKERRUNCMD >> $LOGFILE 2>&1
fi

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

# waiting cluster to active
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


# install kubectl
curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-kubectl.sh
chmod +x install-kubectl.sh
if which kubectl > /dev/null 2>&1 ; then
    log_message "[info] already installed kubectl"
else
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
fi


# Get kubectl config
log_message "[start] Get kubectl config"
if [ ! -d  ${HOME}/.kube ];then
    mkdir -p ${HOME}/.kube
fi
touch  ${HOME}/.kube/config
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


# install helm
curl -s -O https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Kube/scripts/install-helm.sh
chmod +x install-helm.sh
sed -i -e 's/sudo/sudo env PATH=$PATH/' install-helm.sh
if which helm > /dev/null 2>&1 ; then
    log_message "[info] already installed helm"
    log_message "[start] install helm "
    ./install-helm.sh -c >> $LOGFILE 2>&1
    log_message "[end] install helm "
else
    log_message "[start] install helm "
    ./install-helm.sh >> $LOGFILE 2>&1
    if ! which helm > /dev/null 2>&1 ; then
        failed_to_install "install helm"
    fi
    log_message "[end] install helm "
fi

# get System project id
log_message "[start] get System project id"
SYSPROJECTID=$(curl -s -k "${RANCHERURL}/v3/projects/?name=System" \
    -H 'content-type: application/json' \
    -H "Authorization: Bearer $APITOKEN" \
    | jq -r '.data[].id')
log_message "SYSPROJECTID: $SYSPROJECTID"
if [ "$SYSPROJECTID" == "null" ] || [ -z $SYSPROJECTID ]; then
    failed_to_install "Extract SYSPROJECTID " "all"
fi
log_message "[end] get System project id"

# waiting tiller pod
log_message "[start]  waiting tiller pod "
while :
    do
       TILLERSTATE=$(curl -s -k "${RANCHERURL}/v3/project/${SYSPROJECTID}/workloads/deployment:kube-system:tiller-deploy" -H "Authorization: Bearer $APITOKEN" | jq -r .deploymentStatus.availableReplicas)
       echo "Waiting for state to become available.: $TILLERSTATE" | tee -a $LOGFILE
       if [[ $TILLERSTATE -ge 1 ]] ;then
           break
       fi
       sleep 10
done
log_message "[end]  waiting tiller pod "

# add shield repo
add_repo

# set node label
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
            #echo '---------------------------------------------------------'
            #echo '【オールインワンの場合】'
            #echo '---------------------------------------------------------'
            #echo '1) 全て (management, proxy, elk, farm-services, remort-browsers)'
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
                #"1")
                #    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                #    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                #    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                #    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                #    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                #    break
                #    ;;
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

# deploy shield
deploy_shield

# get Default project id
move_to_project

echo ""
echo "【※確認※】 Rancher UI　${RANCHERURL} をブラウザで開き、全てのワークロードが Acriveになることをご確認ください。"
echo ""
fin 0
