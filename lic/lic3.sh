#!/bin/bash

if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 [filename]"
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi



curl -JOLsS https://ericom-tec.ashisuto.co.jp/shield/licset3.sh

kubectl cp --namespace=management licset3.sh shield-management-consul-0:/var/tmp/licset3.sh

kubectl exec -t  --namespace=management shield-management-consul-0 /bin/sh /var/tmp/licset3.sh

