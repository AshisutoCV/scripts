#!/usr/bin/env bash

ES_PATH=/usr/local/ericomshield

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

rm -f lic.py
#wget https://ericom-tec.ashisuto.co.jp/shield/lic.py
curl -JOLsS https://ericom-tec.ashisuto.co.jp/shield/lic.py

for container in ${all[@]}; do
    docker cp lic.py  ${container}:/scripts/lic.py
done

docker exec -t ${all[0]} python /scripts/lic.py

rm -f lic.py
