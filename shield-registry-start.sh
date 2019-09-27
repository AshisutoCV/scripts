#!/bin/bash
############################################
#####   Ericom Shield Registry Cache   #####
#######################################BH###

#Check if we are root
if ((EUID != 0)); then
    #    sudo su
    echo "Usage: $0 "
    echo " Please run it as Root"
    echo "sudo $0 $@"
    exit
fi

ES_PATH="/usr/local/ericomshield"
if [ -d  "$ES_PATH" ]; then
   cd "$ES_PATH"
else
   echo "ericomshield directory not found, please install the product first."
   exit
fi

ES_BRANCH_FILE="$ES_PATH/.esbranch"
if [ -f "$ES_BRANCH_FILE" ]; then
   BRANCH=$(cat "$ES_BRANCH_FILE")
  else
   BRANCH="master"
fi

rm -f ericom-shield-registry-start.sh
curl -JLsS -o ericom-shield-registry-start.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Utils/shield-registry-start.sh
chmod +x ericom-shield-registry-start.sh
bash ./ericom-shield-registry-start.sh

