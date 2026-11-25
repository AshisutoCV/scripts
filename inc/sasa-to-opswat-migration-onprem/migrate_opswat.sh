#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_YAML_NAME="sasa-to-opswat-migration-onprem-job_1123.yaml"
LEGACY_YAML_NAME="sasa-to-opswat-migration-onprem-job.yaml"
JOB_NAMESPACE="management"
JOB_NAME="es-sasa-to-opswat-cdr-migrator"
EXPECTED_MIGRATOR_IMAGE="securebrowsing/es-sasa-to-opswat-cdr-migrator:261119-12.56"
NEW_CDR_IMAGE="securebrowsing/shield-cdr-controller:261118-19.42"
ES_BASE_DIR="${HOME}/ericomshield"
ES_VERSION_FILE="${ES_BASE_DIR}/.esversion"
VALUES_FILE="${ES_BASE_DIR}/shield/values.yaml"

LAST_LOG_FILE=""
DETECTED_SYSTEM_ID=""
TMP_KV_FILE=""
LOG_TAIL_PID=""
JOB_CREATED=0
SUPPRESS_ERROR_BANNER=0
CDR_NS=""
CDR_KIND=""
CDR_NAME=""
CDR_CONTAINER=""

on_exit() {
  local exit_code=$?
  set +e

  [ -n "${LOG_TAIL_PID}" ] && kill "${LOG_TAIL_PID}" 2>/dev/null || true
  [ -n "${TMP_KV_FILE}" ] && rm -f "${TMP_KV_FILE}" 2>/dev/null || true

  if [ "${exit_code}" -ne 0 ] && [ "${SUPPRESS_ERROR_BANNER}" -eq 0 ]; then
    if [ "${JOB_CREATED}" -eq 1 ] || [ -n "${CDR_NAME}" ]; then
      local debug_log="${PWD}/error_k8s_${JOB_NAME}_$(date +%Y%m%d_%H%M%S).log"
      {
        if [ "${JOB_CREATED}" -eq 1 ]; then
          echo "=== kubectl get job,pod (${JOB_NAMESPACE}) ==="
          kubectl get job,pod -n "${JOB_NAMESPACE}" -l "job-name=${JOB_NAME}" -o wide 2>&1 || true
          echo ""
          echo "=== kubectl describe job (${JOB_NAME}) ==="
          kubectl describe job "${JOB_NAME}" -n "${JOB_NAMESPACE}" 2>&1 || true
          echo ""
          echo "=== kubectl describe pod (${JOB_NAME}) ==="
          kubectl describe pod -l "job-name=${JOB_NAME}" -n "${JOB_NAMESPACE}" 2>&1 || true
          echo ""
        fi
        if [ -n "${CDR_NAME}" ]; then
          echo "=== kubectl describe ${CDR_KIND}/${CDR_NAME} (${CDR_NS}) ==="
          kubectl describe "${CDR_KIND}/${CDR_NAME}" -n "${CDR_NS}" 2>&1 || true
          echo ""
          echo "=== kubectl logs ${CDR_KIND}/${CDR_NAME} (tail 50) ==="
          kubectl logs -n "${CDR_NS}" "${CDR_KIND}/${CDR_NAME}" -c "${CDR_CONTAINER}" --tail=50 2>&1 || true
        fi
      } > "${debug_log}" 2>&1 || true
    fi

    if [ "${JOB_CREATED}" -eq 1 ]; then
      echo ""
      echo "エラー発生に伴い、マイグレーション用一時 Job / Pod をクリーンアップしています..."
      kubectl delete job "${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
      kubectl delete pod -l "job-name=${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
    fi

    local found_logs
    found_logs=$(ls -t "${PWD}"/dryrun_${JOB_NAME}_*.log "${PWD}"/real_${JOB_NAME}_*.log "${PWD}"/error_k8s_${JOB_NAME}_*.log 2>/dev/null || true)

    cat <<EOF

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
[エラー停止] 処理が途中で中断されました (終了コード: ${exit_code})

原因調査のため、以下の 2 点をサポート窓口へご送付ください:
  1. 画面（コンソール）の実行ログ一式
     ※ コマンド実行開始から本メッセージまでのターミナル出力全文
  2. 生成されたログファイル（存在する場合）
EOF
    if [ -n "${found_logs}" ]; then
      echo "     [検出されたログファイル]"
      echo "${found_logs}" | sed 's/^/     - /'
    else
      echo "     - （ログファイルはまだ生成されていません）"
    fi
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  fi
}
trap on_exit EXIT

exit_expected() {
  SUPPRESS_ERROR_BANNER=1
  exit 1
}

if [ -z "${YAML_FILE:-}" ]; then
  for candidate in \
    "./${DEFAULT_YAML_NAME}" \
    "${SCRIPT_DIR}/${DEFAULT_YAML_NAME}" \
    "./${LEGACY_YAML_NAME}" \
    "${SCRIPT_DIR}/${LEGACY_YAML_NAME}"; do
    if [ -f "${candidate}" ]; then
      YAML_FILE="${candidate}"
      break
    fi
  done
  YAML_FILE="${YAML_FILE:-./${DEFAULT_YAML_NAME}}"
fi

usage() {
  cat <<EOF
Usage: $0 {dryrun|migrate|check|verify-log|update-cdr|cleanup}

Standard Workflow (2 Steps):
  1. $0 dryrun       : Step 1 - 環境・バージョンチェック + ドライラン実行・ログ自動検証
                       (保存された dryrun_*.log をサポートへ送付して確認)
  2. $0 migrate      : Step 2 - 本番移行 + Consul検証 + cdr-controller更新 + 後処理
                       (完了後、ブラウザでファイルのダウンロード/アップロードをテスト)

Utility / Recovery Commands:
  check              : 環境・バージョン診断のみ単独実行
  verify-log [FILE]  : 保存済みログの正常性チェック（FILE省略時は最新ログ）
  update-cdr         : cdr-controller の更新処理のみ再実行（リカバリ用）
  cleanup            : マイグレーション用一時 Job と Pod の手動削除
EOF
  exit_expected
}

detect_cdr_target() {
  CDR_INFO=$(kubectl get deploy,ds,sts -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.kind}{" "}{.metadata.name}{" "}{.spec.template.spec.containers[?(@.name=="cdr-controller")].name}{"\n"}{end}' | awk '$4 == "cdr-controller" {print; exit}' || true)

  if [ -z "${CDR_INFO}" ]; then
    echo "エラー: クラスター内に cdr-controller が見つかりませんでした。"
    exit 1
  fi

  CDR_NS=$(echo "${CDR_INFO}" | awk '{print $1}')
  CDR_KIND=$(echo "${CDR_INFO}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
  CDR_NAME=$(echo "${CDR_INFO}" | awk '{print $3}')
  CDR_CONTAINER=$(echo "${CDR_INFO}" | awk '{print $4}')
}

get_shield_version() {
  local ver=""
  if [ -f "${ES_VERSION_FILE}" ]; then
    ver=$(tr -d '\r\n ' < "${ES_VERSION_FILE}")
  fi
  if [ -z "${ver}" ] && [ -f "${VALUES_FILE}" ]; then
    ver=$(awk -F: '/^[[:space:]]*shield_version:/ {gsub(/["'\'' \r\n]/, "", $2); print $2; exit}' "${VALUES_FILE}")
  fi
  echo "${ver}"
}

check_supported_version() {
  local shield_ver=$1
  if [ "${FORCE_VERSION:-0}" = "1" ]; then
    return 0
  fi

  if echo "${shield_ver}" | grep -qE "(22\.08|23\.05)"; then
    return 0
  fi

  echo ""
  echo "[対象外バージョン] 検出された Ericom Shield バージョン (${shield_ver:-不明}) は本手順の対象外です。"
  echo "本スクリプトは Ericom Shield v22.08 / v23.05 専用です。"
  echo "v23.13 以降については別途提供される専用手順をご利用ください。"
  exit_expected
}

run_precheck() {
  echo "=== 事前環境・バージョンチェック ==="

  # 1. インストールディレクトリ・values.yaml チェック（初期インストールユーザー確認）
  if [ ! -f "${VALUES_FILE}" ]; then
    echo ""
    echo "[前提条件未達] ${VALUES_FILE} が見つかりません。"
    echo "Ericom Shield を初期インストールした OS ユーザでログインし直してから再度実行してください。"
    exit_expected
  fi
  echo "1. values.yaml (${VALUES_FILE}): OK"

  # 2. バージョンチェック（.esversion / shield_version）
  local shield_ver
  shield_ver=$(get_shield_version)
  check_supported_version "${shield_ver}"
  echo "2. Shield バージョン (${shield_ver}): OK (対象バージョン)"

  # 3. 移行用 YAML およびイメージタグチェック
  if [ -f "${YAML_FILE}" ]; then
    local yaml_img
    yaml_img=$(awk '/^[[:space:]]*image:[[:space:]]*/ {gsub(/["'\'' \r\n]/, "", $2); print $2; exit}' "${YAML_FILE}")
    if [ "${yaml_img}" != "${EXPECTED_MIGRATOR_IMAGE}" ] && [ "${FORCE_YAML_IMAGE:-0}" != "1" ]; then
      echo ""
      echo "[前提条件未達] 移行用 YAML (${YAML_FILE}) のイメージタグが更新版と一致しません。"
      echo "  検出されたイメージ : ${yaml_img:-不明}"
      echo "  期待されるイメージ : ${EXPECTED_MIGRATOR_IMAGE}"
      echo "更新版の ${DEFAULT_YAML_NAME} を配置してから再実行してください。"
      exit_expected
    fi
    echo "3. 移行用 YAML (${YAML_FILE} / ${yaml_img}): OK"
  else
    echo ""
    echo "[前提条件未達] 移行用 YAML (${YAML_FILE}) が見つかりません。"
    echo "手順書に従い、スクリプトと同じディレクトリに ${DEFAULT_YAML_NAME} を配置してから再実行してください。"
    exit_expected
  fi

  # 4. ImagePullSecret チェック
  if kubectl get secret dockerhubcred -n "${JOB_NAMESPACE}" >/dev/null 2>&1; then
    echo "4. ImagePullSecret (dockerhubcred in ${JOB_NAMESPACE}): OK"
  else
    echo "4. ImagePullSecret (dockerhubcred in ${JOB_NAMESPACE}): NG (見つかりません)"
    exit 1
  fi

  # 5. cdr-controller 検出
  detect_cdr_target
  local current_img
  current_img=$(kubectl get "${CDR_KIND}/${CDR_NAME}" -n "${CDR_NS}" -o jsonpath='{.spec.template.spec.containers[?(@.name=="cdr-controller")].image}')
  echo "5. cdr-controller: ${CDR_NS}/${CDR_KIND}/${CDR_NAME} (現在: ${current_img})"
  echo ""
}

cleanup_existing_job() {
  echo "マイグレーション用一時 Job / Pod をクリーンアップしています..."
  kubectl delete job "${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null
  kubectl delete pod -l "job-name=${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null
  JOB_CREATED=0
}

verify_log_file() {
  local target_log=$1
  local expected_mode="${2:-auto}"

  if [ ! -f "${target_log}" ] || [ ! -s "${target_log}" ]; then
    echo "エラー: 有効なログファイルが存在しません: ${target_log}"
    return 1
  fi

  if [ "${expected_mode}" = "auto" ]; then
    case "$(basename "${target_log}")" in
      dryrun_*) expected_mode="dryrun" ;;
      real_*)   expected_mode="real" ;;
    esac
  fi

  echo "=== ログ自動検証: ${target_log} ==="

  if command -v python3 >/dev/null 2>&1; then
    local py_out
    if ! py_out=$(python3 - "${target_log}" "${expected_mode}" <<'PY'
import json
import re
import sys

log_path = sys.argv[1]
expected_mode = sys.argv[2]

errors = []
warnings = []
msgs = []
json_count = 0
system_id = ""

with open(log_path, "r", encoding="utf-8", errors="replace") as f:
    for line_no, raw in enumerate(f, 1):
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            json_count += 1
            msg = str(obj.get("msg", ""))
            level = obj.get("level", 30)
            msgs.append(msg)
            m_sys = re.search(r"Using systemID '([^']+)'", msg)
            if m_sys:
                system_id = m_sys.group(1)
            if level >= 50 or "[** ERROR **]" in msg or "FAILED" in msg or "Aborting:" in msg:
                errors.append(f"L{line_no} (level={level}): {msg}")
            elif level >= 40:
                warnings.append(f"L{line_no} (level={level}): {msg}")
        except json.JSONDecodeError:
            msgs.append(line)
            if "error" in line.lower() or "failed" in line.lower():
                errors.append(f"L{line_no}: {line}")

full_text = "\n".join(msgs)
commit_re = re.compile(r"\bcommit(?:ted|ting)?\s+\d+\s+operations", re.IGNORECASE)

has_dryrun_tag = "[DRY-RUN]" in full_text
has_completed = "CDR Sasa to Opswat migration completed" in full_text
has_commit = bool(commit_re.search(full_text))

if json_count == 0:
    errors.append("有効な JSON ログ行が検出されませんでした。")
if not has_completed:
    errors.append("完了メッセージ ('CDR Sasa to Opswat migration completed') が見つかりません。")
if not has_commit:
    errors.append("設定コミットの記録 ('commit/committed ... operations') が見つかりません。")

if expected_mode == "dryrun" and not has_dryrun_tag:
    errors.append("ドライラン想定ですが '[DRY-RUN]' タグがありません。")
elif expected_mode == "real" and has_dryrun_tag:
    errors.append("本番移行想定ですが '[DRY-RUN]' タグが含まれています。")

detected_mode = "DRY-RUN (シミュレーション)" if has_dryrun_tag else "REAL MIGRATION (本番反映)"
print(f"SYSTEM_ID_META={system_id}")
print(f"・実行モード   : {detected_mode}")

for m in msgs:
    if "Using systemID" in m:
        print(f"・対象システム : {m.replace('[DRY-RUN] ', '').strip()}")
    elif "System policy mapping names:" in m:
        print(f"・ポリシー変換 : {m.replace('[DRY-RUN] ', '').strip()}")
    elif "Updating 'policies/" in m:
        print(f"  - {m.replace('[DRY-RUN] ', '').strip()}")
    elif commit_re.search(m):
        print(f"・処理内容     : {m.replace('[DRY-RUN] ', '').strip()}")

if warnings:
    print(f"\n[警告] {len(warnings)} 件の警告:")
    for w in warnings:
        print(f"  ! {w}")

if errors:
    print(f"\n[判定: NG] {len(errors)} 件の問題が検出されました:")
    for e in errors:
        print(f"  x {e}")
    sys.exit(1)
else:
    print("\n[判定: OK] ログ上のエラーはなく、移行処理は正常です。")
    sys.exit(0)
PY
    ); then
      echo "${py_out}" | grep -v "^SYSTEM_ID_META="
      return 1
    fi
    DETECTED_SYSTEM_ID=$(echo "${py_out}" | awk -F= '/^SYSTEM_ID_META=/{print $2}')
    echo "${py_out}" | grep -v "^SYSTEM_ID_META="
  else
    if grep -qE '"level":50|\[\*\* ERROR \*\*\]|FAILED|Aborting:' "${target_log}"; then
      echo "[判定: NG] ログ内にエラーが検出されました:"
      grep -E '"level":50|\[\*\* ERROR \*\*\]|FAILED|Aborting:' "${target_log}"
      return 1
    fi
    if ! grep -q "CDR Sasa to Opswat migration completed" "${target_log}"; then
      echo "[判定: NG] 完了メッセージが見つかりません。"
      return 1
    fi
    echo "[判定: OK] エラーはなく、完了メッセージを確認しました。"
  fi
}

verify_consul_settings() {
  echo ""
  echo "=== Consul 実データ自動検証（管理画面設定の代替チェック） ==="

  if ! command -v python3 >/dev/null 2>&1; then
    echo "[Consul検証: スキップ] python3 が利用できないため、管理画面で設定を確認してください。"
    return 0
  fi

  TMP_KV_FILE=$(mktemp)

  # 1. K8s API プロキシ経由で shield-management-consul-ui (port 80) から取得
  if ! kubectl get --raw "/api/v1/namespaces/${JOB_NAMESPACE}/services/http:shield-management-consul-ui:80/proxy/v1/kv/?recurse" > "${TMP_KV_FILE}" 2>/dev/null; then
    : > "${TMP_KV_FILE}"
  fi

  # 2. フォールバック: Consul Pod 経由で取得
  if [ ! -s "${TMP_KV_FILE}" ]; then
    local consul_pod
    consul_pod=$(kubectl get pods -n "${JOB_NAMESPACE}" --no-headers 2>/dev/null | awk '/consul-0/{print $1; exit}' || true)
    if [ -n "${consul_pod}" ]; then
      if ! kubectl exec -n "${JOB_NAMESPACE}" "${consul_pod}" -- sh -c 'CONSUL_HTTP_ADDR=http://shield-management-consul-ui:80 consul kv export' > "${TMP_KV_FILE}" 2>/dev/null; then
        : > "${TMP_KV_FILE}"
      fi
    fi
  fi

  if [ ! -s "${TMP_KV_FILE}" ]; then
    rm -f "${TMP_KV_FILE}"
    TMP_KV_FILE=""
    echo "[Consul検証: スキップ] Consul KV データの取得をスキップしました（管理画面で設定を確認してください）。"
    return 0
  fi

  local py_rc=0
  python3 - "${TMP_KV_FILE}" "${DETECTED_SYSTEM_ID}" <<'PY' || py_rc=$?
import base64
import json
import sys

kv_path = sys.argv[1]
sys_id = sys.argv[2]

try:
    with open(kv_path, "r", encoding="utf-8", errors="replace") as f:
        entries = json.load(f)
    if not isinstance(entries, list):
        raise ValueError("Unexpected JSON root type")
except Exception as e:
    print(f"[Consul検証: スキップ] Consul KV のJSON解析をスキップしました: {e}")
    sys.exit(0)

kv = {}
for item in entries:
    if not isinstance(item, dict):
        continue
    k = item.get("key") or item.get("Key", "")
    v_b64 = item.get("value") if "value" in item else item.get("Value")
    if sys_id and sys_id not in k:
        continue
    if v_b64:
        try:
            kv[k] = base64.b64decode(v_b64).decode("utf-8", errors="replace")
        except Exception:
            pass

def find_json(suffix):
    for k, v in kv.items():
        if k.endswith(suffix):
            try:
                return json.loads(v)
            except Exception:
                return {}
    return {}

opswat_obj = find_json("file-management/cdr-vendors/Opswat")
options_obj = find_json("file-management/options")
policies_list = find_json("policies/policies")
default_policies_list = find_json("policies/default_policies")

errors = []

# 1. Opswat URL & サブスクリプションキー & ポリシー定義
base_url = opswat_obj.get("baseUrl", "") if isinstance(opswat_obj, dict) else ""
sub_key = opswat_obj.get("ericomProdEvalSubscriptionKey", "") if isinstance(opswat_obj, dict) else ""
if base_url == "https://opswat.ericomcloud.net/v4" and sub_key:
    print(f"・Opswat 接続  : OK ({base_url} / SubscriptionKey設定済)")
else:
    if base_url != "https://opswat.ericomcloud.net/v4":
        errors.append(f"Opswat baseUrl が不正です: '{base_url}'")
    if not sub_key:
        errors.append("Opswat サブスクリプションキー (ericomProdEvalSubscriptionKey) が未設定です。")

named_policies = {}
if isinstance(opswat_obj, dict):
    named_policies = {p.get("shieldName"): p.get("vendorName") for p in opswat_obj.get("namedPolicies", []) if isinstance(p, dict)}

if named_policies.get("AV Only") == "ericsson_multiscan_v1" and named_policies.get("Full CDR") == "ericsson_sanitize":
    print("・ポリシー定義 : OK (AV Only: ericsson_multiscan_v1 / Full CDR: ericsson_sanitize)")
else:
    errors.append(f"Opswat namedPolicies の定義が想定と異なります: {named_policies}")

# 2. アクティブベンダー & Sanitize File Size 上限確認
vendor = options_obj.get("vendor", "") if isinstance(options_obj, dict) else ""
max_san_mb = options_obj.get("maxSanitizeFileSizeMB", "") if isinstance(options_obj, dict) else ""
if vendor == "Opswat":
    size_label = f"{max_san_mb}MB" if max_san_mb != "" else "未設定"
    print(f"・有効ベンダー : OK (vendor: Opswat / maxSanitizeFileSizeMB: {size_label})")
else:
    errors.append(f"file-management/options の vendor が 'Opswat' になっていません (現在: '{vendor}')。")

# 3. ポリシー移行確認（download / upload キーのみを厳密に検査し、download_sasa は除外）
all_rules = []
for src in (policies_list, default_policies_list):
    if isinstance(src, list):
        all_rules.extend(src)
    elif isinstance(src, dict):
        all_rules.extend(src.values())

legacy_found = []
opswat_count = 0
for rule in all_rules:
    if not isinstance(rule, dict):
        continue
    for action_key in ("download", "upload"):
        val = rule.get(action_key)
        if val is None:
            continue
        s_val = str(val)
        if s_val in ("1000", "1001", "1002", "1003"):
            legacy_found.append(f"{action_key}={s_val}")
        elif s_val in ("1100", "1101"):
            opswat_count += 1

if legacy_found:
    errors.append(f"旧 SASA ポリシーIDが未変換のまま残っています: {legacy_found}")
else:
    print(f"・ポリシー移行 : OK (旧SASA ID残存なし / Opswatポリシー紐付け {opswat_count} 箇所確認)")

if errors:
    print("\n[Consul検証: NG] 以下の不整合が検出されました:")
    for e in errors:
        print(f"  x {e}")
    sys.exit(1)
else:
    print("\n[Consul検証: OK] 管理画面相当のすべての設定値が正常に反映されています。")
    sys.exit(0)
PY

  rm -f "${TMP_KV_FILE}"
  TMP_KV_FILE=""
  return "${py_rc}"
}

wait_and_save_log() {
  local prefix=$1
  local log_file="${PWD}/${prefix}_${JOB_NAME}_$(date +%Y%m%d_%H%M%S).log"
  LAST_LOG_FILE="${log_file}"
  local pod_name=""

  echo "新規 Pod の起動を待機しています..."
  for _ in $(seq 1 30); do
    pod_name=$(kubectl get pods -n "${JOB_NAMESPACE}" -l "job-name=${JOB_NAME}" --field-selector=status.phase!=Succeeded,status.phase!=Failed -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -z "${pod_name}" ]; then
      pod_name=$(kubectl get pods -n "${JOB_NAMESPACE}" -l "job-name=${JOB_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    fi
    [ -n "${pod_name}" ] && break
    sleep 1
  done

  if [ -z "${pod_name}" ]; then
    echo "エラー: Pod が作成されませんでした。"
    return 1
  fi

  echo "Pod (${pod_name}) のログを監視しています..."
  (
    for _ in $(seq 1 60); do
      phase=$(kubectl get pod "${pod_name}" -n "${JOB_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
      if [ "${phase}" = "Running" ] || [ "${phase}" = "Succeeded" ] || [ "${phase}" = "Failed" ]; then
        kubectl logs -f "${pod_name}" -n "${JOB_NAMESPACE}" > "${log_file}" 2>&1 || true
        break
      fi
      sleep 1
    done
  ) &
  LOG_TAIL_PID=$!

  for _ in $(seq 1 90); do
    succeeded=$(kubectl get job "${JOB_NAME}" -n "${JOB_NAMESPACE}" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
    failed_cond=$(kubectl get job "${JOB_NAME}" -n "${JOB_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)

    if [ "${succeeded}" = "1" ] || [ "${failed_cond}" = "True" ]; then
      sleep 1
      kill "${LOG_TAIL_PID}" 2>/dev/null || true
      wait "${LOG_TAIL_PID}" 2>/dev/null || true
      LOG_TAIL_PID=""
      if [ ! -s "${log_file}" ]; then
        kubectl logs -n "${JOB_NAMESPACE}" "job/${JOB_NAME}" > "${log_file}" 2>&1 || true
      fi

      if [ "${succeeded}" = "1" ]; then
        echo "Job が完了しました。ログを ${log_file} に保存しました。"
        return 0
      else
        echo "エラー: Job が異常終了しました。ログを ${log_file} に保存しました。"
        verify_log_file "${log_file}" "${prefix}" || true
        return 1
      fi
    fi
    sleep 2
  done

  kill "${LOG_TAIL_PID}" 2>/dev/null || true
  LOG_TAIL_PID=""
  echo "エラー: タイムアウトしました（Pod: ${pod_name}）。"
  return 1
}

perform_update_cdr() {
  echo ""
  echo "=== CDR コントローラーのイメージ更新・永続化・稼働確認 ==="
  if [ ! -f "${VALUES_FILE}" ]; then
    echo ""
    echo "[前提条件未達] ${VALUES_FILE} が見つかりません。"
    echo "Ericom Shield を初期インストールした OS ユーザでログインし直してから再度実行してください。"
    exit_expected
  fi

  local shield_ver
  shield_ver=$(get_shield_version)
  check_supported_version "${shield_ver}"

  detect_cdr_target
  echo "対象: Namespace=${CDR_NS}, Resource=${CDR_KIND}/${CDR_NAME}, Container=${CDR_CONTAINER}"
  kubectl set image "${CDR_KIND}/${CDR_NAME}" "${CDR_CONTAINER}=${NEW_CDR_IMAGE}" -n "${CDR_NS}"
  kubectl rollout status "${CDR_KIND}/${CDR_NAME}" -n "${CDR_NS}" --timeout=180s

  echo "新しい cdr-controller の起動ログを検証しています..."
  local new_cdr_pod
  new_cdr_pod=$(kubectl get pods -n "${CDR_NS}" --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[?(@.name=="'"${CDR_CONTAINER}"'")].image}{"\n"}{end}' 2>/dev/null | awk -v img="${NEW_CDR_IMAGE}" '$2 == img {print $1; exit}' || true)
  local log_target="${CDR_KIND}/${CDR_NAME}"
  [ -n "${new_cdr_pod}" ] && log_target="pod/${new_cdr_pod}"

  local opswat_ready=0
  for _ in $(seq 1 10); do
    if kubectl logs -n "${CDR_NS}" "${log_target}" -c "${CDR_CONTAINER}" --tail=50 2>/dev/null | grep -q "Setting 'Opswat' as System CDR vendor"; then
      opswat_ready=1
      break
    fi
    sleep 2
  done

  kubectl logs -n "${CDR_NS}" "${log_target}" -c "${CDR_CONTAINER}" --tail=50 2>/dev/null | grep -E "CDR controller Version|Setting 'Opswat'" || true
  if [ "${opswat_ready}" -eq 1 ]; then
    echo "[コントローラー起動検証: OK] Opswat ベンダーとしての起動を確認しました。"
  else
    echo "[コントローラー起動検証: 警告] 起動ログに Opswat 認識メッセージがまだ出力されていません。"
  fi

  echo "values.yaml の永続化設定を確認・更新します..."
  if grep -q "${NEW_CDR_IMAGE}" "${VALUES_FILE}"; then
    echo "更新済み（スキップ）: ${VALUES_FILE}"
  elif [ -w "${VALUES_FILE}" ]; then
    cp "${VALUES_FILE}" "${VALUES_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
    sed -i "s|securebrowsing/shield-cdr-controller:[^\"'[:space:]#]*|${NEW_CDR_IMAGE}|g" "${VALUES_FILE}"
    echo "更新完了（バックアップ作成済）: ${VALUES_FILE}"
  else
    echo "警告: ${VALUES_FILE} に書き込み権限がありません。初期インストールユーザで実行するか手動で更新してください。"
  fi
  grep "shield-cdr-controller" "${VALUES_FILE}" | sed 's/^/  -> /'
}

case "${1:-}" in
  check)
    run_precheck
    ;;

  dryrun)
    run_precheck
    echo "=== Step 1: ドライランを実行します ==="
    cleanup_existing_job
    JOB_CREATED=1
    tr -d '\r' < "${YAML_FILE}" | kubectl apply -f -
    wait_and_save_log "dryrun"
    verify_log_file "${LAST_LOG_FILE}" "dryrun"
    echo ""
    cleanup_existing_job
    cat <<EOF

======================================================================
[Step 1 完了] ドライランは正常に終了しました。
1. 生成された以下のログファイルをサポートへ送付し、承認を得てください:
   ${LAST_LOG_FILE}
2. 承認後、以下を実行して本番移行（設定反映＋コントローラー更新＋後処理）へ進んでください:
   $0 migrate
======================================================================
EOF
    ;;

  migrate)
    run_precheck
    if ! ls "${PWD}"/dryrun_${JOB_NAME}_*.log >/dev/null 2>&1 && [ "${FORCE_MIGRATE:-0}" != "1" ]; then
      echo "警告: カレントディレクトリ (${PWD}) にドライランログが見つかりません。"
      read -r -p "ドライランおよびサポート承認が完了している場合のみ 'y' を入力して続行してください [y/N]: " ans
      if [[ ! "${ans}" =~ ^[Yy]$ ]]; then
        echo "中断しました。先に '$0 dryrun' を実行してください。"
        exit_expected
      fi
    fi

    echo "=== Step 2: 本番移行・設定検証・コントローラー更新を一括実行します ==="
    cleanup_existing_job

    CLEAN_MANIFEST=$(tr -d '\r' < "${YAML_FILE}" | awk '
      /^[[:space:]]*-[[:space:]]*name:[[:space:]]*DRY_RUN[[:space:]]*$/ { skip=1; next }
      skip == 1 && /^[[:space:]]*value:/ { skip=0; next }
      { skip=0; print }
    ')

    if echo "${CLEAN_MANIFEST}" | grep -q "DRY_RUN"; then
      echo "エラー: DRY_RUN の除外に失敗しました。YAML を確認してください。"
      exit 1
    fi

    echo "DRY_RUN を除外して本番ジョブを実行します..."
    JOB_CREATED=1
    echo "${CLEAN_MANIFEST}" | kubectl apply -f -
    wait_and_save_log "real"
    verify_log_file "${LAST_LOG_FILE}" "real"
    verify_consul_settings
    perform_update_cdr
    echo ""
    cleanup_existing_job
    cat <<EOF

======================================================================
[Step 2 完了] 本番移行・コントローラー更新・後処理がすべて正常に完了しました。
・本番移行ログ: ${LAST_LOG_FILE}

最後に、ブラウザから隔離セッション経由でファイルのダウンロード/アップロードを
テストし、正常に動作することを確認して作業完了となります。
======================================================================
EOF
    ;;

  update-cdr)
    perform_update_cdr
    ;;

  verify-log)
    TARGET_LOG="${2:-}"
    if [ -z "${TARGET_LOG}" ]; then
      TARGET_LOG=$(ls -t "${PWD}"/dryrun_${JOB_NAME}_*.log "${PWD}"/real_${JOB_NAME}_*.log 2>/dev/null | head -n 1 || true)
      if [ -z "${TARGET_LOG}" ]; then
        echo "エラー: チェック対象のログファイルが見つかりません。"
        exit_expected
      fi
    fi
    verify_log_file "${TARGET_LOG}"
    ;;

  cleanup)
    echo "=== マイグレーション用一時 Job と Pod を削除します ==="
    cleanup_existing_job
    echo "クリーンアップが完了しました。"
    ;;

  *)
    usage
    ;;
esac