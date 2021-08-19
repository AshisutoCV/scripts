#!/bin/bash

####################
### K.K. Ashisuto
### VER=20210819b
####################

if ((EUID !=0)); then
    echo "Usage: $0"
    echo "Pliease run it as root"
    echo "sudo $0 $@"
    exit
fi

if [ -f /etc/redhat-release ]; then
    OS="RHEL"
else
    OS="Ubuntu"
fi

#while [ $# -ne 0 ]; do
#    arg="$1"
#    case "$arg" in
#    -u | --user)
#        MACHINE_USE="$2"
#        shift
#        ;;
#    -os | --os-user)
#        MACHINE_USER=$(whoami)
#        ;;
#    esac
#    shift
#done

if [ -z "$MACHINE_USER" ]; then
    echo '################################################### Create Ericom user #################################'
    if [[ $(cat /etc/passwd | grep -c ericom) -eq 0 ]];then
        if [[ $OS == "Ubuntu" ]]; then
            sudo adduser --gecos "" ericom
            sudo mkdir -p "/home/ericom/"
        else
            sudo adduser ericom
            sudo passwd ericom
        fi
        MACHINE_USER="ericom"
    else
        MACHINE_USER="ericom"
        echo "======[ 注意事項 ]=========================================================================="
        echo "ericom ユーザが既に存在します。"
        echo "ericom ユーザのパスワードは全Shieldサーバで統一したパスワードを設定する必要があります。"
        echo "これは、以降の作業にて統一されたパスワードのericomユーザにSSH接続を行い処理が行われるためです。"
        echo "パスワードが統一されていない場合には確認の上、事前に変更をお願いします。"
        echo "==========================================================================================="
    fi
else
    echo "======[ 注意事項 ]=========================================================================="
    echo "$MACHINE_USER ユーザのパスワードは全Shieldサーバで統一したパスワードを設定する必要があります。"
    echo "これは、以降の作業にて統一されたパスワードのericomユーザにSSH接続を行い処理が行われるためです。"
    echo "パスワードが統一されていない場合には確認の上、事前に変更をお願いします。"
    echo "==========================================================================================="
fi


echo "########################## $MACHINE_USER Going to prepare super user #########################################"
if [[ $(sudo cat /etc/sudoers | grep -c "$MACHINE_USER ALL=(ALL:ALL) NOPASSWD: ALL") -eq 0 ]];then

    COMMAND="$MACHINE_USER ALL=(ALL:ALL) NOPASSWD: ALL"
    echo $COMMAND | sudo EDITOR='tee -a' visudo
else
    echo "既に設定済みです。"
fi

echo '################################################### Changeing sshd_conf #################################'
sudo sed -i -e '/^PasswordAuthentication/s/no/yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

if [[ $OS == "Ubuntu" ]]; then
    echo '################################################### Changing to the symbolic link. /etc/resolv.conf #################################'
        echo "[start] Changing to the symbolic link."
        if [[ ! -L /etc/resolv.conf ]];then
            echo "[WARN]/etc/resolv.conf is NOT symlink"
            if [[ $(cat /etc/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                echo "[WARN] nameserver is local stub!"
                if [[ -f /run/systemd/resolve/resolv.conf ]];then
                    echo "[INFO] /run/systemd/resolve/resolv.conf exist!"
                    if [[ $(cat /run/systemd/resolve/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                        echo "[WARN] /run/systemd/resolve/resolv.conf が local stub になっています。確認してください。"
                        fin 1
                    else
                        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                        sudo systemctl restart systemd-resolved
                        log_message "[INFO] Changed to symlink"
                        echo "ノードを再起動してください。"
                        exit 0
                    fi
                else
                    echo "[WARN]　/run/systemd/resolve/resolv.conf が存在しません。確認してください。"
                    exit 1
                fi
            else
                echo "[INFO ] nameserver is not local stub! Continue!"
            fi
        else
            echo "[INFO]/etc/resolv.conf is symlink"
            if [[ $(cat /etc/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                echo "[WARN] nameserver is local stub!"
                if [[ -f /run/systemd/resolve/resolv.conf ]];then
                    echo "[INFO] /run/systemd/resolve/resolv.conf exist!"
                    if [[ $(cat /run/systemd/resolve/resolv.conf | grep -v '#' | grep -c 127.0.0.53) -ne 0 ]];then
                        echo "[WARN] /run/systemd/resolve/resolv.conf が local stub になっています。確認してください。"
                        exit 1
                    else
                        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                        sudo systemctl restart systemd-resolved
                        echo "[INFO] Changed to symlink"
                        echo "ノードを再起動してください。"
                        exit 0
                    fi
                else
                    echo "/run/systemd/resolve/resolv.conf が存在しません。確認してください。"
                    exit 1
                fi
            else
                echo "[INFO ] nameserver is not local stub! Continue!"
            fi
        fi
        echo "[end] Changing to the symbolic link."
        exit 0
    echo '################################################### Done #################################'
fi
