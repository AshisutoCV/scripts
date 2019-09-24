#!/bin/sh

JSON_RESPONSE=$(consul kv get activation/license)


expireDate=$(echo $JSON_RESPONSE | jq '.expireDate')

numOfLicenses=$(echo $JSON_RESPONSE | jq '.numOfLicenses')
expireDate=`env TZ=JST-729 date +%Y-%m-%dT00:00:00.000Z`
#expireDate='"2099-12-31T23:59:59.000Z"'

JSON=$(cat << EOS
{
        "expireDate":"${expireDate}",
        "numOfLicenses":10
}
EOS

)

echo ///////////////////////////////////////////

echo $JSON_RESPONSE | jq

echo ------------------------------------------

consul kv put activation/license "$JSON"

consul kv get activation/license | jq

echo ///////////////////////////////////////////

echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


JSON_RESPONSE=$(consul kv get activation/flags)


date=$(echo $JSON_RESPONSE | jq '.[].date')
user_name=$(echo $JSON_RESPONSE | jq '.[].user_name')
opportunity_name=$(echo $JSON_RESPONSE | jq '.[].opportunity_name')
license_type=$(echo $JSON_RESPONSE | jq '.[].license_type')
no_votiro_payment=$(echo $JSON_RESPONSE | jq '.[].no_votiro_payment')
comments=$(echo $JSON_RESPONSE | jq '.[].comments')

JSON=$(cat << EOS
[{
        "date":${date},
        "user_name":"Takuya ARITA",
        "opportunity_name":"K.K. Ashisuto",
        "license_type":"Evaluation",
        "no_votiro_payment":${no_votiro_payment},
        "comments":${comments},
        "cdr_sandblast":false,
        "cdr_sasa":false,
        "votiro_avr":true,
        "cat_netstar":true,
        "allow_full_isolation":true,
        "use_ccu_license": false,
        "use_ccs_license": false
}]
EOS

)

echo ///////////////////////////////////////////

echo $JSON_RESPONSE | jq

echo ------------------------------------------

consul kv put activation/flags "$JSON"
consul kv get activation/flags | jq

echo ///////////////////////////////////////////



