#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200716a
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
    echo "    $0 backup [-mng|-b] <IP Address> [-p <ericom user's password>] [-s]"  
    echo "    $0 backup [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo "    $0 backup [-a]"
    echo ""
    echo "    $0 restore [-mng|-b] <IP Address> [-p <ericom user's password>] [-s]" 
    echo "    $0 restore [-mng|-b] <IP Address#1>,<IP Address #2>... " 
    echo ""
    echo "    第一引数："
    echo "         backup  : バックアップのためにクラスタから対象ノードを切り離します。"
    echo "         restore : バックアップ終了後やリストア時に、切り離したノードをクラスタに再参加させます。"
    echo ""
    echo "    その他の引数："
    echo "           -mng   : 対象とするManagerノードのIPアドレスを指定します。(IP推奨。ホスト名可)"
    echo "           -b     : 対象とするBrowser(Worker)ノードのIPアドレスを指定します。(IP推奨。ホスト名可)"
    echo "           -p     : ericomユーザのパスワードを事前に指定できます。指定しない場合は実行中に入力します。"
    echo "           -s     : 実行時の確認ダイアログを全てYesで実行します。(サイレント)"
    echo "           -a     : バックアップの為に全てのノードをクラスタから離脱させます。(バックアップのみ)"
    echo ""
    echo "  ---------- "
    echo " ex.) $0 backup -mng 192.168.100.11"
    echo "      $0 backup -b 192.168.100.21,192.168.100.22"
    echo "      $0 backup -mng 192.168.100.11 -b 192.168.100.21,192.168.100.22"
    echo "      $0 backup -mng 192.168.100.11 -b 192.168.100.21,192.168.100.22 -p password -s"
    echo "      $0 backup -mng 192.168.100.11 -b 192.168.100.21,192.168.100.22 -s"
    echo "      $0 backup -a -p password -s"
    echo "      $0 backup -a"
    echo ""
    echo "      $0 restore -mng 192.168.100.11"
    echo "      $0 restore -b 192.168.100.21,192.168.100.22"
    echo "      $0 restore -mng 192.168.100.11,192.168.100.12,192.168.100.13 -b 192.168.100.21,192.168.100.22"
    echo "      $0 restore -mng 192.168.100.11,192.168.100.12,192.168.100.13 -b 192.168.100.21,192.168.100.22 -p password -s"
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

# 引数のIPアドレスを配列に格納(ホスト名可)
function set_ip_arr(){
    MNG_ARR=( $(echo $MNG_HOSTS | tr -s ',' ' ') )
    BRO_ARR=( $(echo $BRO_HOSTS | tr -s ',' ' ') )
    ERR_FLG=0

    # Manager について
    for i in "${MNG_ARR[@]}" 
    do
        # 引数で渡されたものがIPアドレスの形かどうかを確認
        check_ip $i

        # バックアップ時は -mngで渡されたアドレスがManagerのものかどうか確認
        # リストア時は 既にクラスタに参加済みではいかどうかを確認
        MANAGER_CNT=$(sudo docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Description.Hostname }}" $(docker node ls -q) | grep manager | grep -c $i)
        if [ $BACKUP_FLG -eq 1 ] && [ $MANAGER_CNT -eq 0 ]; then
            log_message "!!! ERROR: ${IP} is not Manager."
            ERR_FLG=1
        elif [ $RESTORE_FLG -eq 1 ] && [ $MANAGER_CNT -gt 0 ] ; then
            if [ $ALL_FLG -eq 0 ] ; then 
                log_message "!!! ERROR: ${IP} is Alredy Exist."
                ERR_FLG=1
            elif [ $ALL_FLG -eq 1 ] && [ "$i" != "$MY_IP" ]; then
                log_message "!!! ERROR: ${IP} is Alredy Exist."
                ERR_FLG=1
            fi              
        fi
    done

    # Workerについて
    for i in "${BRO_ARR[@]}" 
    do
        # 引数で渡されたものがIPアドレスの形かどうかを確認
        check_ip $i

        # バックアップ時は -bで渡されたアドレスがWorkerのものかどうか確認
        # リストア時は 既にクラスタに参加済みではいかどうかを確認
        WORKER_CNT=$(sudo docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Description.Hostname }}" $(docker node ls -q) | grep worker | grep -c $i)
        if [ $BACKUP_FLG -eq 1 ] && [ $WORKER_CNT -eq 0 ]; then
            log_message "!!! ERROR: ${IP} is not Worker."
            ERR_FLG=1
        elif [ $RESTORE_FLG -eq 1 ] && [ $WORKER_CNT -gt 0 ]; then
            log_message "!!! ERROR: ${IP} is Alredy Exist."
            ERR_FLG=1
        fi
    done

    # Errorがあった場合に終了
    if [ $ERR_FLG -eq 1 ]; then
        fin 1
    fi

    # 引数として渡された対象ノード数を記録
    MNG_ARG_CNT=${#MNG_ARR[*]}
    BRO_ARG_CNT=${#BRO_ARR[*]}
    echo "    MNG_ARG_CNT: $MNG_ARG_CNT" >> $LOGFILE
    echo "    BRO_ARG_CNT: $BRO_ARG_CNT" >> $LOGFILE

}

# IPアドレスの形式かどうかを確認
# 違う場合は警告を出すが処理は続行
# IPアドレスでない場合、バックアップ時はクラスタのノードリストにホスト名があるかどうかを確認。
function check_ip(){
    IP=$1
    IP_CHECK=$(echo ${IP} | grep -E  "^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")

    if [ ! "${IP_CHECK}" ] ; then
        log_message "!!! WARNING: ${IP} is not IP Address."
        if [ $BACKUP_FLG -eq 1 ]; then
            if [ $(docker node ls | grep -c ${IP}) -eq 0 ];then
                log_message "!!! ERROR: ${IP} dose not Exist in node list."
                fin 1
            fi
        fi
    fi
}

# 自分自身をクラスタから離脱させるために、他のManagerノードのアドレスをセット
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

# 全てのノードを離脱させるための対象アドレスをセット
function all_ip_set(){
    MNG_ARR=( $(docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }}" $(docker node ls -q) | grep manager | awk '{print $2}') )
    BRO_ARR=( $(docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }}" $(docker node ls -q) | grep worker | awk '{print $2}') )

    MNG_ARG_CNT=${#MNG_ARR[*]}
    BRO_ARG_CNT=${#BRO_ARR[*]}
    echo "    MNG_ARG_CNT: $MNG_ARG_CNT" >> $LOGFILE
    echo "    BRO_ARG_CNT: $BRO_ARG_CNT" >> $LOGFILE
}

# ノードに付与されたラベルを確認
# function check_labels(){
#     log_message "-----------------------------------------------------------------------"
#     docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Status.State }} {{ .Spec.Labels }}" $(docker node ls -q) | grep manager | tee -a  $LOGFILE
#     docker node inspect -f "{{ .Spec.Role }} {{ .Status.Addr }} {{ .Status.State }} {{ .Spec.Labels }}" $(docker node ls -q) | grep worker | tee -a  $LOGFILE
#     log_message "-----------------------------------------------------------------------"
# }

# 対象ノードにSSHでリモートコマンドを実行させる
# リモートでの標準出力はTXTに
function exec_ssh(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    RET_EXEC=""
    rm -f tmp_exec.txt
    exec setsid ssh -t $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE tmp_exec.txt
    RET_EXEC=$(cat tmp_exec.txt | grep -v "Warning")
    rm -f tmp_exec.txt
}

# 対象ノードのホスト名を確認するため、SSHでリモートhostnameコマンドを実行させる
function exec_ssh2(){
    SSH_HOST=$1
    REMOTE_CMD=$2
    rm -f tmp_hostname.txt
    exec setsid ssh $SSH_OP $SSH_USER@$SSH_HOST $REMOTE_CMD 2>&1 | tee -a >> $LOGFILE tmp_hostname.txt 
    NODE_HOSTNAME=$(cat tmp_hostname.txt | grep -v "Warning")
    if [[ $(echo $NODE_HOSTNAME | grep -c 'Permission denied') -ge 1 ]];then
        rm -f tmp_hostname.txt
        log_message "!!! ERROR: The ssh password is incorrect. Or ssh is not allowed."
        fin 1
    fi
    rm -f tmp_hostname.txt
}


#root権限確認
if ((EUID != 0)); then
    #    sudo su
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

# ヘルプ表示
if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
    usage
fi

# 代替Managerでのステータス確認呼び出し処理
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

# 自IPの取得
MY_IP="$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')"

# 引数確認
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

# sshパスワードの事前チェック
exec_ssh2 'localhost' 'hostname'


# バックアップの場合、対象ノードをleave する。
if [ $BACKUP_FLG -eq 1 ] ; then

    # 作業初期のクラスタノードのIPを取得しておく。（最後のメッセージ表示用）
    all_ip_set
    ALL_MNG_IP=$(echo "${MNG_ARR[*]}" | tr -s ' ' ',')
    ALL_BRO_IP=$(echo "${BRO_ARR[*]}" | tr -s ' ' ',')

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

    # 対象ノードの確認表示
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
        # 離脱
        log_message "    Leaving $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        exec_ssh2 $i "hostname"
        # ステータスがDownになるのを待つ(rm出来ない)
        status_check $NODE_HOSTNAME "Down"
        # ノードを削除
        log_message "    Removing $i"
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) >> $LOGFILE 2>&1
        log_message "      Done"
    done

    # Managerノード
    MY_FLG=0
    for i in "${MNG_ARR[@]}"
    do
        # 自分自身は最後に
        if [ "$i" == "$MY_IP" ] || [ "$i" == "${HOSTNAME}" ] ;then 
            MY_FLG=1
            continue
        fi

        log_message "  Leave $i"
        check_nodes > /dev/null
        exec_ssh2 $i "hostname"
        # 対象ノードのホスト名がクラスタのノードリストに無い場合はスキップ
        if [ $(docker node ls | grep -c $NODE_HOSTNAME) -eq 0 ];then
            log_message "!!! WARNING: $NODE_HOSTNAME dose not exist. Skip."
            continue
        fi
        # まずは降格
        log_message "    Demoting $NODE_HOSTNAME"
        docker node demote $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1)  >> $LOGFILE  2>&1
        # 続いて離脱
        log_message "    Leaveing $i"
        exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
        # ステータスがDownになるのを待つ(rm出来ない)
        status_check $NODE_HOSTNAME "Down"
        # ノードを削除
        log_message "    Removing $i"
        docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) >> $LOGFILE 2>&1
        log_message "      Done"
    done

    # 対象に自分のIPが含まれている場合
    if [ $MY_FLG -eq 1 ] ; then
        check_nodes > /dev/null
        # 自分が最後の有効なManagerノードの場合
        if [ $ALLIVE_MNG_CNT -eq 1 ] && [ $ALL_FLG -eq 0 ] ; then
            log_message " INFO: All Managers will be leaving."
            if [ $SILENT_FLG -eq 0 ] ; then
                while :
                do
                    echo "  最後のManagerノードが離脱します。Workerが残っている場合、それらも離脱させます。"
                    echo -n "  本当に進めてよろしいですか？ [y/N]: "
                        read -r ANSWER
                        echo "    ANSWER: $ANSWER" >> $LOGFILE            
                        case $ANSWER in
                            "Y" | "y" | "yse" | "Yes" | "YES" )
                                break
                                ;;
                            "" | "n" | "N" | "no" | "No" | "NO" )
                                log_message "[Stop] Backup pre-processing. "
                                check_nodes
                                fin 0
                                ;;
                            * )
                                echo "YまたはNで答えて下さい。"
                                ;;
                        esac
                done
                ALL_FLG=1
            fi
            # 残っているノードのIPを再セット
            all_ip_set
            # Browserを離脱
            for i in "${BRO_ARR[@]}"
            do
                log_message "  Leave $i"
                # 離脱
                log_message "    Leaving $i"
                exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
                exec_ssh2 $i "hostname"
                # ステータスがDownになるのを待つ(rm出来ない)
                status_check $NODE_HOSTNAME "Down"
                # ノードを削除
                docker node rm $(docker node ls | grep $NODE_HOSTNAME | cut -d ' ' -f 1) >> $LOGFILE 2>&1
            done  
            # 自分自身をLeave         
            log_message "  Leave $MY_IP"
            log_message "    Leaveing myself $MY_IP"
            docker swarm leave -f >> $LOGFILE 2>&1
            log_message "     Done"
        elif [ $ALLIVE_MNG_CNT -ne 1 ] && [ $ALL_FLG -eq 0 ] ; then
            # 他のManagerからコマンドを代替実行させる
            alt_mng_ip
            log_message "  Leave $MY_IP"
            if [ $(docker node ls | grep -c ${HOSTNAME}) -eq 0 ];then
                log_message "!!! WARNING: ${HOSTNAME} dose not exist. Skip."
            else
                # 自分自身をリモートから降格
                log_message "    Demoting myself $MY_IP"
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S docker node demote ${HOSTNAME}"
                # 自分自身を離脱
                log_message "    Leaveing myself $MY_IP"
                docker swarm leave -f >> $LOGFILE 2>&1
                # 自分自身のステータスがDownになるのを待つ(rm出来ない)：リモートから
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S $MY_PATH status_check ${HOSTNAME} Down"       
                log_message "     Done"
                # 自分自身をリモートから削除
                log_message "    Removing $MY_IP"
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S docker node rm ${HOSTNAME}"
                log_message "      Done"
                # Leave 後のリスト表示：リモートから
                exec_ssh $ALT_MNG "echo $PASSWORD | sudo -S $MY_PATH check_nodes"            
            fi
        # -aによる処理の場合は自分自身を最後にleave
        elif [ $ALL_FLG -eq 1 ] ; then
            log_message "  Leave $MY_IP"
            log_message "    Leaveing myself $MY_IP"
            docker swarm leave -f >> $LOGFILE 2>&1
            log_message "     Done"
        fi
    else
        # Leave 後のリスト表示(自分が最後のManagerの場合に実行可能)
        check_nodes
    fi
    
    #終了
    log_message "[End] Backup pre-processing. "
    log_message ""
    log_message "対象ノードをシャットダウンし、バックアップを取得してください。"

    # リストア時に実行するコマンドを提示して終了
    SHOW_ARG=""
    if [ $ALL_FLG -eq 0 ]; then
        if [ $MNG_ARG_CNT -ge 1 ]; then
            SHOW_ARG="-mng $MNG_HOSTS"
        fi
        if [ $BRO_ARG_CNT -ge 1 ]; then
            SHOW_ARG="$SHOW_ARG -b $BRO_HOSTS"
        fi
    elif [ $ALL_FLG -eq 1 ]; then
        SHOW_ARG="-mng $ALL_MNG_IP -b $ALL_BRO_IP"
    fi
    log_message "再起動後、sudo $0 restore $SHOW_ARG コマンドによりクラスタに再参加させてください。"
    fin 0

# リストアの場合
elif [ $RESTORE_FLG -eq 1 ] ; then

    log_message "[Start] Restore processing. "
    # クラスタ情報が確認できない場合（全リストアの場合）
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

    # 全リストアの場合はManagerが居ないので自分がManagerとなる。
    if [ $ALL_FLG -eq 1 ] ; then
        log_message "  Force initializing."
        docker swarm init --force-new-cluster >> $LOGFILE 
    fi

    # IPアドレス配列セット
    set_ip_arr

    # 対象ノードの確認表示
    log_message "次のノードをクラスタに再参加させます。"
    if [ $MNG_ARG_CNT -ge 1 ]; then
        # Join用コマンドの格納
        JOIN_MNG=$(docker swarm join-token manager | grep join)
        echo "    JOIN_MNG: $JOIN_MNG" >> $LOGFILE
        log_message "  Manager:"
        for i in "${MNG_ARR[@]}"
        do
            log_message "    $i"
        done
    fi
    if [ $BRO_ARG_CNT -ge 1 ]; then
        # Join用コマンドの格納
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
        # Joinの実行
        exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_BRO"
        # 前回離脱していないWorker？強制離脱して再参加
        if [ $(echo $RET_EXEC | grep -c "This node is already part of a swarm") -eq 1 ];then
            log_message "!!! WARNING: This node is already part of a swarm. Re-joining!"
            exec_ssh $i "echo $PASSWORD | sudo -S docker swarm leave -f"
            exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_BRO"
        fi
        exec_ssh2 $i "hostname"
        # ラベル付け
        log_message "    Adding labels"
        $ES_PATH/nodes.sh --add-label $NODE_HOSTNAME browser >> $LOGFILE 2>&1
        log_message "      Done"
    done

    # Managerノード
    MY_FLG=0
    for i in "${MNG_ARR[@]}"
    do
        # 自分自身はラベルだけ(全リストアの場合も自分はManagerとなっている)
        if [ "$i" == "$MY_IP" ] ;then 
            log_message "  Joining myself $i"
            log_message "    Adding labels"
            $ES_PATH/nodes.sh --add-label $HOSTNAME management >> $LOGFILE 2>&1
            $ES_PATH/nodes.sh --add-label $HOSTNAME shield_core >> $LOGFILE 2>&1
            log_message "      Done"
        else
            # Joinコマンドの実行
            log_message "  Joining $i"
            exec_ssh $i "echo $PASSWORD | sudo -S $JOIN_MNG"
            exec_ssh2 $i "hostname"
            # ラベル付け
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
    log_message ""

    if [ $ALL_FLG -eq 1 ]; then
        log_message "sudo $ES_PATH/start.sh を実行し、Shieldを再開させてください。"
    fi
    fin 0

fi


