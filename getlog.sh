#!/bin/bash

####################
### K.K. Ashisuto
### VER=20191003a
####################

#-----------------
TZ="Asia/Tokyo"
TTZ="+9:00"
#-----------------

usage() {
   echo "$0 [target log] (target date) (target time) (get filed) "
   echo
   echo "    --target_log (-L)   : 取得対象ログの種類。"
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
   echo "    --get_field (-F)    : 指定したフィールドを含むログを取得。"
   echo "    --output_dir (-O)   : 指定したディレクトリにログをファイル出力します。ファイル名は「[target_log](-get_field)_[target_date(yyyymmdd))]」。"
}

TARGET_DATE=$(date +"%Y-%m-%d")
TARGET_TIME="0000-2359"
QUERY='"match_all":{}'

for i in `seq 1 ${#}`
do
    if [ "$1" == "--help" ] || [ "$1" == "-h" ] ; then
        usage
        exit 0
    elif [ "$1" == "--target_log" ] || [ "$1" == "-L" ] ; then
        shift
        TARGET_LOG=$1
         if [[ $(cat $0 | grep -c -E "\-\s${TARGET_LOG}\"$") -eq 0 ]];then
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

if [ -z $TARGET_LOG ];then
  echo "target_logの指定は必須です。"
  usage
  exit 1
fi

if [ ! -z $GET_FIELD ];then
    QUERY='"exists":{"field":"'${GET_FIELD}'"}'
fi

if [ ! -z ${OUTPUT_DIR} ];then
    yyyymmdd=$(date --date "${TARGET_DATE}" +%Y%m%d)
    if [ ! -z ${GET_FIELD} ];then
        LOGFILE="${OUTPUT_DIR}/${TARGET_LOG}-${GET_FIELD}_${yyyymmdd}"
    else
        LOGFILE="${OUTPUT_DIR}/${TARGET_LOG}_${yyyymmdd}"
    fi
fi
sTH=${TARGET_TIME:0:2}
sTM=${TARGET_TIME:2:2}
eTH=${TARGET_TIME:5:2}
eTM=${TARGET_TIME:7:2}

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


if [ "${TARGET_LOG}" == "reports" ];then
    if [ "${sTd}" == "${eTd}" ];then
        TARGET="${TARGET_LOG}-${sTY}.${sTm}.${sTd}"
    else
        TARGET="${TARGET_LOG}-${sTY}.${sTm}.${sTd},${TARGET_LOG}-${eTY}.${eTm}.${eTd}"
    fi
elif [ "${TARGET_LOG}" == "systemalert" ] || [ "${TARGET_LOG}" == "systemtest" ]  ;then
    if [ "${sTm}" == "${eTm}" ];then
        TARGET="${TARGET_LOG}-${sTy}${sTm}"
    else
        TARGET="${TARGET_LOG}-${sTy}${sTm},${TARGET_LOG}-${eTy}${eTm}"
    fi
else
    if [ "${sTm}" == "${eTm}" ];then
        TARGET="${TARGET_LOG}-${sTY}-${sTm}-01"
    else
        TARGET="${TARGET_LOG}-${sTY}-${sTm}-01,${TARGET_LOG}-${eTY}-${eTm}-01"
    fi
fi

RET=$(kubectl exec -it --namespace=elk elasticsearch-master-0 -- /bin/curl "http://localhost:9200/${TARGET}/_search" -H 'Content-Type: application/json' -d'
    {
      "version": true,
      "from": 0,
      "size": 10000,
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
                  "gte": "'${sTY}'-'${sTm}'-'${sTd}'T'${sTH}':'${sTM}':00.000Z",
                  "lte": "'${eTY}'-'${eTm}'-'${eTd}'T'${eTH}':'${eTM}':59.999Z"
                }
              }
            }
          ]
        }
      }
    }'
)

ERROR=$(echo "$RET" | jq -r .error.type)

if [[ "${ERROR}" == "null" ]];then
if [[ $(echo "$RET" | jq -r '.hits.hits[]._source' | jq -c . | grep -c "timestamp") -ge 10000 ]];then
        echo
        echo "エラー: ヒット件数が多すぎます。target_time を短く指定するか、get_fieldにより対象を絞りこんでください。"
        echo
        exit 1
    fi
else
    echo "エラー: ${ERROR}"
    exit 1
fi

RET=$(echo "$RET" | jq -c '.hits.hits[]._source')

RES=""
while read line
do
        LEFT=$(echo $line | sed -E 's/(^.*@timestamp":)(.*$)/\1/')
        RIGHT=$(echo $line | sed -E 's/(^.*"@timestamp":.*)(,".*$)/\2/')
        TIMESTAMP=$(echo $line | sed -E 's/(^.*"@timestamp":")([^"]*)(",.*$)/\2/')
    TIMESTAMP=$(env TZ=${TZ} date --date "${TIMESTAMP}" +%Y-%m-%dT%H:%M:%S${TTZ})
    if [[ ${RES} == "" ]];then
        RES=${LEFT}'"'${TIMESTAMP}'"'${RIGHT}
    else
        RES=${RES}"\n"${LEFT}'"'${TIMESTAMP}'"'${RIGHT}
    fi
done<<END
$RET
END



if [ -z ${LOGFILE} ];then
    echo -e "$RES"
else
    echo -e "$RES" >> ${LOGFILE}
fi
