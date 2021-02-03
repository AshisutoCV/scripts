import glob
import os, sys
import json
from deepdiff import DeepDiff
import subprocess, fcntl
from datetime import datetime
import logging
import base64
from json.decoder import JSONDecodeError

loglevel = "INFO"
if "LOG_LEVEL" in os.environ:
    loglevel = os.environ['LOG_LEVEL'].upper()
FORMAT = '%(asctime)-15s - %(levelname)s - %(message)s'
logging.basicConfig(format=FORMAT)
logger = logging.getLogger('backup-process')
logger.setLevel(logging.getLevelName(loglevel))

history_length = 10
if "BACKUP_HISTORY_LENGTH" in os.environ:
    history_length = int(os.environ["BACKUP_HISTORY_LENGTH"])

backup_path = "/consul/backup"
if "BACKUP_PATH" in os.environ:
    backup_path = os.environ['BACKUP_PATH']


required_object = {
        'activation/license': False,
        'policies/policies': False
    }

keys_for_filter = ['status/', 'ldap_cache/', 'version/']  #Test with , 'version/' key

files = []

def fill_files_array():
    global files
    files = glob.glob(os.path.join(backup_path, "*.json"))
    files.sort(key=lambda f: os.path.getctime(f))

fill_files_array()

def clean_files():
    if len(files) > history_length:
        del_len = len(files) - history_length
        for f in files[:del_len]:
            os.remove(f)


def check_license_amount(items):
    '''
    Check licenses amount.
    If licenses equals to 0 no reason to save this backup
    :param items:
    :return:
    '''
    for itm in items:
        if itm['key'] == 'activation/license':
            value = base64.b64decode(itm['value'])
            obj = json.loads(value)
            return int(obj['numOfLicenses']) != 0
    return False


def check_delta_with_last_backup(new_file):
    if len(files) == 0:
        return {
            "save": True
        }

    file_obj = None
    while len(files) > 0:
        with open(files[-1], mode='rb') as backup:
            try:
                file_obj = json.load(backup)
                break
            except Exception as e:
                if isinstance(e, JSONDecodeError):
                    process_bad_file(files[-1])
                else:
                    raise e

    if file_obj is None:
        return {
            "save": True
        }
    return DeepDiff(file_obj, new_file, ignore_order=True)

def process_bad_file(file):
    subprocess.run("rm -f {}".format(file), shell=True)
    fill_files_array()


def check_backup_item(backup_item):
    if len(backup_item['value']) == 0:
        return False
    for uk in keys_for_filter:
        if uk in backup_item['key']:
            return False
    if backup_item['key'] in required_object:
        required_object[backup_item['key']] = True
    return True


def save_back_up(backup):
    with open(os.path.join(backup_path, "backup{}.json".format(datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))), mode='w') as file:
        logger.info("Save to {}".format(file.name))
        try:
            fcntl.flock(file, fcntl.LOCK_EX)
            json.dump(backup, file)
        except Exception as ex:
            logger.fatal(str(ex))
        finally:
            fcntl.flock(file, fcntl.LOCK_UN)


def filter_backup_json(backup):
    return [item for item in backup if check_backup_item(item)]


def check_restore_run():
    try:
        subprocess.check_output(['/bin/consul', 'kv', 'get', 'restore/running/now'])
        return False
    except subprocess.CalledProcessError as ex:
        return True
    except Exception as ex:
        logger.error(ex)
        return False


def check_required_keys():
    required = [key for key in required_object if required_object[key]]
    logger.debug(required)
    return len(required_object.keys()) == len(required)


def run_backup(backup):
    logger.info("Start backup")

    if not check_license_amount(backup):
        logger.info("No license found. Backup stopped")
        return
    logger.info("License OK")
    right_items = filter_backup_json(backup)
    if not check_required_keys():
        logger.error("No required keys found")
        return
    logger.info("Items is OK")
#    diff = check_delta_with_last_backup(right_items)
    logger.info("Going check difference")
#    logger.debug(diff)
#    if len(diff) > 0:
    logger.info("Check point before save")
    save_back_up(right_items)
    clean_files()


def main():
    try:
        logger.info("Check restore running")
        if check_restore_run():
            backup = json.loads(subprocess.check_output(['/bin/consul', 'kv', 'export']))
            run_backup(backup)
        else:
            logger.info("Restore running! Backup denied")
    except Exception as ex:
        logger.fatal(ex)




if __name__ == "__main__":
    main()
