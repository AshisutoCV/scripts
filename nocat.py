#!/usr/bin/python3

import json, argparse, subprocess
import pprint

def get_current_activation_object():
    string = subprocess.check_output("consul kv get settings/es-policy-manager", shell=True).decode("UTF-8")
    return json.loads(string)

def save_current_object(current_object):
    current_object = json.dumps(current_object)

    subprocess.run("consul kv put settings/es-policy-manager '{}'".format(current_object), shell=True)

def main():
    current_object = get_current_activation_object()
    pprint.pprint( current_object )
    current_object['enforceCategories'] = False
    current_object['detectPhishingSites'] = False
    save_current_object(current_object)
    current_object = get_current_activation_object()
    pprint.pprint( current_object )

    print("done.")

if __name__ == "__main__":
    main()

