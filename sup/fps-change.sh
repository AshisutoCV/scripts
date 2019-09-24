#!/usr/bin/env bash

ES_PATH=/usr/local/ericomshield

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 [filename]"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi


if [[ "$1" != "--low" && "$1" != "--high" ]]; then
    echo "--------------------- Usage -----------------------------"
    echo "Usage: "
    echo "   $0 --low  the fps is set lower."
    echo "   $0 --high  the fps is set higher."
    echo ""
    exit 1
fi

all=($(docker ps | grep consul-server | awk {'print $1'}))

if [ ${#all[@]} -eq 0 ]; then
    echo "Please run this command on a management node"
    exit
fi

rm -f fpschange.py
#wget https://ericom-tec.ashisuto.co.jp/shield/fpschange.py
curl -JOLsS https://ericom-tec.ashisuto.co.jp/shield/fpschange.py

for container in ${all[@]}; do
    docker cp fpschange.py  ${container}:/scripts/fpschange.py
done

docker exec -t ${all[0]} python /scripts/fpschange.py $1

rm -f fpschange.py
