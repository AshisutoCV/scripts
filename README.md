# scripts

## k8s用
### セットアップ＆運用スクリプト
* shield-setup.sh
  * セットアップ用
* shield-nodes.sh
  * ノード追加、ラベル再設定
* shield-start.sh
  * Shieldのスタート(redeploy)
* shield-stop.sh
  * Shieldのストップ(delete)
* shield-update.sh
  * 別バージョンへの切り替え
* shield-restore.sh
  * バックアップディレクトリに存在するjsonファイルを使ったリストア
* delete-all.sh
  * 実行ノード上での全てを削除

### 公開バージョン定義ファイル
* k8s-pre-rel-ver.txt
  * pre-use用
* k8s-rel-ver-git.txt
  * Chart番号(ビルド番号)とGitHubに置けるリリース番号のマッチング
* k8s-rel-ver.txt
  * リリースバージョンの一覧

## swarm用
### セットアップ＆運用スクリプト
* prepare-node.sh
* setup.sh
* ver-change.sh
* pre-install-check.sh
* updater.sh

### 公開バージョン定義ファイル
* pre-rel-ver.txt
* rel-ver.txt

## 共通
* proxy.py
* proxy-cent.py
