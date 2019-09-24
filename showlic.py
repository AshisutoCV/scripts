#!/usr/bin/python3

import json, argparse, subprocess
import pprint


def get_current_activation_object():
    string = subprocess.check_output("consul kv get activation/license", shell=True).decode("UTF-8")
    return json.loads(string)

def get_current_activation_object2():
    string = subprocess.check_output("consul kv get activation/flags", shell=True).decode("UTF-8")
    return json.loads(string[1:-2])


def main():
    print("==== License infomations =====")
    current_object = get_current_activation_object()
    pprint.pprint( current_object )

    current_object = get_current_activation_object2()
    pprint.pprint( current_object )

    print("done.")

if __name__ == "__main__":
    main()

