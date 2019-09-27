#!/bin/bash
############################################
#####   Ericom Shield Version Changer  #####
################  K.K.Ashisuto #############

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

#Check if we are root
if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

if [ ! -d /usr/local/ericomshield ]; then
    echo "Ericom Shield はインストールされていません。"
    exit 1
fi


NOW_VER="$(sed -n 1p  /usr/local/ericomshield/shield-version.txt | awk 'match($0, /(Rel|Staging|Dev).*on/) {print substr($0, RSTART, RLENGTH)}' | cut -d' ' -f1)"

echo "=========================================================="
echo -n "現在のインストール済みバージョン："
echo "$NOW_VER"
echo -n "現在のターゲットバージョン："
echo "$(cat /usr/local/ericomshield/.esbranch)"
echo "=========================================================="
echo ""


pre_flg=0
args=""

for i in `seq 1 ${#}`
do
    if [ "$1" == "--pre-use" ]; then
        pre_flg=1
    else
        args="${args} ${1}"
    fi
    shift
done

if [ $pre_flg -eq 1 ] ; then
    BRANCH=$( curl -sL ${SCRIPTS_URL}/TEST/TEST-pre-rel-ver.txt )
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
else
    declare -A vers
    n=0
    echo "どのバージョンをターゲットとしてセットしますか？"
    for i in $( curl -sL ${SCRIPTS_URL}/TEST/TEST-rel-ver.txt )
    do
        n=$(( $n + 1 ))
        vers[$n]=$i
        echo "$n: $i"
    done

    while :
    do
        echo
        echo -n " 番号で指定してください: "
        read answer
        if [ -z ${vers[$answer]} ] ; then
                echo "番号が違っています。"
        else
                BRANCH=${vers[$answer]}
                break
        fi
    done
fi

echo $BRANCH >  /usr/local/ericomshield/.esbranch
echo "=========================================================="
echo -n "新しいターゲットバージョン："
echo "$(cat /usr/local/ericomshield/.esbranch)"
mv /usr/local/ericomshield/update.sh /usr/local/ericomshield/update.sh-BAK
curl -JLsS -o /usr/local/ericomshield/update.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Setup/update.sh
chmod +x /usr/local/ericomshield/update.sh && rm -f /usr/local/ericomshield/update.sh-BAK


