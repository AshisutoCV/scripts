#!/bin/bash

####################
### K.K. Ashisuto
### VER=20251202a
####################

# --- 設定 ---
TARGET_PROJ_NAME="Shield"
NAMESPACES=("common" "elk" "farm-services" "management" "proxy")
RANCHER_CMD="/usr/local/bin/rancher"
KUBECTL_CMD="/usr/local/bin/kubectl"
STATUS_SCRIPT="$HOME/ericomshield/shield-status.sh"

# --- 事前チェック ---
if [[ ! -x "$RANCHER_CMD" ]]; then
    echo "[ERROR] Rancher CLI ($RANCHER_CMD) が見つかりません。"
    exit 1
fi

if [[ ! -x "$KUBECTL_CMD" ]]; then
    echo "[ERROR] kubectl ($KUBECTL_CMD) が見つかりません。"
    exit 1
fi

# --- メイン処理 ---
echo "----------------------------------------------------------"
echo "[1] ShieldプロジェクトIDの特定"

# ShieldプロジェクトのIDを取得
TARGET_ID=$($RANCHER_CMD projects 2>/dev/null | grep -w "$TARGET_PROJ_NAME" | awk '{print $1}')

# ID取得チェック
if [ -z "$TARGET_ID" ]; then
    echo "[ERROR] '$TARGET_PROJ_NAME' プロジェクトが見つかりません。処理を中断します。"
    echo "        Rancherへのログイン状態やプロジェクト名を確認してください。"
    exit 1
elif [ $(echo "$TARGET_ID" | wc -l) -gt 1 ]; then
    echo "[ERROR] '$TARGET_PROJ_NAME' プロジェクトが複数検出されました。手動確認が必要です。"
    echo "        検出されたID:"
    echo "$TARGET_ID"
    exit 1
else
    echo "[INFO] ターゲットID特定: $TARGET_ID ($TARGET_PROJ_NAME)"
fi

echo ""
echo "----------------------------------------------------------"
echo "[2] ネームスペースの紐付けチェックと修正"

for ns in "${NAMESPACES[@]}"; do
    # 現在のプロジェクトIDを取得
    CURRENT_ID=$($KUBECTL_CMD get ns "$ns" -o jsonpath='{.metadata.annotations.field\.cattle\.io/projectId}' 2>/dev/null)

    if [ "$CURRENT_ID" == "$TARGET_ID" ]; then
        # 既にShieldプロジェクトならスキップ
        echo "[SKIP] '$ns' は既に正しいプロジェクトに所属しています。"
    else
        # 違うプロジェクト(または未所属)なら移動
        echo "[MOVE] '$ns' を移動します... (現在: ${CURRENT_ID:-なし} -> 移動先: $TARGET_ID)"
        $RANCHER_CMD namespaces move "$ns" "$TARGET_ID"

        if [ $? -eq 0 ]; then
             echo "       -> 移動成功"
        else
             echo "       -> [WARN] 移動失敗 (ログを確認してください)"
        fi
    fi
done

echo ""
echo "----------------------------------------------------------"
echo "[3] ステータス最終確認"

if [ -f "$STATUS_SCRIPT" ]; then
    bash "$STATUS_SCRIPT"
else
    echo "[WARN] ステータス確認スクリプト ($STATUS_SCRIPT) が見つかりませんでした。"
    echo "       手動でステータスを確認してください。"
fi

#echo "----------------------------------------------------------"
echo "処理完了"
exit 0