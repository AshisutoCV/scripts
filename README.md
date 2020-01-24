# scripts一覧

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
* shield-status.sh
    * Workload ステータス確認

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
	* ノード事前準備用スクリプト(メーカー製)
* setup.sh
	* セットアップスクリプト(日本バージョンコントロール版)
* ver-change.sh
	* 利用バージョン切り替え用スクリプト
* pre-install-check.sh
	* ノード事前チェック用(メーカー製)
* updater.sh
	* updateスクリプトの更新用？(メーカー製) ※使ってないはず。
* backup-restore.sh
    * バックアップ前のクラスタ離脱と、リストア時の再参加用スクリプト。
    
### 公開バージョン定義ファイル
* pre-rel-ver.txt
	* pre-use用
* rel-ver.txt
	* リリースバージョンの一覧

## 共通
* proxy.py
	* Proxy設定スクリプト(Ubuntu用)
* proxy-cent.py
	* Proxy設定スクリプト(CnetOS用)
* MachineStats.zip
	* Votiroライセンス申請用情報取得スクリプト(メーカー製)

## サポートツール(括弧内のものは本体から自動DLする部品)
* shield-registry-start.sh
	* ローカルリポジトリサーバ作成スクリプト(Swarm限定)(メーカー製)
* nocat.sh (nocat.py)
	* カテゴリ設定OFFスクリプト(Swarm限定)
* showlic.sh (showlic.py)
	* ライセンス情報詳細取得スクリプト(Swarm限定)
* spellcheck.sh
	* スペルチェック切り替えスクリプト(Swarm限定)(メーカー製)
* fps-change.sh (fpschange.py)
	* FPS設定値最適化スクリプト(Swarm限定)
* install-proxy-rules.sh
	* 上位プロキシ問題暫定回避(iptables設定)スクリプト(Swarm限定)(メーカー製)
* uninstall-proxy-rules.sh
	* 上位プロキシ問題暫定回避(iptables設定)設定削除スクリプト(Swarm限定)(メーカー製)
* getlog.sh
    * elkからのログ取り出しスクリプト(k8s限定)

