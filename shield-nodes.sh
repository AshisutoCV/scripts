#!/bin/bash

####################
### K.K. Ashisuto
### VER=20191227a
####################

if [ ! -e ./logs/ ];then
    mkdir logs
    mv -f ./*.log ./logs/ > /dev/null 2>&1
fi

LOGFILE="./logs/nodes.log"
CMDFILE="command.txt"
BRANCH="Rel"
if [ -f .es_branch ]; then
    BRANCH=$(cat .es_branch)
fi

export BRANCH

function usage() {
    echo "USAGE: $0 [--addnodes] [--setlabels] "
    echo "    --addnodes       : 新規ノードの追加とラベリングを行います。"
    echo "    --setlabels       : 既存ノードのラベリングを確認・変更します。"

    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

function failed_to_start() {
    log_message "An error occurred during the nodes script.: $1, exiting"
    fin 1
}

function fin() {
    log_message "###### DONE ############################################################"
    exit $1
}

function check_args(){
    add_flg=0
    label_flg=0
    args=""

    echo "args: $1" >> $LOGFILE

    if [ ${#} -eq 0 ];then
        log_message "引数が必要です。"
        usage
        fin 1
    fi

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "--addnodes" ] || [ "$1" == "--Addnodes" ]; then
            add_flg=1
        elif [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
            usage
        elif [ "$1" == "--setlabels" ] || [ "$1" == "--Setlabels" ] ; then
            label_flg=1
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
    echo "add_flg: $add_flg" >> $LOGFILE
    echo "label_flg: $label_flg" >> $LOGFILE
    echo "args: $args" >> $LOGFILE
    echo "////////////////////////////////" >> $LOGFILE
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

function get_docker_cmd() {
    log_message "[Start] Generate commands"
    # Generate nodecommand
    AGENTCMD=$(curl -s -k "${RANCHERURL}/v3/clusterregistrationtoken?id=${CLUSTERID}" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $APITOKEN" \
        | jq -r '.data[].nodeCommand' | head -1)
    if [ -z "$AGENTCMD" ]; then
        failed_to_start "Extract AGENTCMD "
    fi

    declare -A roles
    roles[1]='--etcd --controlplane --worker'
    roles[2]='--etcd --controlplane'
    roles[3]='--worker'
 
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

    DOCKERRUNCMD1=$(echo ${DOCKERRUNCMD1} | sed -e 's/\//\\\//')
    DOCKERRUNCMD2=$(echo ${DOCKERRUNCMD2} | sed -e 's/\//\\\//')
    DOCKERRUNCMD3=$(echo ${DOCKERRUNCMD3} | sed -e 's/\//\\\//')

    sed -i -e "/[a-zA-Z_0-9]\s--etcd --controlplane --worker$/s|.*|${DOCKERRUNCMD1}|" $CMDFILE
    sed -i -e "/[a-zA-Z_0-9]\s--etcd --controlplane$/s|.*|${DOCKERRUNCMD2}|" $CMDFILE
    sed -i -e "/[a-zA-Z_0-9]\s--worker$/s|.*|${DOCKERRUNCMD3}|" $CMDFILE

    log_message "[end] Generate commands"
}


function docker_cmd(){
    log_message "[Start] Exec docker command "
    echo ""
    echo "========================================================================================="
    echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
    echo '※この後、複数台構成にする場合に他のノードで実行するコマンドが画面に表示されます。'
    echo '※必要に応じてコピーの上、他ノードで実行してください。'
    echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
    echo ""

    cat ${CMDFILE}

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

    log_message "[end] Exec docker command "
    echo ""
    echo "wait 30sec...."
    sleep 30
}


function set_label(){
    log_message "[start] set labels "
    NODELIST=($(kubectl get node -o json |jq -r .items[].metadata.name))
    adv_flg=0
    for NODENAME in ${NODELIST[@]};
    do
        echo ""
        LABELLISTS=($(kubectl get node --show-labels | grep ${NODENAME} | awk '{print $6}' | tr ',' '\n' |grep shield))
        echo "================================================================================="
        echo ""
        log_message "*** {$NODENAME} ***"
        echo ""
        if [ ${#LABELLISTS} -eq 0 ]; then
            echo -n '上記ノードにはまだラベルが設定されていません。設定しますか？ [y/N]:'
        else
            echo '上記ノードには下記のラベルが設定されています。'
            echo ""
            for LABELLIST in ${LABELLISTS[@]};
            do
                log_message "${LABELLIST}"
            done
            echo ""
            echo -n '再設定しますか？ [y/N]:'
        fi

        break_flg=0
        while :
        do
        if [[ break_flg -eq 1 ]];then
            break
        fi
            read ANSWER
            echo $ANSWER >> $LOGFILE
            case $ANSWER in
                "Y" | "y" | "yse" | "Yes" | "YES" )
                    log_message "[start] reset labels "
                    kubectl label node ${NODENAME} shield-role/farm-services- > /dev/null 2>&1
                    kubectl label node ${NODENAME} shield-role/remote-browsers- > /dev/null 2>&1
                    kubectl label node ${NODENAME} shield-role/management- > /dev/null 2>&1
                    kubectl label node ${NODENAME} shield-role/proxy- > /dev/null 2>&1
                    kubectl label node ${NODENAME} shield-role/elk- > /dev/null 2>&1
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
                                    break_flg=1
                                    break
                                    ;;
                                #"1")
                                #    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                #    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                #    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                #    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                #    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                #    break_flg=1
                                #    break
                                #    ;;
                                "2")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "3")
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
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
                                    break_flg=1
                                    break
                                    ;;
                                "1")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "2")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "3")
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "4")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "5")
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "11")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "12")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "13")
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "14")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "15")
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "19")
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "21")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "22")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "23")
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "24")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "25")
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "29")
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "31")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "32")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "33")
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "34")
                                    kubectl label node ${NODENAME} shield-role/management=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "35")
                                    kubectl label node ${NODENAME} shield-role/farm-services=accept --overwrite
                                    kubectl label node ${NODENAME} shield-role/remote-browsers=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "38")
                                    kubectl label node ${NODENAME} shield-role/elk=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                "39")
                                    kubectl label node ${NODENAME} shield-role/proxy=accept --overwrite
                                    break_flg=1
                                    break
                                    ;;
                                *)
                                    echo "番号が正しくありません。"
                                    ;;
                            esac
                        fi
                    done
                    log_message "[end] reset labels "
                    ;;
                "" | "n" | "N" | "no" | "No" | "NO" )
                    break
                    ;;
                * )
                    echo -n 'YまたはNで答えて下さい。 [y/N]:'
                    ;;
            esac
        done
    done
   log_message "[end] set labels "
}


log_message "###### START ###########################################################"

#read ra files
if [ -f .ra_rancherurl ] && [ -f .ra_clusterid ] && [ -f .ra_apitoken ];then
    RANCHERURL=$(cat .ra_rancherurl)
    CLUSTERID=$(cat .ra_clusterid)
    APITOKEN=$(cat .ra_apitoken)
else
    failed_to_start "read ra files"
fi


# check args and set flags
check_args $@

if [[ add_flg -eq 1 ]];then
    # echo docker command
    get_docker_cmd
    docker_cmd
    set_label
fi

if [[ label_flg -eq 1 ]];then
    # set node label
    set_label
fi

fin 0
