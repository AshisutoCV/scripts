#!/bin/sh

#expireDate=`env TZ=JST-729 date +%Y-%m-%dT00:00:00.000Z`
expireDate='2099-12-31T23:59:59.000Z'

JSON=$(cat << EOS
{
    "expireDate":"${expireDate}",
    "numOfLicenses":50
}
EOS
)

echo ///////////////////////////////////////////

consul kv put activation/license "$JSON"

consul kv get activation/license

echo ///////////////////////////////////////////

echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

JSON=$(cat << EOS
[{
    "date":"2019-01-01",
    "user_name":"Takuya ARITA",
    "opportunity_name":"K.K. Ashisuto",
    "license_type":"Evaluation",
    "no_votiro_payment":false,
    "comments":"KKA test",
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

consul kv put activation/flags "$JSON"
consul kv get activation/flags

echo ///////////////////////////////////////////


