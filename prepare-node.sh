#!/bin/bash

if ((EUID !=0)); then
    echo "Usage: $0"
    echo "Pliease run it as root"
    echo "sudo $0 $@"
    exit
fi

rm -f shield-prepare-node.sh
#wget -O shield-prepare-node.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Setup/prepare-node.sh
curl -JLsS -o shield-prepare-node.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/master/Setup/prepare-node.sh


chmod +x shield-prepare-node.sh
bash ./shield-prepare-node.sh

