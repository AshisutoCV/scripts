#!/usr/bin/python3

import json, argparse, subprocess

def get_current_browser_object():
    string = subprocess.check_output("consul kv get settings/browser", shell=True).decode("UTF-8")
    return json.loads(string)


def save_current_object(current_object):
    subprocess.run("consul kv put settings/browser '{}'".format(json.dumps(current_object)), shell=True)



def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--low", action="store_true", help="set fps to lower")
    parser.add_argument("--high", action="store_true", help="set fps to higher")
    return parser.parse_args()

def main():
    args = parse_args()
    current_object = get_current_browser_object()

    if args.low:
        if not 'start_fps' in current_object:
            current_object['start_fps'] = 8
            save_current_object(current_object)
        elif current_object['start_fps']:
            if not current_object['start_fps'] == 8:
                current_object['start_fps'] = 8
                save_current_object(current_object)
            else:
                print("lower start_fps is up to date")

        if not 'media_fps' in current_object:
            current_object['media_fps'] = 15
            save_current_object(current_object)
        elif current_object['media_fps']:
            if not current_object['media_fps'] == 15:
                current_object['media_fps'] = 15
                save_current_object(current_object)
            else:
                print("lower media_fps is up to date")

        if not 'non_media_fps' in current_object:
            current_object['non_media_fps'] = 8
            save_current_object(current_object)
        elif current_object['non_media_fps']:
            if not current_object['non_media_fps'] == 8:
                current_object['non_media_fps'] = 8
                save_current_object(current_object)
            else:
                print("lower non_media_fps is up to date")

    if args.high:
        if not 'start_fps' in current_object:
            current_object['start_fps'] = 15
            save_current_object(current_object)
        elif current_object['start_fps']:
            if not current_object['start_fps'] == 15:
                current_object['start_fps'] = 15
                save_current_object(current_object)
            else:
                print("higher start_fps is up to date")

        if not 'media_fps' in current_object:
            current_object['media_fps'] = 25
            save_current_object(current_object)
        elif current_object['media_fps']:
            if not current_object['media_fps'] == 25:
                current_object['media_fps'] = 25
                save_current_object(current_object)
            else:
                print("higher media_fps is up to date")

        if not 'non_media_fps' in current_object:
            current_object['non_media_fps'] = 15
            save_current_object(current_object)
        elif current_object['non_media_fps']:
            if not current_object['non_media_fps'] == 15:
                current_object['non_media_fps'] = 15
                save_current_object(current_object)
            else:
                print("higher non_media_fps is up to date")


if __name__ == "__main__":
    main()

