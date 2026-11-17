#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_YAML_NAME="sasa-to-opswat-migration-onprem-job.yaml"
JOB_NAMESPACE="management"
JOB_NAME="es-sasa-to-opswat-cdr-migrator"
NEW_CDR_IMAGE="securebrowsing/shield-cdr-controller:261109-13.09"
DEFAULT_VALUES_FILE="${HOME}/ericomshield/shield/values.yaml"
LAST_LOG_FILE=""

if [ -z "${YAML_FILE:-}" ]; then
  if [ -f "./${DEFAULT_YAML_NAME}" ]; then
    YAML_FILE="./${DEFAULT_YAML_NAME}"
  elif [ -f "${SCRIPT_DIR}/${DEFAULT_YAML_NAME}" ]; then
    YAML_FILE="${SCRIPT_DIR}/${DEFAULT_YAML_NAME}"
  else
    YAML_FILE="./${DEFAULT_YAML_NAME}"
  fi
fi

usage() {
  cat <<EOF
Usage: $0 {dryrun|migrate|update-cdr|cleanup|check|verify-log}

Standard Workflow:
  1. $0 dryrun       : Stage 1 - 事前チェック + ドライラン実行・ログ保存・検証
                       (保存された dryrun_*.log をサポートへ送付して確認)
  2. $0 migrate      : Stage 2 - 本番移行実行・ログ保存・検証
                       (完了後、Admin画面で Opswat 設定・ポリシーを確認)
  3. $0 update-cdr   : Stage 3 - cdr-controller 更新・ログ確認・values.yaml 書き換え
                       (完了後、ブラウザでダウンロード/アップロードをテスト)
  4. $0 cleanup      : 後処理  - マイグレーション用 Job と Pod の削除

Utility Commands:
  check              : 環境診断のみ単独実行
  verify-log [FILE]  : 保存済みログの正常性チェック（FILE省略時は最新ログ）
EOF
  exit 1
}

detect_cdr_target() {
  CDR_INFO=$(kubectl get deploy,ds,sts -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.kind}{" "}{.metadata.name}{" "}{.spec.template.spec.containers[0].name}{"\n"}{end}' | grep -w "cdr-controller" | head -n 1 || true)

  if [ -z "${CDR_INFO}" ]; then
    echo "エラー: クラスター内に cdr-controller が見つかりませんでした。"
    exit 1
  fi

  CDR_NS=$(echo "${CDR_INFO}" | awk '{print $1}')
  CDR_KIND=$(echo "${CDR_INFO}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
  CDR_NAME=$(echo "${CDR_INFO}" | awk '{print $3}')
  CDR_CONTAINER=$(echo "${CDR_INFO}" | awk '{print $4}')
}

resolve_values_files() {
  if [ -n "${VALUES_FILE:-}" ]; then
    [ -f "${VALUES_FILE}" ] && echo "${VALUES_FILE}"
    return 0
  fi

  if [ -f "${DEFAULT_VALUES_FILE}" ] && grep -q "shield-cdr-controller" "${DEFAULT_VALUES_FILE}" 2>/dev/null; then
    echo "${DEFAULT_VALUES_FILE}"
    return 0
  fi

  local search_targets=()
  [ -d "${HOME}/ericomshield" ] && search_targets+=("${HOME}/ericomshield")
  [ -d "/ericomshield/shield" ] && search_targets+=("/ericomshield/shield")

  if [ ${#search_targets[@]} -gt 0 ]; then
    find "${search_targets[@]}" -maxdepth 4 -type f \( -name "values.yaml" -o -name "custom-values*.yaml" \) 2>/dev/null \
      | xargs grep -l "shield-cdr-controller" 2>/dev/null || true
  fi
}

run_precheck() {
  echo "=== 事前環境チェック ==="
  if [ -f "${YAML_FILE}" ]; then
    echo "1. 移行用 YAML (${YAML_FILE}): OK"
  else
    echo "1. 移行用 YAML (${YAML_FILE}): NG (見つかりません)"
    exit 1
  fi

  if kubectl get secret dockerhubcred -n "${JOB_NAMESPACE}" >/dev/null 2>&1; then
    echo "2. ImagePullSecret (dockerhubcred in ${JOB_NAMESPACE}): OK"
  else
    echo "2. ImagePullSecret (dockerhubcred in ${JOB_NAMESPACE}): NG (見つかりません)"
    exit 1
  fi

  detect_cdr_target
  local current_img
  current_img=$(kubectl get "${CDR_KIND}/${CDR_NAME}" -n "${CDR_NS}" -o jsonpath='{.spec.template.spec.containers[0].image}')
  echo "3. cdr-controller: ${CDR_NS}/${CDR_KIND}/${CDR_NAME} (現在: ${current_img})"

  local files
  files=$(resolve_values_files)
  if [ -n "${files}" ]; then
    echo "4. 対象 values.yaml:"
    echo "${files}" | sed 's/^/   - /'
  else
    echo "4. 対象 values.yaml: なし（該当ファイルが見つかりません）"
  fi
  echo ""
}

cleanup_existing_job() {
  echo "既存のマイグレーション Job / Pod をクリーンアップしています..."
  kubectl delete job "${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null
  kubectl delete pod -l "job-name=${JOB_NAME}" -n "${JOB_NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null
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

  echo "=== ログ検証結果: ${target_log} ==="

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${target_log}" "${expected_mode}" <<'PY'
import json
import re
import sys

log_path = sys.argv[1]
expected_mode = sys.argv[2]

errors = []
warnings = []
msgs = []
json_count = 0

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
    print("\n[判定: OK] エラーはなく、移行ログは正常です。")
    sys.exit(0)
PY
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

wait_and_save_log() {
  local prefix=$1
  local log_file="${prefix}_${JOB_NAME}_$(date +%Y%m%d_%H%M%S).log"
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
    kubectl describe job "${JOB_NAME}" -n "${JOB_NAMESPACE}" | tail -n 15
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
  local log_pid=$!

  for _ in $(seq 1 90); do
    succeeded=$(kubectl get job "${JOB_NAME}" -n "${JOB_NAMESPACE}" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
    failed_cond=$(kubectl get job "${JOB_NAME}" -n "${JOB_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)

    if [ "${succeeded}" = "1" ] || [ "${failed_cond}" = "True" ]; then
      wait "${log_pid}" 2>/dev/null || true
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

  kill "${log_pid}" 2>/dev/null || true
  echo "警告: タイムアウトしました。現在の Pod 状態:"
  kubectl describe pod "${pod_name}" -n "${JOB_NAMESPACE}" 2>/dev/null | tail -n 20 || true
  return 1
}

case "${1:-}" in
  check)
    run_precheck
    ;;

  dryrun)
    run_precheck
    echo "=== Stage 1: ドライランを実行します ==="
    cleanup_existing_job
    tr -d '\r' < "${YAML_FILE}" | kubectl apply -f -
    wait_and_save_log "dryrun"
    verify_log_file "${LAST_LOG_FILE}" "dryrun"
    cat <<EOF

[次のアクション]
1. 保存されたログ (${LAST_LOG_FILE}) をサポートへ送付し、承認を得てください。
2. 承認後、以下を実行して本番移行へ進んでください:
   $0 migrate
EOF
    ;;

  migrate)
    echo "=== Stage 2: 本番移行を実行します ==="
    [ -f "${YAML_FILE}" ] || { echo "エラー: ${YAML_FILE} が見つかりません。"; exit 1; }
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
    echo "${CLEAN_MANIFEST}" | kubectl apply -f -
    wait_and_save_log "real"
    verify_log_file "${LAST_LOG_FILE}" "real"
    cat <<EOF

[次のアクション]
1. 管理画面 (Admin -> Settings -> Files & Sanitization) で以下を確認してください:
   - Opswat URL : https://opswat.ericomcloud.net/v4
   - ポリシー   : AV Only (multiscan,unarchive) / Full CDR (ericsson_sanitize)
   - サイズ上限 : 3814
2. 管理画面 (Admin -> Policies) で Download / Upload ポリシーの移行を確認してください。
3. 確認後、以下を実行して CDR コントローラーを更新してください:
   $0 update-cdr
EOF
    ;;

  verify-log)
    TARGET_LOG="${2:-}"
    if [ -z "${TARGET_LOG}" ]; then
      TARGET_LOG=$(ls -t dryrun_${JOB_NAME}_*.log real_${JOB_NAME}_*.log 2>/dev/null | head -n 1 || true)
      if [ -z "${TARGET_LOG}" ]; then
        echo "エラー: チェック対象のログファイルが見つかりません。"
        exit 1
      fi
    fi
    verify_log_file "${TARGET_LOG}"
    ;;

  update-cdr)
    echo "=== Stage 3: cdr-controller のイメージを更新します ==="
    detect_cdr_target
    echo "対象: Namespace=${CDR_NS}, Resource=${CDR_KIND}/${CDR_NAME}, Container=${CDR_CONTAINER}"

    kubectl set image "${CDR_KIND}/${CDR_NAME}" "${CDR_CONTAINER}=${NEW_CDR_IMAGE}" -n "${CDR_NS}"
    kubectl rollout status "${CDR_KIND}/${CDR_NAME}" -n "${CDR_NS}" --timeout=180s

    echo "新しい cdr-controller の起動ログを確認しています..."
    sleep 3
    kubectl logs -n "${CDR_NS}" "${CDR_KIND}/${CDR_NAME}" --tail=30 | grep -E "CDR controller Version|Setting 'Opswat'" || true

    echo "values.yaml の永続化設定を確認・更新します..."
    FILES=$(resolve_values_files)
    if [ -n "${FILES}" ]; then
      for f in ${FILES}; do
        if grep -q "${NEW_CDR_IMAGE}" "${f}"; then
          echo "更新済み（スキップ）: ${f}"
        elif [ -w "${f}" ]; then
          cp "${f}" "${f}.bak_$(date +%Y%m%d_%H%M%S)"
          sed -i "s|securebrowsing/shield-cdr-controller:[^\"' ]*|${NEW_CDR_IMAGE}|g" "${f}"
          echo "更新完了（バックアップ作成済）: ${f}"
        else
          echo "警告: 書き込み権限がありません。手動で更新してください: ${f}"
        fi
        grep "shield-cdr-controller" "${f}" | sed 's/^/  -> /'
      done
    else
      echo "情報: 書き換え対象の values.yaml が見つかりませんでした。"
    fi
    cat <<EOF

[次のアクション]
1. ブラウザからファイルのダウンロードおよびアップロードの動作テストを実施してください。
2. テストに問題がなければ、以下を実行して一時 Job / Pod を削除してください:
   $0 cleanup
EOF
    ;;

  cleanup)
    echo "=== 後処理: マイグレーション用 Job と Pod を削除します ==="
    cleanup_existing_job
    echo "すべての移行作業が完了しました。"
    ;;

  *)
    usage
    ;;
esac
