#!/bin/bash
############################################
#####   Ericom Shield Installer        #####
#######################################BH###
################  K.K.Ashisuto #############

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/scripts/master"

#Check if we are root
if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 [-f|--force] [--autoupdate]"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

get_os_dist() {
    if [ -e /etc/lsb-release ]; then
        # Ubuntu
        dist_name="ubuntu"
    elif [ -e /etc/redhat-release ]; then
        if [ $(grep -c CentOS /etc/redhat-release) ]; then
            dist_name="centos"
        elif [ $(grep -c "Red Hat" /etc/redhat-release) ]; then
            # Red Hat Enterprise Linux
            dist_name="redhat"
        fi
    else
        echo "This OS is probably out of support."
        exit 1
    fi
}


pre_flg=0
args=""
dev_flg=0
stg_flg=0
ver_flg=0
BRANCH="master"

for i in `seq 1 ${#}`
do
    if [ "$1" == "--pre-use" ]; then
        pre_flg=1
    elif [ "$1" == "-dev" ] || [ "$1" == "--Dev" ] ; then
        dev_flg=1
    elif [ "$1" == "-staging" ] || [ "$1" == "--Staging" ] ; then
        stg_flg=1
    elif [ "$1" == "-v" ] || [ "$1" == "-version" ] || [ "$1" == "--version" ] ; then
        shift
        BRANCH="$1"
        ver_flg=1
    else
        args="${args} ${1}"
    fi
    shift
done

get_os_dist


if [ $pre_flg -eq 1 ] ; then
    if [ "$dist_name" == "ubuntu" ]; then
        BRANCH=$( curl -sL ${SCRIPTS_URL}/TEST/TEST-pre-rel-ver.txt )
    else
        BRANCH=$( curl -sL ${SCRIPTS_URL}/TEST/TEST-centos-pre-rel-ver.txt )
    fi
    if [ "$BRANCH" == "NA" ]; then
        echo "現在ご利用可能なリリース前先行利用バージョンはありません。"
        exit 1
    else
        echo -n "リリース前先行利用バージョン ${BRANCH} をセットアップします。[Y/n]:"
        read ANSWER
        case $ANSWER in
            "" | "Y" | "y" | "yes" | "Yes" | "YES" ) echo "Start."
                                                     ;;
            * ) echo "STOP."
                exit 1
                ;;
        esac
    fi
elif [ $dev_flg -eq 1 ] ; then
    if [ $BRANCH == "master" ] ; then
        BRANCH="Dev"
    fi
elif [ $stg_flg -eq 1 ] ; then
    if  [ $BRANCH == "master" ] ; then
        BRANCH="Staging"
    fi
elif [ $ver_flg -eq 1 ] ; then
    if  [ $BRANCH == "master" ] ; then
        BRANCH="master"
    fi
else
    declare -A vers
    n=0
    echo "どのバージョンをセットアップしますか？"

    if [ "$dist_name" == "ubuntu" ]; then
        for i in $( curl -sL ${SCRIPTS_URL}/TEST/TEST-rel-ver.txt )
        do
            n=$(( $n + 1 ))
            vers[$n]=$i
            echo "$n: $i"
        done
    else
        for i in $( curl -sL ${SCRIPTS_URL}/TEST/TEST-centos-rel-ver.txt )
        do
            n=$(( $n + 1 ))
            vers[$n]=$i
            echo "$n: $i"
        done
    fi

    while :
    do
        echo
        echo -n " 番号で指定してください: "
        read answer
        if [ -z ${vers[$answer]} ] ; then
                echo "番号が違っています。"
        else
                BRANCH=${vers[$answer]}
                echo "$BRANCH をセットアップします。"
                break
        fi
    done
fi


if [ "$dist_name" = "ubuntu" ]; then
    rm -f ericomshield-setup.sh
    curl -JOLsS https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Setup/ericomshield-setup.sh


    chmod +x ericomshield-setup.sh
    echo "preparing..."
    apt-get -qq update

    if [ $dev_flg -eq 1 ]; then
        bash ./ericomshield-setup.sh --Dev --version $BRANCH ${args}
    elif [ $stg_flg -eq 1 ]; then
        bash ./ericomshield-setup.sh --Staging --version $BRANCH ${args}
    else
        if [ ${BRANCH:4:2}${BRANCH:7:2} -le 1809 ]; then
            bash ./ericomshield-setup.sh ${args} -version $BRANCH
        else
            bash ./ericomshield-setup.sh ${args} --version $BRANCH
        fi
    fi

else
    rm -f ericomshield-setup-rhel.sh
    curl -JOLsS "https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Setup/rpm/ericomshield-setup-rhel.sh"

    chmod +x ericomshield-setup-rhel.sh
    bash ./ericomshield-setup-rhel.sh $BRANCH
fi
