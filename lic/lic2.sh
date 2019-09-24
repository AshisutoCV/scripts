#!/bin/bash

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 [filename]"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi



#all=($(docker ps | grep consul-server.*_management_ | grep /bin/sh | awk {'print $1'}))

#if [ ${#all[@]} -eq 0 ]; then
#    echo "Please run this command on a management node"
#    exit
#fi

rm -f licset.sh
curl -JOLsS https://ericom-tec.ashisuto.co.jp/shield/licset.sh

#for container in ${all[@]}; do
#    docker cp licset.sh  ${container}:/var/tmp/licset.sh
#done

kubectl cp --namespace=management licset.sh shield-management-consul-server-0:/var/tmp/licset.sh

#docker exec -t ${all[0]} /bin/sh /var/tmp/licset.sh

kubectl exec -t  --namespace=management shield-management-consul-server-0 /bin/sh /var/tmp/licset.sh

rm -f licset.sh
