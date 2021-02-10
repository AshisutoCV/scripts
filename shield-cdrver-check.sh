#!/bin/bash

####################
### K.K. Ashisuto
### VER=20210210a
####################

CURRENT_DIR=$(cd $(dirname $0); pwd)
cd $CURRENT_DIR

##### 変数 #####===================================================
SET_VER='8.3.0.256'
ERROR_FILE=${CURRENT_DIR}/error-cdr.txt
################===================================================

rm -f ${ERROR_FILE}

var=$(curl --silent -q --proxy http://127.0.0.1:3128 http://shield-stats -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36" 2>&1)
var=${var//"<br>"/" | "}
var=${var//"</h1>"/}
var=${var//"<b>"/" "}
var=${var//"</b>"/}
var=${var//"<i>"/" | "}
var=${var//"</i>"/}
var=${var//"<ul>"/" | "}
var=${var//"</ul>"/}
var=${var//"<li>"/" | "}
var=${var//"</li>"/}
var=${var//"<p>"/" | "}
var=${var//"<blockquote>"/}
var=${var//"</blockquote>"/}
#cdr_ver=$(echo "$var" | sed -e 's/^.*active_CDR:.*version: \(.*\) |  cdr_controller.*$/\1/')
cdr_ver=$(echo "$var" | sed -e 's/^.*active_CDR:\(.*\) |  cdr_controller.*$/\1/')

if [[ "$cdr_ver" = "" ]];then
        cdr_ver="N.A."
else
        cdr_ver=$(echo "$cdr_ver" | sed -e 's/^.*version: \(.*\)$/\1/')
fi

#echo $SET_VER
#echo $cdr_ver

if [[ "$SET_VER" != "$cdr_ver" ]];then
        echo "$cdr_ver" > ${ERROR_FILE}
fi

