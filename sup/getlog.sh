#!/bin/bash

####################
### K.K. Ashisuto
### VER=20191031a
####################

####-----------------
#TZ="Asia/Tokyo"    # 結果のtimestampをTZに調整して表示
TTZ="+9:00"        # 検索時間のズレを調整するため設定を推奨
####-----------------
SIZE=10000 
if [[ ! -z ${TZ} ]];then
    SIZE=100
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
   echo "                           - errors"
   echo "                           - systemusage"
   echo "                           - systemalert"
   echo "                           - systemtest"
   echo "                           - reports"
   echo "    --target_date (-D)  : 取得対象日。(YYYY-MM-DD)。 省略した場合は本日。"
   echo "    --target_time (-T)  : 取得対象時刻。開始時刻-終了時刻(HHMM-HHMM)。 省略した場合24時間。(0000-2359)"
   echo "                           (秒を含めた6桁でも対応。 ex.: 095500-095505)"
   echo "    --get_field (-F)    : 指定したフィールドを含むログを取得。"
   echo "    --output_dir (-O)   : 指定したディレクトリにログをファイル出力します。ファイル名は「[target_log](-get_field)_[target_date(yyyymmdd))]」。"
}

TARGET_DATE=$(date +"%Y-%m-%d")
TARGET_TIME="0000-2359"
QUERY='"match_all":{}'
TARGET_LOGs=()

for i in `seq 1 ${#}`
do
    if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
        usage
        exit 0
    elif [ "$1" == "--target_log" ] || [ "$1" == "-L" ] ; then
        shift
        TARGET_LOG=$1
        TARGET_LOGs+=( ${TARGET_LOG} )
         if [[ $(cat $0 | grep -c -E "\-\s${TARGET_LOG}\"$") -eq 0 ]] && [[ "${TARGET_LOG}" != "*" ]];then
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


sTY=$(date --date "${TARGET_DATE} ${sTH}:${sTM} ${TTZ}" +%Y)
sTy=$(date --date "${TARGET_DATE} ${sTH}:${sTM} ${TTZ}" +%y)
sTm=$(date --date "${TARGET_DATE} ${sTH}:${sTM} ${TTZ}" +%m)
sTd=$(date --date "${TARGET_DATE} ${sTH}:${sTM} ${TTZ}" +%d)
eTY=$(date --date "${TARGET_DATE} ${eTH}:${eTM} ${TTZ}" +%Y)
eTy=$(date --date "${TARGET_DATE} ${eTH}:${eTM} ${TTZ}" +%y)
eTm=$(date --date "${TARGET_DATE} ${eTH}:${eTM} ${TTZ}" +%m)
eTd=$(date --date "${TARGET_DATE} ${eTH}:${eTM} ${TTZ}" +%d)
sTH=$(date --date "${sTH} ${TTZ}" +%H)
eTH=$(date --date "${eTH} ${TTZ}" +%H)

i=0
for e in ${TARGET_LOGs[@]}; do
    if [[ $i -eq 0 ]];then
        TARGET="${e}-*"
    else
        TARGET="${TARGET},${e}-*"
    fi
    let i++
done

RET=$(kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:9200/${TARGET}/_search?scroll=1m" -H 'Content-Type: application/json' -d'
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

next_flg=1
first_scroll=1
while [[ $next_flg -eq 1 ]]
do
    if [[ ${first_scroll} -ne 1 ]];then
            RET=$(kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XGET "http://localhost:9200/_search/scroll" -H 'Content-Type: application/json' -d'
            {
                "scroll": "1m",
                "scroll_id" : '${SCROLL_ID}'
            }')
    else
        SCROLL_ID=$(echo "$RET" | jq -c ._scroll_id)
    fi
    first_scroll=0
    ERROR=$(echo "$RET" | jq -r .error.type)
    if [[ "${ERROR}" == "null" ]];then
        RET=$(echo "$RET" | jq -c '.hits.hits[]._source')
        if  [[ ${#RET} -eq 0 ]];then
            next_flg=0
            kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl -XDELETE "http://localhost:9200/_search/scroll" -H 'Content-Type: application/json' -d'
            {
                "scroll_id" : '${SCROLL_ID}'
            }' >/dev/null
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
            TIMESTAMP=$(env TZ=${TZ} date --date "${TIMESTAMP}" +%Y-%m-%dT%H:%M:%S.%3N${TTZ})
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