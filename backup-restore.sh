#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200114a
####################

# 変数
SSH_USER="ericom"
SSH_HOST=""
REMOTE_CMD=""
SSH_OP="-oStrictHostKeyChecking=no"
ES_PATH="/usr/local/ericomshield"
LOGFILE="backup-restore.log"
MY_PATH="$(cd $(dirname $0); pwd)/${0##*/}"
export SSH_ASKPASS=$0
export DISPLAY=dummy:0

function usage() {
    echo ""
    echo "USAGE: "
    echo "    $0 backup [-mng|-b] <IP Address> " 
    echo "    $0 backup [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo "    $0 backup [-a]"
    echo ""
    echo "    $0 restore [-mng|-b] <IP Address> " 
    echo "    $0 restore [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo ""
    echo "  ---------- "
    echo " ex.) $0 backup -mng 192.168.100.11"
    echo "      $0 backup -b 192.168.100.21,192.168.100.22"
    echo "      $0 backup -mng 192.168.100.11 -b 192.168.100.21,192.168.100.22"
    echo "      $0 backup -a"
    echo ""
    echo "      $0 restore -mng 192.168.100.11"
    echo "      $0 restore -b 192.168.100.21,192.168.100.22"
    echo "      $0 restore -mng 192.168.100.11,192.168.100.12,192.168.100.13 -b 192.168.100.21,192.168.100.22"
    exit 0
}

function status_check(){
    NODE_HOSTNAME=$1
    for j in `seq 1 30`
    do
        NODE_STATUS=$(docker node ls | grep $NODE_HOSTNAME | awk '{print $3}')
        if [ "$2" == "$NODE_STATUS" ] ; then
            echo "      Done"
            return
        fi
        sleep 1
    done
    log_message "!!! WARNING: status_check timeout."
    fin 1
}

function check_nodes(){

    echo ""
    log_message "-----------------------------------------------------------------------"
    docker node ls | tee -a $LOGFILE
    log_message "-----------------------------------------------------------------------"
    echo ""

    # ALL_CNT=$(docker node inspect $(docker node ls -q) | grep -c "Role")
    # MNG_CNT=$(docker node inspect $(docker node ls -q) | grep -c "manager")
    # BRO_CNT=$(docker node inspect $(docker node ls -q) | grep -c "worker")
    # echo "    ALL_CNT: $ALL_CNT" >> $LOGFILE
    # echo "    MNG_CNT: $MNG_CNT" >> $LOGFILE
    # echo "    BRO_CNT: $BRO_CNT" >> $LOGFILE

    ALLIVE_MNG_CNT=$(docker node ls |grep -c -E "(Reachable|Leader)")
    ALLIVE_BRO_CNT=$(docker node ls |grep -c -v -E "(*eachable|Leader|ID)")
    echo "    ALLIVE_MNG_CNT: $ALLIVE_MNG_CNT" >> $LOGFILE
    echo "    ALLIVE_BRO_CNT: $ALLIVE_BRO_CNT" >> $LOGFILE
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
    echo "StatusCode: $1" >>"$LOGFILE"
    log_message "###### DONE ############################################################"
    exit $1
}

function check_args(){

    echo "    ///// args /////////////////////" >> $LOGFILE
    echo "    args: $@" >> $LOGFILE

    if [ ${#} -eq 0 ] ; then
        log_message "!!! ERROR: ${0##*/} needs arguments."
        log_message "        please check '$ sudo $0 --help' ."
        fin 1
    fi
    args=""
    BACKUP_FLG=0
    RESTORE_FLG=0
    ALL_FLG=0
    SILENT_FLG=0
    PASSWORD=""

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "backup" ] ; then
            BACKUP_FLG=1
        elif [ "$1" == "restore" ] ; then
            RESTORE_FLG=1
        elif [ "$1" == "-a" ] ; then
            ALL_FLG=1
        elif [ "$1" == "-s" ] ; then
            SILENT_FLG=1
        elif [ "$1" == "-p" ] ; then
            shift
            PASSWORD="$1"
        elif [ "$1" == "-mng" ] ; then
            shift
            MNG_HOSTS="$1"
            if [ -z $MNG_HOSTS ]; then
                log_message "!!! ERROR: -mng needs IP address."
                log_message "        please check '$ sudo $0 --help' ."
                fin 1
            fi
        elif [ "$1" == "-b" ] ; then
            shift
            BRO_HOSTS="$1"
            if [ -z $BRO_HOSTS ]; then
                log_message "!!! ERROR: -b needs IP address."
                log_message "        please check '$ sudo $0 --help' ."
                fin 1
            fi
        else
            args="${args} ${1}"
        fi
        shift
    done

    if [ $BACKUP_FLG -eq 0 ] && [ $RESTORE_FLG -eq 0 ] ; then
                log_message "!!! ERROR: ${0##*/} needs backup or restore argument."
                log_message "        please check '$ sudo $0 --help' ."
                fin 1
    fi
    if [ ! -z ${args} ]; then
        log_message "!!! ERROR: ${args} is wrong argument(s)."
        log_message "        please check '$ sudo $0 --help' ."
        fin 1
    fi


    echo "    remaind args: $args" >> $LOGFILE
    echo "    BACKUP_FLG: $BACKUP_FLG" >> $LOGFILE
    echo "    RESTORE_FLG: $RESTORE_FLG" >> $LOGFILE
    echo "    MNG_HOSTS: $MNG_HOSTS" >> $LOGFILE
    echo "    BRO_HOSTS: $BRO_HOSTS" >> $LOGFILE
    echo "    ////////////////////////////////" >> $LOGFILE
}

function set_ip_arr(){
    MNG_ARR=( $(echo $MNG_HOSTS | tr -s ',' ' ') )
    BRO_ARR=( $(echo $BRO_HOSTS | tr -s ',' ' ') )
    ERR_FLG=0
    for i in "${MNG_ARR[@]}" 
    do
        check_ip $i
        if [ $(sudo docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Description.Hostname }}" $(docker node ls -q) | grep manager | grep -c $i) -eq 0 ]; then
            log_message "!!! ERROR: ${IP} is not Manager."
            ERR_FLG=1
        fi
    done
    for i in "${BRO_ARR[@]}" 
    do
        check_ip $i
        if [ $(sudo docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Description.Hostname }}" $(docker node ls -q) | grep worker | grep -c $i) -eq 0 ]; then
            log_message "!!! ERROR: ${IP} is not Worker."
            ERR_FLG=1
        fi
    done

    if [ $ERR_FLG -eq 1 ]; then
        fin 1
    fi

    MNG_ARG_CNT=${#MNG_ARR[*]}
    BRO_ARG_CNT=${#BRO_ARR[*]}
    echo "    MNG_ARG_CNT: $MNG_ARG_CNT" >> $LOGFILE
    echo "    BRO_ARG_CNT: $BRO_ARG_CNT" >> $LOGFILE

}

function check_ip(){
    IP=$1
    IP_CHECK=$(echo ${IP} | grep -E  "^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")

    if [ ! "${IP_CHECK}" ] ; then
        log_message "!!! WARNING: ${IP} is not IP Address."
        if [ $(docker node ls | grep -c ${IP}) -eq 0 ];then
            log_message "!!! ERROR: ${IP} dose not Exist in node list."
            fin 1
        fi
    fi
}

function alt_mng_ip(){
    ALT_MNG_ARR=( $(docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Status.State }}" $(docker node ls -q) | grep manager | grep -v down | awk '{print $2}') )
    for i in "${ALT_MNG_ARR[@]}"
    do 
        if [ "$i" == "$MY_IP" ]; then
            continue
        fi
        ALT_MNG="$i"
    done
    echo "    ALT_MNG: $ALT_MNG" >> $LOGFILE
}

function all_ip_set(){
    MNG_ARR=( $(docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }}" $(docker node ls -q) | grep manager | awk '{print $2}') )
    BRO_ARR=( $(docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }}" $(docker node ls -q) | grep worker | awk '{print $2}') )

    MNG_ARG_CNT=${#MNG_ARR[*]}
    BRO_ARG_CNT=${#BRO_ARR[*]}
    echo "    MNG_ARG_CNT: $MNG_ARG_CNT" >> $LOGFILE
    echo "    BRO_ARG_CNT: $BRO_ARG_CNT" >> $LOGFILE
}



# function check_labels(){
#     log_message "-----------------------------------------------------------------------"
#     docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Status.State }} {{ .Spec.Labels }}" $(docker node ls -q) | grep manager | tee -a  $LOGFILE
#     docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Status.State }} {{ .Spec.Labels }}" $(docker node ls -q) | grep worker | tee -a  $LOGFILE
#     log_message "-----------------------------------------------------------------------"
# }

function exec_ssh(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    exec setsid ssh -t $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE
}

function exec_ssh2(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    rm -f tmp_hostname.txt
    exec setsid ssh $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE tmp_hostname.txt 
    NODE_HOSTNAME=$(cat tmp_hostname.txt | grep -v "Warning")
    rm -f tmp_hostname.txt
}


#root権限確認
if ((EUID != 0)); then
    #    sudo su
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

if [ $# -eq 1 ] && [ "$1" == "check_nodes" ]; then
    check_nodes
    exit 0
elif [ $# -eq 3 ] && [ "$1" == "status_check" ]; then
    status_check $2 $3
    exit 0
fi

# SSH_ASKPASS経由の場合の応答処理
if [ -n "$PASSWORD" ]; then
  cat <<< "$PASSWORD"
  exit 0
fi


##### メイン処理
log_message "###### START ###########################################################"
log_message "ScriptName: ${0##*/}"
log_message "ScriptVER: $(cat $0 | grep "### VER=" | grep -v grep )"
log_message "------------------------------------"

MY_IP="$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')"

check_args $@

# -pによるパスワードが指定されていない場合、ericom ユーザ password を入力
if [ "$PASSWORD" == "" ];then
    while :
    do
        echo ""
        echo "================================================================================="
        echo -n "Please Enter $SSH_USER user's password : "
        read -r -s PASSWORD
        echo ""
        echo -n "Retype same password : "
        read -r -s PASSWORD2
        echo ""
        if [ $PASSWORD = $PASSWORD2 ]; then
            break
        else
            echo "Sorry, passwords do not match."
            echo ""
        fi
    done
fi

export PASSWORD

# バックアップの場合、対象ノードをleave する。
if [ $BACKUP_FLG -eq 1 ] ; then

    # クラスタ情報が確認できない場合
    if [[ $(docker node ls 2>&1 | grep -c "This node is not a swarm manager.") -eq 1 ]] ; then
        log_message " INFO: This node is not swarm Manager."    
        echo "  このノードは現在、Managerでもなく、Swarmクラスタのメンバーでもありません。"
        echo "  他に有効なManagerノードで実行してください。"
        fin 1
    fi

    log_message "[Start] Backup pre-processing. "

    # 現状のノードリスト確認
    check_nodes

    # IPアドレス配列セット
    if [ $ALL_FLG -eq 1 ] ;then
        log_message " INFO: All Managers have been selected."
        if [ $SILENT_FLG -eq 0 ] ; then
            while :
            do
                echo -n "  全てのノードが離脱します。本当に進めてよろしいですか？ [y/N]: "
                    read -r ANSWER
                    echo "    ANSWER: $ANSWER" >> $LOGFILE            
                    case $ANSWER in
                        "Y" | "y" | "yse" | "Yes" | "YES" )
                            break
                            ;;
                        "" | "n" | "N" | "no" | "No" | "NO" )
                            log_message "[Stop] Backup pre-processing. "
                            fin 0
                            ;;
                        * )
                            echo "YまたはNで答えて下さい。"
                            ;;
                    esac
            done
        fi
        all_ip_set
    else
        set_ip_arr
    fi

    # 対象ノードの確認
    log_message "次のノードをクラスタから除外します。"
    if [ $MNG_ARG_CNT -ge 1 ]; then
        log_message "  Manager:"
        for i in "${MNG_ARR[@]}"
        do
            log_message "    $i"
        done
    fi
    if [ $BRO_ARG_CNT -ge 1 ]; then
        log_message "  Browser:"
        for i in "${BRO_ARR[@]}"
        do
            log_message "    $i"
        done
    fi

    if [ $SILENT_FLG -eq 0 ] ; then
        while :
        do
            echo -n "  進めてよろしいですか？ [y/N]: "
                read -r ANSWER
                echo "    ANSWER: $ANSWER" >> $LOGFILE            
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        log_message "[Stop] Backup pre-processing. "
                        fin 0
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
        done
    fi

    # 対象ノードをLeave
    log_message "[Start] Leaving nodes..... "

    # Browserノードから
    for i in "${BRO_ARR[@]}"
    do
        log_message "  Leave $i"
        log_message "    Leaving $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        exec_ssh2 $i "hostname"
        status_check $NODE_HOSTNAME "Down"
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) >> $LOGFILE 2>&1
    done

    # Managerノード
    MY_FLG=0
    for i in "${MNG_ARR[@]}"
    do
        # 自分自身は最後に
        if [ "$i" == "$MY_IP" ] ;then 
            MY_FLG=1
            continue
        fi

        log_message "  Leave $i"
        check_nodes > /dev/null
        exec_ssh2 $i "hostname"
        if [ $(docker node ls | grep -c $NODE_HOSTNAME) -eq 0 ];then
            log_message "!!! WARNING: $NODE_HOSTNAME dose not exist. Skip."
            continue
        fi
        log_message "    Demoting $NODE_HOSTNAME"
        docker node demote $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1)  >> $LOGFILE  2>&1
        log_message "    Leaveing $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        status_check $NODE_HOSTNAME "Down"
        log_message "   Removing $i"
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) >> $LOGFILE 2>&1
        log_message "     Done"
    done

    # 対象に自分のIPが含まれている場合
    if [ $MY_FLG -eq 1 ] ; then
        check_nodes > /dev/null
        # 自分が最後の有効なManagerノードの場合
        if [ $ALLIVE_MNG_CNT -eq 1 ]; then
            log_message "  Leave $MY_IP"
            log_message "    Leaveing myself $MY_IP"
            docker swarm leave -f
            log_message "     Done"
        else
            alt_mng_ip
            log_message "  Leave $MY_IP"
            if [ $(docker node ls | grep -c ${HOSTNAME}) -eq 0 ];then
                log_message "!!! WARNING: ${HOSTNAME} dose not exist. Skip."
            else
                log_message "    Demoting myself $MY_IP"
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S docker node demote ${HOSTNAME}"
                log_message "    Leaveing myself $MY_IP"
                docker swarm leave -f >> $LOGFILE 2>&1
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S $MY_PATH status_check ${HOSTNAME} Down"       
                log_message "     Done"
                log_message "   Removing $MY_IP"
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S docker node rm ${HOSTNAME}"
                log_message "     Done"
                # Leave 後のリスト表示
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S $MY_PATH check_nodes"            
            fi
        fi
    # -aによる処理の場合は自分自身を最後にleave
    elif [ $ALL_FLG -eq 1 ] ;then
        log_message "    Leaveing myself $MY_IP"
        docker swarm leave -f
        log_message "     Done"
    else
        # Leave 後のリスト表示(自分がManagerの場合に実行可能)
        check_nodes
    fi
    
    #終了
    log_message "[End] Backup pre-processing. "
    log_message ""
    log_message "対象ノードをシャットダウンし、バックアップを取得してください。"
    SHOW_ARG=""
    if [ $MNG_ARG_CNT -ge 1 ]; then
        SHOW_ARG="-mng $MNG_HOSTS"
    fi
    if [ $BRO_ARG_CNT -ge 1 ]; then
        SHOW_ARG="$SHOW_ARG -b $BRO_HOSTS"
    fi
    log_message "再起動後、sudo $0 restore $SHOW_ARG コマンドによりクラスタに再参加させてください。"
    fin 0

elif [ $RESTORE_FLG -eq 1 ] ; then

    log_message "[Start] Restore processing. "
    # クラスタ情報が確認できない場合
    if [[ $(docker node ls 2>&1 | grep -c "This node is not a swarm manager.") -eq 1 ]] ; then
        log_message " INFO: This node is not swarm Manager."             
        if [ $SILENT_FLG -eq 0 ]; then
            while :
            do
                echo "  このノードは現在、Managerでもなく、Swarmクラスタのメンバーでもありません。"
                echo "  他に有効なManagerノードが存在する場合は処理を中断し、そちらで実行してください。"
                echo -n "  このノードを新しいLeaderとして再初期化してよろしいですか？ [y/N]: "
                    read -r ANSWER
                    echo "    ANSWER: $ANSWER" >> $LOGFILE            
                    case $ANSWER in
                        "Y" | "y" | "yse" | "Yes" | "YES" )
                            break
                            ;;
                        "" | "n" | "N" | "no" | "No" | "NO" )
                            log_message "[Stop] Restore processing. "
                            fin 0
                            ;;
                        * )
                            echo "YまたはNで答えて下さい。"
                            ;;
                    esac
            done
        fi
        ALL_FLG=1
    fi

    if [ $ALL_FLG -eq 1 ] ; then
        log_message "  Force initializing."
        docker swarm init --force-new-cluster >> $LOGFILE 
    fi

    # IPアドレス配列セット
    set_ip_arr

    # 対象ノードの確認
    log_message "次のノードをクラスタに再参加させます。"
    if [ $MNG_ARG_CNT -ge 1 ]; then
        JOIN_MNG=$(docker swarm join-token manager | grep join)
        echo "    JOIN_MNG: $JOIN_MNG" >> $LOGFILE
        log_message "  Manager:"
        for i in "${MNG_ARR[@]}"
        do
            log_message "    $i"
        done
    fi
    if [ $BRO_ARG_CNT -ge 1 ]; then
        JOIN_BRO=$(docker swarm join-token worker | grep join)
        echo "    JOIN_BRO: $JOIN_BRO" >> $LOGFILE
        log_message "  Browser:"
        for i in "${BRO_ARR[@]}"
        do
            log_message "    $i"
        done
    fi

    if [ $SILENT_FLG -eq 0 ]; then
        while :
        do
            echo -n "  進めてよろしいですか？ [y/N]: "
                read -r ANSWER
                echo "    ANSWER: $ANSWER" >> $LOGFILE            
                case $ANSWER in
                    "Y" | "y" | "yse" | "Yes" | "YES" )
                        break
                        ;;
                    "" | "n" | "N" | "no" | "No" | "NO" )
                        log_message "[Stop] Restore processing. "
                        fin 0
                        ;;
                    * )
                        echo "YまたはNで答えて下さい。"
                        ;;
                esac
        done
    fi

    # 対象ノードをjoin
    log_message "[Start] Joining nodes..... "

    # Browserノードから
    for i in "${BRO_ARR[@]}"
    do
        log_message "  Joining $i"
        exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_BRO"
        exec_ssh2 $i "hostname"
        log_message "    Adding labels"
        $ES_PATH/nodes.sh --add-label $NODE_HOSTNAME browser >> $LOGFILE 2>&1
        log_message "      Done"
    done

    # Managerノード
    MY_FLG=0
    for i in "${MNG_ARR[@]}"
    do
        # 自分自身はラベルだけ
        if [ "$i" == "$MY_IP" ] ;then 
            log_message "  Joining myself $i"
            log_message "    Adding labels"
            $ES_PATH/nodes.sh --add-label $HOSTNAME management >> $LOGFILE 2>&1
            $ES_PATH/nodes.sh --add-label $HOSTNAME shield_core >> $LOGFILE 2>&1
            log_message "      Done"
        else
            log_message "  Joining $i"
            exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_MNG"
            exec_ssh2 $i "hostname"
            log_message "    Adding labels"
            $ES_PATH/nodes.sh --add-label $NODE_HOSTNAME management >> $LOGFILE 2>&1
            $ES_PATH/nodes.sh --add-label $NODE_HOSTNAME shield_core >> $LOGFILE 2>&1
            log_message "      Done"
        fi
    done

    # Join 後のリスト表示
    check_nodes
    $ES_PATH/status.sh -n
    #終了
    log_message "[End] Restore processing. "
    fin 0

fi


