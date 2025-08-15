#!/bin/bash
############################################################
### K.K. Ashisuto
### Shield Monitoring Log Collector
### VER=20250815c
############################################################

#===========================================================
# Configuration
#===========================================================
# --- 日次ログの保持日数 ---
readonly KEEP_LOGS_DAYS=30
# --- サポートログアーカイブの保持世代数 ---
readonly KEEP_SUP_LOGS_COUNT=10
# --- 全Podログアーカイブの保持世代数 ---
readonly KEEP_ALLPOD_LOGS_COUNT=10

readonly BASE_LOG_DIR="${HOME}/kka_monitoring_log"
readonly EXEC_DATE=$(date +%Y%m%d)
readonly EXEC_DATETIME=$(date +%Y%m%d_%H%M%S)
readonly LOG_DIR="${BASE_LOG_DIR}/${EXEC_DATE}"
readonly HOSTNAME=$(hostname)
# --- 多重実行防止用ロックディレクトリ ---
readonly LOCK_DIR="${BASE_LOG_DIR}/script.lock"

#===========================================================
# Global Variables
#===========================================================
suplog_flg=0
allpodlog_flg=0

#===========================================================
# Functions
#===========================================================

# --- Show script usage ---
function usage() {
    cat <<EOF

USAGE: $0 [--suplog] [--allpodlog] [--cron]
    --suplog         : トラブルシューティングに必要なサポートログを取得し出力します。
                       ※ログは[${BASE_LOG_DIR}/]配下に[suplog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz]として出力されます。
    --allpodlog      : トラブルシューティングに必要なPODログを取得し出力します。
                       ※ログは[${BASE_LOG_DIR}/]配下に[ALLPodLog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz]として出力されます。
    --cron           : --suplog と --allpodlog を両方実行します。Cronでの定期実行を想定したオプションです。

[ログ世代管理について]
 - サポートログ: ${KEEP_SUP_LOGS_COUNT}世代
 - 全Podログ    : ${KEEP_ALLPOD_LOGS_COUNT}世代
 - 日次ログ     : ${KEEP_LOGS_DAYS}日分
上記を超えた古いファイルは自動的に削除されます。

EOF
    exit 0
}

# --- Log helper function ---
function log_command() {
    local log_file="$1"
    local cmd="$2"
    
    echo "============================================================" >> "${log_file}"
    echo "■ Command: ${cmd}" >> "${log_file}"
    echo "■ Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "${log_file}"
    echo "------------------------------------------------------------" >> "${log_file}"
    eval "${cmd}" >> "${log_file}" 2>&1
    echo -e "\n" >> "${log_file}"
}

#===========================================================
# Main Functions
#===========================================================

# --- Collect normal monitoring logs ---
function main_log() {
    echo "[info] Monitoring_Log output in progress..."
    echo "outputting...."

    ##== Kubernetes/Rancher Info ==##
    if command -v kubectl &> /dev/null && [ -d "${HOME}/.kube" ]; then
        log_command "${LOG_DIR}/rancher_ps${EXEC_DATE}.txt" "rancher ps --project \$(rancher projects | grep Shield | awk '{print \$1}')"
        echo "------------------" >> "${LOG_DIR}/rancher_ps${EXEC_DATE}.txt"
        log_command "${LOG_DIR}/rancher_ps${EXEC_DATE}.txt" "rancher ps --project \$(rancher projects | grep System | awk '{print \$1}')"
        log_command "${LOG_DIR}/kube_getnodes${EXEC_DATE}.txt" "kubectl get node -o wide"
        log_command "${LOG_DIR}/kube_getpods${EXEC_DATE}.txt" "kubectl get pods -A -o wide"
        log_command "${LOG_DIR}/kube_topnodes${EXEC_DATE}.txt" "kubectl top nodes"
        log_command "${LOG_DIR}/kube_toppod${EXEC_DATE}.txt" "kubectl top pod -A | sort -k 4 -h"

        ##== Shield Stats Info ==##
        local AuthIP
        AuthIP="$(kubectl get pods -A -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP | grep es-proxy-auth | grep Running -m1 | awk '{print $3}')"
        if [ -n "$AuthIP" ]; then
            local curl_cmd="curl -sS -m 10 -i -x http://${AuthIP}:3128 http://shield-stats/ -H 'User-Agent: Mozilla/5.0' --compressed --insecure"
            local curl_output
            curl_output=$(eval "${curl_cmd}" 2>&1)

            local stats_info_file="${LOG_DIR}/Shield_Stats_Info${EXEC_DATE}.txt"
            local stats_browser_file="${LOG_DIR}/Shield_Stats_BrowserUrl_List${EXEC_DATE}.txt"
            local stats_alert_file="${LOG_DIR}/Shield_Stats_AlertList${EXEC_DATE}.txt"

            echo "============================================================" >> "${stats_info_file}"
            date >> "${stats_info_file}"
            echo "------------------------------------------------------------" >> "${stats_info_file}"
            echo "${curl_output}" | sed 's/<br>/\'$'\n/g' | grep -e maxBrowsersCapacity -e "available sessions" -e "sessions in use" -e "session licenses in use" -e "user licenses in use" -e "HTTP/" -e "Failed to connect" >> "${stats_info_file}"

            echo "============================================================" >> "${stats_browser_file}"
            date >> "${stats_browser_file}"
            echo "------------------------------------------------------------" >> "${stats_browser_file}"
            echo "${curl_output}" | sed 's/<br>/\'$'\n/g' | grep CLIENT_USERNAME | awk '{print substr($0, index($0, "CLIENT_USERNAME"))}' >> "${stats_browser_file}"

            echo "============================================================" >> "${stats_alert_file}"
            date >> "${stats_alert_file}"
            echo "------------------------------------------------------------" >> "${stats_alert_file}"
            echo "${curl_output}" | awk '{print substr($0, index($0, "<i>maxBrowsersCapacity</i>"))}' | awk '{print substr($0, index($0, "<i>alerts:</i>"))}' | sed 's/<br>/\'$'\n/g' | sed 's/<blockquote>/\'$'\n/g' >> "${stats_alert_file}"
        fi
    fi

    ##== System & Memory Info ==##
    if ! command -v smem &> /dev/null; then
        echo "[info] smem setup start"
        sudo apt-get update &> /dev/null && sudo apt-get install -y smem &> /dev/null
        echo "[info] smem setup end"
    fi
    local mem_log="${LOG_DIR}/free_smem_${EXEC_DATE}.txt"
    log_command "${mem_log}" "free -mh"
    log_command "${mem_log}" "sudo smem -t -a -w -k"
    log_command "${mem_log}" "sudo smem -s pss -r -a -k | head -n 20"
    log_command "${mem_log}" "sudo cat /proc/meminfo"
    log_command "${mem_log}" "sudo slabtop --once --sort=c | head -n 20"
    log_command "${mem_log}" "sudo cat /proc/buddyinfo"
    
    ##== Docker & Process Info ==##
    if command -v docker &> /dev/null; then
        log_command "${LOG_DIR}/dockerstats_sort_MemUsage${EXEC_DATE}.txt" "sudo docker stats --no-stream --format 'table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}' | sort -k 4 -h"
    fi
    log_command "${LOG_DIR}/vmstat${EXEC_DATE}.txt" "vmstat --unit M -w -t"
    log_command "${LOG_DIR}/top${EXEC_DATE}.txt" "top -b -n 1 -o %MEM | head -n 17"
    
    echo "[End info] Monitoring_Log output completed."
}

# --- Collect support logs ---
function support_log() {
    echo "[info] SupLog output in progress..."
    echo "outputting...."
    local sup_log_dir="${LOG_DIR}/suplog"
    mkdir -p "${sup_log_dir}"

    ##== EricomShield Config Archive ==##
    if [ -d "${HOME}/ericomshield" ]; then
        log_command "${sup_log_dir}/archive_ericomshield_config.log" "sudo tar --exclude rancher-store --exclude shield-prepare-servers -zcf ${sup_log_dir}/ericomshield_${HOSTNAME}_${EXEC_DATE}.tar.gz ~/ericomshield/"
    fi

    ##== Kubernetes Info ==##
    if command -v kubectl &> /dev/null; then
        log_command "${sup_log_dir}/kube_services${EXEC_DATE}.txt" "kubectl get services -A -o wide"
        log_command "${sup_log_dir}/kube_getall${EXEC_DATE}.txt" "kubectl get all -A -o wide"
        log_command "${sup_log_dir}/kube_getnodes${EXEC_DATE}.txt" "kubectl get node --show-labels -o wide"
        log_command "${sup_log_dir}/kube_gethpa${EXEC_DATE}.txt" "kubectl get hpa -A -o wide"
        log_command "${sup_log_dir}/kube_getjob${EXEC_DATE}.txt" "kubectl get job -A -o wide"
        log_command "${sup_log_dir}/kube_getdeploy${EXEC_DATE}.txt" "kubectl get deploy -A -o wide"
        log_command "${sup_log_dir}/kube_getnamespaces${EXEC_DATE}.txt" "kubectl get namespaces -o wide"
        log_command "${sup_log_dir}/kube_topnodes${EXEC_DATE}.txt" "kubectl top nodes"
        log_command "${sup_log_dir}/kube_toppods${EXEC_DATE}.txt" "kubectl top pod -A"
        log_command "${sup_log_dir}/kube_describe_nodes${EXEC_DATE}.txt" "kubectl describe nodes"
        log_command "${sup_log_dir}/kube_describe_pod${EXEC_DATE}.txt" "kubectl describe pod -A"
        log_command "${sup_log_dir}/kube_events${EXEC_DATE}.txt" "kubectl get events -n proxy --sort-by='.lastTimestamp' -o custom-columns=LAST_SEEN:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message"
    
        ##== Consul Info ==##
        local consul_log="${sup_log_dir}/kube_consul_list-peers${EXEC_DATE}.txt"
        log_command "${consul_log}" "kubectl exec -it shield-farm-services-consul-0 -n farm-services -c consul -- consul operator raft list-peers"
        log_command "${consul_log}" "kubectl exec -it shield-farm-services-consul-1 -n farm-services -c consul -- consul operator raft list-peers"
        log_command "${consul_log}" "kubectl exec -it shield-farm-services-consul-2 -n farm-services -c consul -- consul operator raft list-peers"
        log_command "${consul_log}" "kubectl exec -it shield-management-consul-0 -n management -c consul -- consul operator raft list-peers"
        log_command "${consul_log}" "kubectl exec -it shield-management-consul-1 -n management -c consul -- consul operator raft list-peers"
        log_command "${consul_log}" "kubectl exec -it shield-management-consul-2 -n management -c consul -- consul operator raft list-peers"
    fi

    ##== Config Files & Certificates ==##
    log_command "${sup_log_dir}/es_custom_env${EXEC_DATE}.txt" "cat ~/.es_custom_env"
    if [ -f "${HOME}/.kube/config" ]; then
        log_command "${sup_log_dir}/kube_config${EXEC_DATE}.txt" "cat ~/.kube/config"
    fi
    if [ -d "${HOME}/ericomshield/rancher-store/k3s/server/tls" ]; then
        log_command "${sup_log_dir}/RancherCertificate${EXEC_DATE}.txt" "sudo ls ~/ericomshield/rancher-store/k3s/server/tls/ | grep .crt | xargs -I {} sh -c \"echo {}; sudo openssl x509 -dates -noout -in ~/ericomshield/rancher-store/k3s/server/tls/{}; echo\""
    fi
    log_command "${sup_log_dir}/OS_Certificate${EXEC_DATE}.txt" "ls -lha /usr/share/ca-certificates/"
    log_command "${sup_log_dir}/OS_Certificate${EXEC_DATE}.txt" "cat /etc/ca-certificates.conf"

    ##== Internet Connection Check ==##
    local shield_net_log="${sup_log_dir}/ShieldInternetConnection_Check${EXEC_DATE}.txt"
    local direct_net_log="${sup_log_dir}/InternetConnection_check${EXEC_DATE}.txt"
    if command -v kubectl &> /dev/null; then
        local AuthIP
        AuthIP="$(kubectl get pods -A -o wide | grep es-proxy-auth | grep Running -m1 | awk '{print $7}')"
        if [ -n "$AuthIP" ]; then
            log_command "${shield_net_log}" "curl --retry 2 -sS -m 10 -i -w'\n' -x http://${AuthIP}:3128 http://shield-ver/"
            log_command "${shield_net_log}" "curl --retry 2 -m 10 -v -x http://${AuthIP}:3128 https://ericom-tec.ashisuto.co.jp/shield/k8s-rel-ver.txt"
            log_command "${shield_net_log}" "curl --retry 2 -m 10 -v -x http://${AuthIP}:3128 https://ericom-tec.ashisuto.co.jp/shield/k8s-rel-ver.txt -A 'Mozilla/5.0...'"
        fi
        log_command "${shield_net_log}" "kubectl exec -ti \$(kubectl get pod --namespace=farm-services | grep ext-proxy | grep -v ext-proxy-noadblock | awk {'print \$1'} | head -n 1) -n farm-services -- curl --retry 2 -m 10 -v https://ericom-tec.ashisuto.co.jp/shield/k8s-rel-ver.txt"
    fi
    
    log_command "${direct_net_log}" "curl --retry 1 https://www.google.com/ -m 10 -I"
    log_command "${direct_net_log}" "curl --retry 1 https://ericom-tec.ashisuto.co.jp/ -m 10 -I"
    log_command "${direct_net_log}" "curl --retry 1 https://shieldstats.azurewebsites.net/ -m 10 -I"
    log_command "${direct_net_log}" "dig ericom-tec.ashisuto.co.jp"
    log_command "${direct_net_log}" "dig www.google.com"
    log_command "${direct_net_log}" "dig shieldstats.azurewebsites.net"
    log_command "${direct_net_log}" "ping 8.8.8.8 -c 5"
    log_command "${direct_net_log}" "curl -w'time_total: %{time_total}\n' -o /dev/null https://sctestfile.s3-ap-northeast-1.amazonaws.com/sample.xlsm"
    log_command "${direct_net_log}" "curl -w'time_total: %{time_total}\n' -o /dev/null https://sample-img.lb-product.com/wp-content/themes/hitchcock/images/10MB.jpg"
    log_command "${direct_net_log}" "curl --retry 1 http://ip-api.com/ -m 10 -i"

    ##== System, Hardware, Disk Info ==##
    local hw_log="${sup_log_dir}/HW_Information${EXEC_DATE}.txt"
    log_command "${hw_log}" "lscpu"
    log_command "${hw_log}" "lspci"
    log_command "${hw_log}" "sudo lshw"
    log_command "${sup_log_dir}/last${EXEC_DATE}.txt" "last"
    log_command "${sup_log_dir}/last_reboot${EXEC_DATE}.txt" "last reboot"
    log_command "${sup_log_dir}/hostnamectl${EXEC_DATE}.txt" "hostnamectl"
    log_command "${sup_log_dir}/dpkg_docker${EXEC_DATE}.txt" "dpkg -l | grep -e docker -e containerd"
    log_command "${sup_log_dir}/uptime${EXEC_DATE}.txt" "uptime"
    log_command "${sup_log_dir}/dmesg_log${EXEC_DATE}.txt" "dmesg"
    log_command "${sup_log_dir}/timedatectl${EXEC_DATE}.txt" "timedatectl"
    log_command "${sup_log_dir}/localectl${EXEC_DATE}.txt" "localectl"
    log_command "${sup_log_dir}/dpkg_all${EXEC_DATE}.txt" "dpkg -l | grep ii"
    
    local disk_log="${sup_log_dir}/disk_directory_info${EXEC_DATE}.txt"
    log_command "${disk_log}" "df -h"
    log_command "${disk_log}" "df -i"
    log_command "${disk_log}" "sudo find / -xdev -printf '%h\n' | sort | uniq -c | sort -rn | head -30"
    log_command "${disk_log}" "lsblk"
    log_command "${disk_log}" "sudo fdisk -l"
    log_command "${disk_log}" "sudo cat /etc/fstab"
    log_command "${disk_log}" "sudo hdparm -I /dev/sda"
    log_command "${disk_log}" "sudo hdparm /dev/sda"
    log_command "${disk_log}" "sudo hdparm -Tt /dev/sda"

    ##== Proxy, Network, Firewall Info ==##
    local proxy_log="${sup_log_dir}/Proxy_info${EXEC_DATE}.txt"
    log_command "${proxy_log}" "cat /etc/apt/apt.conf"
    log_command "${proxy_log}" "cat /etc/environment"
    log_command "${proxy_log}" "cat /etc/bash.bashrc | grep -i proxy"
    log_command "${proxy_log}" "cat /etc/systemd/system/docker.service.d/http-proxy.conf"
    log_command "${proxy_log}" "printenv | grep -i proxy"

    local net_log="${sup_log_dir}/Network_info${EXEC_DATE}.txt"
    log_command "${net_log}" "ifconfig -a"
    log_command "${net_log}" "ip addr show"
    log_command "${net_log}" "ip -6 a"
    log_command "${net_log}" "ip route show"
    log_command "${net_log}" "sudo ls /etc/netplan/ | grep .yaml | xargs -I {} sh -c \"echo \<{}\>;echo; sudo cat /etc/netplan/{}; echo\""
    log_command "${net_log}" "ls -l /etc/resolv.conf"
    log_command "${net_log}" "sudo cat /etc/resolv.conf"
    log_command "${net_log}" "sudo cat /run/systemd/resolve/resolv.conf"
    log_command "${net_log}" "sudo cat /etc/systemd/resolved.conf"
    log_command "${net_log}" "sudo cat /etc/hosts"
    log_command "${sup_log_dir}/ufw${EXEC_DATE}.txt" "sudo ufw status verbose"

    ##== Process, Memory, Docker Full Info ==##
    log_command "${sup_log_dir}/top${EXEC_DATE}.txt" "top -b -n 1"
    local mem_log_sup="${sup_log_dir}/free_smem_${EXEC_DATE}.txt"
    log_command "${mem_log_sup}" "free -mh"
    log_command "${mem_log_sup}" "sudo smem -t -a -w -k"
    log_command "${mem_log_sup}" "sudo smem -s pss -r -t -a -k"
    log_command "${mem_log_sup}" "sudo cat /proc/meminfo"
    log_command "${mem_log_sup}" "sudo slabtop --once --sort=c"
    
    if command -v docker &> /dev/null; then
        local docker_log="${sup_log_dir}/DockerLogs_info${EXEC_DATE}.txt"
        log_command "${docker_log}" "sudo docker info"
        log_command "${docker_log}" "sudo docker ps -a"
        log_command "${docker_log}" "sudo docker stats --no-stream"
        log_command "${docker_log}" "sudo docker image ls"
        log_command "${docker_log}" "sudo docker network ls"
        log_command "${docker_log}" "sudo docker system df -v"
        log_command "${docker_log}" "sudo systemctl status docker"
        log_command "${docker_log}" "sudo ls -lah /etc/docker/"
        log_command "${docker_log}" "sudo cat /etc/docker/daemon.json"
        log_command "${docker_log}" "sudo journalctl -e -n 100 -u docker"
    fi

    ##== Misc Configs & File Listings ==##
    log_command "${sup_log_dir}/sudoers${EXEC_DATE}.txt" "sudo cat /etc/sudoers"
    log_command "${sup_log_dir}/passwd${EXEC_DATE}.txt" "sudo cat /etc/passwd"
    log_command "${sup_log_dir}/apt_sources_list${EXEC_DATE}.txt" "sudo cat /etc/apt/sources.list"
    
    local ls_log="${sup_log_dir}/ls_info${EXEC_DATE}.txt"
    log_command "${ls_log}" "ls -lha ~/"
    log_command "${ls_log}" "ls -lha ~/ericomshield/"
    log_command "${ls_log}" "ls -lha ~/.kube/"
    log_command "${ls_log}" "sudo ls -lha /home/"
    log_command "${ls_log}" "sudo ls -lha /home/ericom/"
    log_command "${ls_log}" "sudo ls -lha /etc/apt/"
    log_command "${ls_log}" "sudo ls -lha /etc/apt/sources.list.d/"

    ##== Log File Copy ==##
    echo "[info] Copying OS and k3s logs..."
    mkdir -p "${sup_log_dir}/OS_Log" "${sup_log_dir}/k3s_Log"
    sudo cp -f /var/log/syslog* "${sup_log_dir}/OS_Log/" 2> /dev/null
    sudo cp -f /var/log/kern* "${sup_log_dir}/OS_Log/" 2> /dev/null
    sudo cp -f /var/log/dpkg* "${sup_log_dir}/OS_Log/" 2> /dev/null
    sudo cp -f /var/log/shield_syslog* "${sup_log_dir}/OS_Log/" 2> /dev/null
    if [ -f "${HOME}/ericomshield/rancher-store/k3s.log" ]; then
        sudo cp -f ~/ericomshield/rancher-store/k3s.log "${sup_log_dir}/k3s_Log/" 2> /dev/null
    fi

    ##== Setting JSON Backup Copy ==##
    echo "[info] Copying setting backups..."
    local setting_dir="${sup_log_dir}/setting_json"
    mkdir -p "${setting_dir}"
    if [ -d /home/ericom/ericomshield/config-backup/backup/ ];then
        ls -1 -t /home/ericom/ericomshield/config-backup/backup/ 2> /dev/null | head -n 1 | xargs -I {} cp /home/ericom/ericomshield/config-backup/backup/{} "${setting_dir}/" 2> /dev/null
        ls -1 -t /home/ericom/ericomshield/config-backup/daily/ 2> /dev/null | head -n 1 | xargs -I {} cp /home/ericom/ericomshield/config-backup/daily/{} "${setting_dir}/" 2> /dev/null
    fi
    if [ -d /mnt/nfs_shield/ericomshield/config-backup/backup/ ];then
        ls -1 -t /mnt/nfs_shield/ericomshield/config-backup/backup/ 2> /dev/null | head -n 1 | xargs -I {} cp /mnt/nfs_shield/ericomshield/config-backup/backup/{} "${setting_dir}/" 2> /dev/null
        ls -1 -t /mnt/nfs_shield/ericomshield/config-backup/daily/ 2> /dev/null | head -n 1 | xargs -I {} cp /mnt/nfs_shield/ericomshield/config-backup/daily/{} "${setting_dir}/" 2> /dev/null
    fi
    if [ -f ~/ericomshield/custom-management.yaml ];then
        local localPath=`cat ~/ericomshield/custom-management.yaml | grep 'localPath:' | grep -v -E '#.*localPath:' | sed -e 's/localPath://g' -e 's/ //g'`
        ls -1 -t "${localPath}"backup/ 2> /dev/null | head -n 1 | xargs -I {} cp  "${localPath}"backup/{} "${setting_dir}/" 2> /dev/null
        ls -1 -t "${localPath}"daily/ 2> /dev/null | head -n 1 | xargs -I {} cp  "${localPath}"daily/{} "${setting_dir}/" 2> /dev/null
    fi

    # Archive
    echo "[info] Compressing support logs..."
    local archive_path="${BASE_LOG_DIR}/suplog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz"
    # Note: This compresses the entire log directory for the day, including normal monitoring logs.
    sudo tar -zcf "${archive_path}" -C "${BASE_LOG_DIR}" "${EXEC_DATE}" >/dev/null 2>&1
    echo "  -> ${archive_path}"
    
    echo "[End info] SupLog output completed."
}

# --- Collect all pod logs ---
function all_pod_log() {
    echo "[info] AllPodLog output in progress..."
    echo "outputting...."
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # Set a trap as a safety net in case of unexpected errors
    trap 'echo "Error: Cleaning up temporary directory..."; sudo rm -rf -- "$tmp_dir"; trap - EXIT' EXIT
    
    # Use EXEC_DATETIME in the directory name inside the temp directory to avoid conflicts
    local pod_log_dir="${tmp_dir}/ALLPodLog_${HOSTNAME}_${EXEC_DATETIME}"
    mkdir -p "${pod_log_dir}"
    if [ -d "/var/log/pods" ]; then
        sudo cp -rL /var/log/pods/ "${pod_log_dir}/" >/dev/null 2>&1
    fi
    
    echo "[info] Compressing all pod logs..."
    local archive_path="${BASE_LOG_DIR}/ALLPodLog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz"
    sudo tar -zcf "${archive_path}" -C "${tmp_dir}" . >/dev/null 2>&1
    echo "  -> ${archive_path}"

    # Explicitly clean up the temporary directory
    echo "[info] Cleaning up temporary directory..."
    sudo rm -rf -- "$tmp_dir"
    # Remove the trap since cleanup is done
    trap - EXIT
    
    echo "[End info] AllPodLog output completed."
}

# --- Cleanup old logs ---
function cleanup_old_logs() {
    echo "[info] Cleaning up old log files..."
    
    # 1. Compress log directories older than today, excluding the lock directory
    find "${BASE_LOG_DIR}" -mindepth 1 -maxdepth 1 -type d -not -name "${EXEC_DATE}" -not -name "script.lock" | while read -r dir; do
        if [ -d "$dir" ]; then
            local dir_date
            dir_date=$(basename "$dir")
            echo "  Compressing and removing old directory: ${dir}"
            tar -zcf "${BASE_LOG_DIR}/${dir_date}.tar.gz" -C "${BASE_LOG_DIR}" "${dir_date}" && rm -rf "$dir"
        fi
    done

    # 2. Delete daily archives older than KEEP_LOGS_DAYS based on filename date
    echo "  Deleting daily archives older than ${KEEP_LOGS_DAYS} days based on filename."
    local current_date_sec
    current_date_sec=$(date +%s)
    local retention_period_sec=$((KEEP_LOGS_DAYS * 86400)) # 86400 seconds in a day

    for f in "${BASE_LOG_DIR}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].tar.gz; do
        # Check if file exists to avoid errors when no files match
        [ -e "$f" ] || continue

        local filename
        filename=$(basename "$f")
        local file_date_str
        file_date_str=${filename%.tar.gz} # Extracts "YYYYMMDD"

        # Check if the extracted string is a valid date format
        if [[ "$file_date_str" =~ ^[0-9]{8}$ ]]; then
            local file_date_sec
            # Use --date for compatibility with GNU date
            file_date_sec=$(date --date="$file_date_str" +%s 2>/dev/null)
            
            if [ -n "$file_date_sec" ] && [ $((current_date_sec - file_date_sec)) -gt $retention_period_sec ]; then
                echo "    Deleting old daily archive: $f"
                rm -f "$f"
            fi
        fi
    done

    # 3. Delete suplog archives exceeding the retention count
    echo "  Deleting suplog archives older than ${KEEP_SUP_LOGS_COUNT} generations."
    ls -t "${BASE_LOG_DIR}"/suplog_*.tar.gz 2>/dev/null | tail -n +$((KEEP_SUP_LOGS_COUNT + 1)) | xargs --no-run-if-empty rm -f --

    # 4. Delete allpodlog archives exceeding the retention count
    echo "  Deleting allpodlog archives older than ${KEEP_ALLPOD_LOGS_COUNT} generations."
    ls -t "${BASE_LOG_DIR}"/ALLPodLog_*.tar.gz 2>/dev/null | tail -n +$((KEEP_ALLPOD_LOGS_COUNT + 1)) | xargs --no-run-if-empty rm -f --
    
    echo "[info] Cleanup completed."
}


#===========================================================
# Execution Start
#===========================================================

# --- Create log directory first to ensure it exists for locking ---
mkdir -p "${LOG_DIR}"

# --- Lock for preventing multiple executions ---
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "[info] Script is already running. Exiting. (Lock file found: ${LOCK_DIR})"
    exit 1
fi
# --- Set trap to remove lock directory on exit ---
trap 'rm -rf -- "${LOCK_DIR}"; echo "Script interrupted, lock file removed."; exit' INT TERM EXIT


# --- Argument parsing ---
while getopts ":h-:" opt; do
    case ${opt} in
        -)
            case "${OPTARG}" in
                suplog) suplog_flg=1 ;;
                allpodlog) allpodlog_flg=1 ;;
                cron)
                    suplog_flg=1
                    allpodlog_flg=1
                    ;;
                help) usage ;;
                *) echo "Invalid option: --${OPTARG}" >&2; usage ;;
            esac;;
        h) usage ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; usage ;;
    esac
done

echo "[info] Log output path: ${LOG_DIR}"

# --- Execute main functions ---
main_log

if [ ${suplog_flg} -eq 1 ]; then
    support_log
fi

if [ ${allpodlog_flg} -eq 1 ]; then
    all_pod_log
fi

# --- Set final permissions for log files ---
echo "[info] Setting log file permissions..."
find "${BASE_LOG_DIR}/" -type d -print0 | xargs -0 sudo chmod 755
find "${BASE_LOG_DIR}/" -type f -print0 | xargs -0 sudo chmod 664
sudo chown -R "$(whoami):$(whoami)" "${BASE_LOG_DIR}/"
echo "[info] Permission settings completed."

# --- Execute cleanup ---
cleanup_old_logs

# --- Output Log Path ---
if [ ${suplog_flg} -eq 1 ] || [ ${allpodlog_flg} -eq 1 ]; then
    echo
    echo "[Output Log Path]"
    if [ ${suplog_flg} -eq 1 ]; then
        readlink -f "${BASE_LOG_DIR}/suplog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz"
    fi
    if [ ${allpodlog_flg} -eq 1 ]; then
        readlink -f "${BASE_LOG_DIR}/ALLPodLog_${HOSTNAME}_${EXEC_DATETIME}.tar.gz"
    fi
fi

echo
echo "All processes completed."

# --- Release lock and remove trap ---
rm -rf -- "${LOCK_DIR}"
trap - INT TERM EXIT
exit 0