#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200110a
####################

# 変数
SSH_USER="ericom"
SSH_HOST=""
REMOTE_CMD=""
SSH_OP="-oStrictHostKeyChecking=no"
ES_PATH="/usr/local/ericomshield"
LOGFILE="backup-restore.log"
export SSH_ASKPASS=$0
export DISPLAY=dummy:0

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

# SSH_ASKPASS経由の場合の応答処理
if [ -n "$PASSWORD" ]; then
  cat <<< "$PASSWORD"
  exit 0
fi

function usage() {
    echo ""
    echo "USAGE: "
    echo "    $0 backup [-mng|-b] <IP Address> " 
    echo "    $0 backup [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo ""
    echo "    $0 restore [-mng|-b] <IP Address> " 
    echo "    $0 restore [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo ""
    echo "  ---------- "
    echo " ex.) $0 backup -mng 192.168.100.11"
    echo "      $0 backup -b 192.168.100.21,192.168.100.22"
    echo "      $0 backup -mng 192.168.100.11 -b 192.168.100.21,192.168.100.22"
    echo ""
    echo "      $0 restore -mng 192.168.100.11"
    echo "      $0 restore -b 192.168.100.21,192.168.100.22"
    echo "      $0 restore -mng 192.168.100.11,192.168.100.12,192.168.100.13 -b 192.168.100.21,192.168.100.22"
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

function fin() {
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

    for i in `seq 1 ${#}`
    do
        if [ "$1" == "backup" ] ; then
            BACKUP_FLG=1
        elif [ "$1" == "restore" ] ; then
            RESTORE_FLG=1
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

function check_nodes(){

    echo ""
    log_message "-----------------------------------------------------------------------"
    docker node ls | tee -a $LOGFILE
    log_message "-----------------------------------------------------------------------"
    echo ""

    ALL_CNT=$(docker node inspect $(docker node ls -q) | grep -c "Role")
    MNG_CNT=$(docker node inspect $(docker node ls -q) | grep -c "manager")
    BRO_CNT=$(docker node inspect $(docker node ls -q) | grep -c "worker")

    echo "    ALL_CNT: $ALL_CNT" >> $LOGFILE
    echo "    MNG_CNT: $MNG_CNT" >> $LOGFILE
    echo "    BRO_CNT: $BRO_CNT" >> $LOGFILE
    
}

function set_ip_arr(){
    MNG_ARR=( $(echo $MNG_HOSTS | tr -s ',' ' ') )
    BRO_ARR=( $(echo $BRO_HOSTS | tr -s ',' ' ') )

    for i in "${MNG_ARR[@]} ${BRO_ARR[@]}" 
    do
        check_ip $i
    done

    MNG_ARG_CNT=${#MNG_ARR[*]}
    BRO_ARG_CNT=${#BRO_ARR[*]}
    echo "    MNG_ARG_CNT: $MNG_ARG_CNT" >> $LOGFILE
    echo "    BRO_ARG_CNT: $BRO_ARG_CNT" >> $LOGFILE

}

function check_ip(){
    IP=$1
    IP_CHECK=$(echo ${IP} | grep -E  "^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")

    if [ ! "${IP_CHECK}" ] ; then
        log_message "!!! ERROR: ${IP} is not IP Address."
        fin 1
    fi
}

function exec_ssh(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    exec setsid ssh -t $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE
}
function exec_ssh2(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    rm -f tmp_hostname.txt
    exec setsid ssh $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE  tmp_hostname.txt
    NODE_HOSTNAME=$(cat tmp_hostname.txt)
}

##### メイン処理
log_message "###### START ###########################################################"
log_message "ScriptName: ${0##*/}"
log_message "ScriptVER: $(cat $0 | grep "### VER=" | grep -v grep )"
log_message "------------------------------------"
check_args $@
# ericom ユーザ password 入力
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

export PASSWORD

# IPアドレス配列セット
set_ip_arr

# 現状のノードリスト確認
check_nodes

# バックアップの場合、対象ノードをleave する。
if [ $BACKUP_FLG -eq 1 ] ; then

    log_message "[Start] Backup pre-processing. "
    if [ $(( $MNG_CNT-$MNG_ARG_CNT)) -eq 0 ] ;then
        while :
        do
            log_message " INFO: All Managers have been selected."
            echo -n "  全てのManagerノードが離脱します。本当に進めてよろしいですか？ [y/N]: "
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

    # 対象ノードをLeave
    log_message "[Start] Leaving nodes..... "
    for i in "${MNG_ARR[@]}"
    do
        log_message "  Leaving $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        exec_ssh2 $i "hostname"
        docker node demote $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) | tee -a >> $LOGFILE
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) | tee -a >> $LOGFILE
    done
    for i in "${BRO_ARR[@]}"
    do
        log_message "  Leaving $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        exec_ssh2 $i "hostname"
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) | tee -a >> $LOGFILE
    done
    
    # Leave 後のリスト表示
    check_nodes

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
    if [ $(( $MNG_CNT-$MNG_ARG_CNT)) -eq 0 ] ;then
        while :
        do
            log_message " INFO: All Managers have been selected."
            echo -n "  全てのManagerノードが離脱します。本当に進めてよろしいですか？ [y/N]: "
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

    # 対象ノードをjoin
    log_message "[Start] Joining nodes..... "
    for i in "${MNG_ARR[@]}"
    do
        log_message "  Joining $i"
        exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_MNG"
    done
    for i in "${BRO_ARR[@]}"
    do
        log_message "  Joining $i"
        exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_BRO"
    done
    
    # Leave 後のリスト表示
    check_nodes

    #終了
    log_message "[End] Restore processing. "
    fin 0

fi


