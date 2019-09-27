#!/bin/bash

SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"

curl -JOLsS ${SCRIPTS_URL}/li/licset.sh


kubectl cp --namespace=management licset.sh shield-management-consul-server-0:/var/tmp/licset.sh
kubectl exec -t  --namespace=management shield-management-consul-server-0 /bin/sh /var/tmp/licset.sh

