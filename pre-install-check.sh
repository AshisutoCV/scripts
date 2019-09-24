#!/bin/bash

if ((EUID !=0)); then
    echo "Usage: $0"
    echo "Pliease run it as root"
    echo "sudo $0 $@"
    exit
fi

rm -f shield-pre-install-check.sh
#wget -O shield-pre-install-check.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Setup/shield-pre-install-check.sh
curl -JLsS -o shield-pre-install-check.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Setup/shield-pre-install-check.sh

chmod +x shield-pre-install-check.sh
echo "preparing..."
apt-get -qq update
bash ./shield-pre-install-check.sh

