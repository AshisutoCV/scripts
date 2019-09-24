#!/bin/bash

if ((EUID !=0)); then
    echo "Usage: $0"
    echo "Pliease run it as root"
    echo "sudo $0 $@"
    exit
fi

ES_PATH="/usr/local/ericomshield"
if [ -d  "$ES_PATH" ]; then
   cd "$ES_PATH"
else
   echo ""
   exit
fi

ES_BRANCH_FILE="$ES_PATH/.esbranch"
if [ -z "$BRANCH" ]; then
    if [ -f "$ES_BRANCH_FILE" ]; then
        BRANCH=$(cat "$ES_BRANCH_FILE")
    else
        BRANCH="master"
    fi
fi


rm -f spellcheck.sh
#wget -O spellcheck.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Setup/spellcheck.sh
curl -JLsS -o spellcheck.sh https://raw.githubusercontent.com/EricomSoftwareLtd/Shield/${BRANCH}/Setup/spellcheck.sh


echo "running $ES_PATH/spellckeck.sh"
chmod +x spellcheck.sh
bash ./spellcheck.sh

