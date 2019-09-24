####################
### K.K. Ashisuto
### VER=20190920a
####################

#!/bin/bash

TARGET_FILE=""
if [ $# != 0 ];then
    TARGET_FILE="/consul/backup/$1"
fi

CONSUL_BACKUP_POD=$(kubectl get pods --namespace=management | grep consul-backup | awk {'print $1'})

kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/restore.py ${TARGET_FILE}


