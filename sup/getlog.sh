#!/bin/bash

####################
### K.K. Ashisuto
### VER=20200207a
####################

####-----------------
#TZ="Asia/Tokyo"    # 結果のtimestampをTZに調整して表示
TTZ="Asia/Tokyo"    # 検索日時の入力において、入力値をどのTZとして扱うか。
####-----------------


SIZE=10000 
if [[ ! -z ${TZ} ]];then
    SIZE=100
    nTZ=$(env TZ=${TZ} date +%z | sed -e s/00$/:00/)
fi

usage() {
   echo "$0 [target log] (target date) (target time) (get filed) (output_dir)"
   echo
   echo "    --target_log (-L)   : 取得対象ログの種類。 "
   echo "                           複数指定可能。複数指定の場合はそれぞれにオプションをつけること。 (ex.: -L connections -L applications)"
   echo "                           - connections"
   echo "                           - applications"
   echo "                           - file-sanitization"
   echo "                           - file-transfer"
   echo "                           - file-preview"
   echo "                           - file-download"
   echo "                           - systemusage"
   echo "                           - systemalert"
   echo "                           - systemtest"
   echo "                           - errors"
   echo "                           - feedback"
   echo "                           - phishing (k8sのみ)"
   echo "                           - reports (k8sのみ)"
   echo "                           - allsystemstats (swarmのみ)"
   echo "                           - connectioninfo (swarmのみ)"
   echo "                           - scalebrowser (swarmのみ)"
   echo "                           - raw (swarmのみ)"
   echo "    --target_date (-D)  : 取得対象日。(YYYY-MM-DD)。 省略した場合は本日。"
   echo "    --target_time (-T)  : 取得対象時刻。開始時刻-終了時刻(HHMM-HHMM)。 省略した場合24時間。(0000-2359)"
   echo "                           (秒を含めた6桁でも対応。 ex.: 095500-095505)"
   echo "    --get_field (-F)    : 指定したフィールドを含むログを取得。"
   echo "    --output_dir (-O)   : 指定したディレクトリにログをファイル出力します。ファイル名は「[target_log](-get_field)_[target_date(yyyymmdd))]」。"
}


TARGET_DATE=$(env TZ=${TTZ} date +"%Y-%m-%d")
TARGET_TIME="0000-2359"
QUERY='"match_all":{}'
TARGET_LOGs=()

#OS Check
if [ -f /etc/redhat-release ]; then
    OS="RHEL"
else
    OS="Ubuntu"
fi
# install jq
if ! which jq > /dev/null 2>&1 ;then
    echo "Need install jq. installing..."
    if [[ $OS == "Ubuntu" ]]; then
        sudo apt-get install -y -qq jq
    elif [[ $OS == "RHEL" ]]; then
        sudo yum -y -q install epel-release
        sudo yum -y -q install jq
    fi
    if ! which jq > /dev/null 2>&1 ;then
        echo "failed to install jq. exiting."
        exit 1
    fi
fi

for i in `seq 1 ${#}`
do
    if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
        usage
        exit 0
    elif [ "$1" == "--target_log" ] || [ "$1" == "-L" ] ; then
        shift
        TARGET_LOG=$1
        TARGET_LOGs+=( ${TARGET_LOG} )
         if [[ $(cat $0 | grep -c -E "\-\s${TARGET_LOG}\"$") -eq 0 ]] && [[ $(cat $0 | grep -c -E "\-\s${TARGET_LOG} (.*)\"$") -eq 0 ]];then
             echo "エラー: target_logの指定が不正です。"
             usage
             exit 1
         fi
    elif [ "$1" == "--target_date" ] || [ "$1" == "-D" ] ; then
        shift
        TARGET_DATE=$1
    elif [ "$1" == "--target_time" ] || [ "$1" == "-T" ] ; then
        shift
        TARGET_TIME=$1
    elif [ "$1" == "--get_field" ] || [ "$1" == "-F" ] ; then
        shift
        GET_FIELD=$1
    elif [ "$1" == "--output_dir" ] || [ "$1" == "-O" ] ; then
        shift
        OUTPUT_DIR=$1
        if [ ! -e ${OUTPUT_DIR} ];then
            mkdir -p ${OUTPUT_DIR}
        fi
    else
        args="${args} ${1}"
    fi
    shift
done

if [ ! -z ${args} ]; then
    echo "${args} は不正な引数です。"
    usage
    exit 1
fi

if [[ ${#TARGET_LOGs[@]} -eq 0 ]];then
  echo "target_logの指定は必須です。"
  usage
  exit 1
fi

if [ ! -z $GET_FIELD ];then
    QUERY='"exists":{"field":"'${GET_FIELD}'"}'
fi

if [ ! -z ${OUTPUT_DIR} ];then
    yyyymmdd=$(date --date "${TARGET_DATE}" +%Y%m%d)
    if [[ ${#TARGET_LOGs[@]} -ge 2 ]];then
        TARGET_LOG="getlogs"
    fi
    if [ ! -z ${GET_FIELD} ];then
        LOGFILE="${OUTPUT_DIR}/${TARGET_LOG}-${GET_FIELD}_${yyyymmdd}"
    else
        LOGFILE="${OUTPUT_DIR}/${TARGET_LOG}_${yyyymmdd}"
    fi
fi

if [[ ${#TARGET_TIME} -eq 9 ]];then
    sTH=${TARGET_TIME:0:2}
    sTM=${TARGET_TIME:2:2}
    sTS=00
    eTH=${TARGET_TIME:5:2}
    eTM=${TARGET_TIME:7:2}
    eTS=59
else
    sTH=${TARGET_TIME:0:2}
    sTM=${TARGET_TIME:2:2}
    sTS=${TARGET_TIME:4:2}
    eTH=${TARGET_TIME:7:2}
    eTM=${TARGET_TIME:9:2}
    eTS=${TARGET_TIME:11:2}
fi


sTY=$(env TZ=UTC date --date "${TARGET_DATE} ${sTH}:${sTM}" +%Y)
sTy=$(env TZ=UTC date --date "${TARGET_DATE} ${sTH}:${sTM}" +%y)
sTm=$(env TZ=UTC date --date "${TARGET_DATE} ${sTH}:${sTM}" +%m)
sTd=$(env TZ=UTC date --date "${TARGET_DATE} ${sTH}:${sTM}" +%d)
eTY=$(env TZ=UTC date --date "${TARGET_DATE} ${eTH}:${eTM}" +%Y)
eTy=$(env TZ=UTC date --date "${TARGET_DATE} ${eTH}:${eTM}" +%y)
eTm=$(env TZ=UTC date --date "${TARGET_DATE} ${eTH}:${eTM}" +%m)
eTd=$(env TZ=UTC date --date "${TARGET_DATE} ${eTH}:${eTM}" +%d)
sTH=$(env TZ=UTC date --date "${TARGET_DATE} ${sTH}:${sTM}" +%H)
eTH=$(env TZ=UTC date --date "${TARGET_DATE} ${eTH}:${eTM}" +%H)

i=0
for e in ${TARGET_LOGs[@]}; do
    if [[ $i -eq 0 ]];then
        TARGET="${e}-*"
    else
        TARGET="${TARGET},${e}-*"
    fi
    let i++
done

ELASTIC_PORT="9100"
if which kubectl > /dev/null 2>&1 ; then
    kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:9100/" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:9200/" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Error.  elasticserachのポートが特定できません。"
            exit 1
        else
            ELASTIC_PORT="9200"
        fi
    fi
    RET=$(kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:${ELASTIC_PORT}/${TARGET}/_search?scroll=1m" -H 'Content-Type: application/json' -d'
        {
          "version": true,
          "from": 0,
          "size": '${SIZE}',
          "sort": [
            {
              "@timestamp": {
                "order": "asc",
                "unmapped_type": "boolean"
              }
            }
          ],
          "_source": {
          },
          "stored_fields": [
            "*"
          ],
          "query": {
            "bool": {
              "must": [
                {
                  '${QUERY}'
                },
                {
                  "range": {
                    "@timestamp": {
                      "format": "strict_date_optional_time",
                      "gte": "'${sTY}'-'${sTm}'-'${sTd}'T'${sTH}':'${sTM}':'${sTS}'.000Z",
                      "lte": "'${eTY}'-'${eTm}'-'${eTd}'T'${eTH}':'${eTM}':'${eTS}'.999Z"
                    }
                  }
                }
              ]
            }
          }
        }'
    )
else
    ELKCONTAINER=$(sudo docker ps |grep shield-elk | cut -d" " -f 1)
    sudo docker exec -it ${ELKCONTAINER}  /usr/bin/curl -XGET "http://localhost:9100/" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
            sudo docker exec -it ${ELKCONTAINER}  /usr/bin/curl -XGET "http://localhost:9200/" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Error.  elasticserachのポートが特定できません。"
            exit 1
        else
            ELASTIC_PORT="9200"
        fi
    fi
    RET=$(sudo docker exec -it ${ELKCONTAINER}  /usr/bin/curl -XGET "http://localhost:${ELASTIC_PORT}/${TARGET}/_search?scroll=1m" -H 'Content-Type: application/json' -d'
        {
          "version": true,
          "from": 0,
          "size": '${SIZE}',
          "sort": [
            {
              "@timestamp": {
                "order": "asc",
                "unmapped_type": "boolean"
              }
            }
          ],
          "_source": {
          },
          "stored_fields": [
            "*"
          ],
          "query": {
            "bool": {
              "must": [
                {
                  '${QUERY}'
                },
                {
                  "range": {
                    "@timestamp": {
                      "format": "strict_date_optional_time",
                      "gte": "'${sTY}'-'${sTm}'-'${sTd}'T'${sTH}':'${sTM}':'${sTS}'.000Z",
                      "lte": "'${eTY}'-'${eTm}'-'${eTd}'T'${eTH}':'${eTM}':'${eTS}'.999Z"
                    }
                  }
                }
              ]
            }
          }
        }'
    )
fi

next_flg=1
first_scroll=1
while [[ $next_flg -eq 1 ]]
do
    if [[ ${first_scroll} -ne 1 ]];then
        if which kubectl > /dev/null 2>&1 ; then
            RET=$(kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:${ELASTIC_PORT}/_search/scroll" -H 'Content-Type: application/json' -d'
            {
                "scroll": "1m",
                "scroll_id" : '${SCROLL_ID}'
            }')
        else
            RET=$(sudo docker exec -it ${ELKCONTAINER}  /usr/bin/curl -XGET "http://localhost:${ELASTIC_PORT}/_search/scroll" -H 'Content-Type: application/json' -d'
            {
                "scroll": "1m",
                "scroll_id" : '${SCROLL_ID}'
            }')
        fi
    else
        SCROLL_ID=$(echo "$RET" | jq -c ._scroll_id)
    fi
    first_scroll=0
    ERROR=$(echo "$RET" | jq -r .error.type)
    if [[ "${ERROR}" == "null" ]];then
        RET=$(echo "$RET" | jq -c '.hits.hits[]._source')
        if  [[ ${#RET} -eq 0 ]];then
            next_flg=0
            if which kubectl > /dev/null 2>&1 ; then
                kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XDELETE "http://localhost:${ELASTIC_PORT}/_search/scroll" -H 'Content-Type: application/json' -d'
                {
                    "scroll_id" : '${SCROLL_ID}'
                }' >/dev/null
            else
                sudo docker exec -it ${ELKCONTAINER}  /usr/bin/curl -XDELETE "http://localhost:${ELASTIC_PORT}/_search/scroll" -H 'Content-Type: application/json' -d'
                {
                    "scroll_id" : '${SCROLL_ID}'
                }' >/dev/null
            fi
            if [[ ${#RET} -eq 0 ]];then
                exit 0
            fi
        fi
    else
        echo "エラー: ${ERROR}"
        exit 1
    fi


    if [[ ! -z ${TZ} ]];then
        RES=""
        while read -r line
        do
            LEFT=$(echo $line | sed -E 's/(^.*@timestamp":)(.*$)/\1/')
            RIGHT=$(echo $line | sed -E 's/(^.*"@timestamp":"[^"]*")(.*$)/\2/')
            TIMESTAMP=$(echo $line | sed -E 's/(^.*"@timestamp":")([^"]*)(.*$)/\2/')
            TIMESTAMP=$(env TZ=${TZ} date --date "${TIMESTAMP}" +%Y-%m-%dT%H:%M:%S.%3N${nTZ})
            if [[ ${RES} == "" ]];then
                RES=${LEFT}'"'${TIMESTAMP}'"'${RIGHT}
            else
                RES=${RES}${LEFT}'"'${TIMESTAMP}'"'${RIGHT}
            fi
        done <<END
$RET
END

    else
        RES=${RET}
    fi


    if [ -z ${LOGFILE} ];then
        echo ${RES}  | jq -c '[ ."@timestamp", .]'
    else
        echo ${RES}  | jq -c '[ ."@timestamp", .]' >> ${LOGFILE}
    fi

done