#!/bin/bash

#SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/shield"
SCRIPTS_URL="https://ericom-tec.ashisuto.co.jp/dev-scripts/develop"

curl -JOLsS ${SCRIPTS_URL}/lic/licset3.sh

kubectl cp --namespace=management licset3.sh shield-management-consul-0:/var/tmp/licset3.sh

kubectl exec -t  --namespace=management shield-management-consul-0 /bin/sh /var/tmp/licset3.sh

