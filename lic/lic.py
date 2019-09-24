#!/usr/bin/python3

import json, argparse, subprocess
import pprint

def get_current_activation_object():
    string = subprocess.check_output("consul kv get activation/license", shell=True).decode("UTF-8")
    return json.loads(string)

def get_current_activation_object2():
    string = subprocess.check_output("consul kv get activation/flags", shell=True).decode("UTF-8")
    return json.loads(string[1:-2])

def save_current_object(current_object):
    subprocess.run("consul kv put activation/license '{}'".format(json.dumps(current_object)), shell=True)

def save_current_object2(current_object):
    current_object = json.dumps(current_object)    
    
    subprocess.run("consul kv put activation/flags '[{}]'".format(current_object), shell=True)

def main():
    current_object = get_current_activation_object()
    pprint.pprint( current_object )
    if current_object['numOfLicenses'] == 0:
       current_object['numOfLicenses'] = 5
       save_current_object(current_object)
       current_object = get_current_activation_object()
       pprint.pprint( current_object )
    else:
        print("already activate.")

    current_object = get_current_activation_object2()
    pprint.pprint( current_object )
    if current_object['license_type'] != "Evaluation":
       current_object['license_type'] = "Evaluation"
       current_object['opportunity_name'] = "K.K. Ashisuto"
       current_object['user_name'] = "Takuya ARITA"
       current_object['comments'] = "Takuya ARITA"
       current_object['no_votiro_payment'] = False
       current_object['cdr_sandblast'] = False
       current_object['cdr_sasa'] = False
       current_object['votiro_avr'] = True
       current_object['cat_netstar'] = True
       current_object['allow_full_isolation'] = True
       current_object['use_ccu_license'] = False
       save_current_object2(current_object)
       current_object = get_current_activation_object2()
       pprint.pprint( current_object )
    else:
        print("already activate.")

    print("done.")

if __name__ == "__main__":
    main()
