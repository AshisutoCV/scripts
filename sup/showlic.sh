#!/usr/bin/env bash

ES_PATH=/usr/local/ericomshield
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 [filename]"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi



all=($(docker ps | grep consul-server | awk {'print $1'}))

if [ ${#all[@]} -eq 0 ]; then
    echo "Please run this command on a management node"
    exit
fi

rm -f showlic.py
curl -JOLsS ${SCRIPTS_URL}/showlic.py

for container in ${all[@]}; do
    docker cp showlic.py  ${container}:/scripts/showlic.py
done

docker exec -t ${all[0]} python /scripts/showlic.py

rm -f showlic.py
