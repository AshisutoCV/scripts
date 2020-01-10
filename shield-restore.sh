#!/bin/bash

####################
### K.K. Ashisuto
### VER=20191008a
####################

CONSUL_BACKUP_POD=$(kubectl get pods --namespace=management | grep consul-backup | awk {'print $1'})

if [ $# != 0 ];then
    TARGET_FILE="/consul/backup/$1"
else
    TARGET_FILE=$(kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} -- ls -1t /consul/backup/ | grep json | head -1)
fi

kubectl exec -t --namespace=management ${CONSUL_BACKUP_POD} python /scripts/restore.py ${TARGET_FILE}
