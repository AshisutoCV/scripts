# Changelog

## [VER=20191003a] - 2019/10/03

### 追加
#### shield-update.sh
- yamlファイル差分のチェックを事前実施して警告。後にshieldsetup.shを呼び出すように実装。

### 変更
#### shield-setup.sh
- bonding対応
- System component が3台構成ならantiafinity:hardを有効化
- updateを別スクリプト(shield-update.sh)からのトリガーを想定するように修正
- Dockerバージョン固定の修正
- logファイルをlogディレクトリに集約

#### shield-start.sh
- logファイルをlogディレクトリに集約

#### shield-stop.sh
- logファイルをlogディレクトリに集約
- 以前のバージョンにおける不正な common の削除を判定により削除可能なよう修正(恒久対策完了)

#### shield-nodes.sh
- logファイルをlogディレクトリに集約
- Rancher Agent追加用コマンド(command.txt)を実行時に随時更新するように変更。

#### delete-all.sh
- CentOSにおいて、rancher-store ディレクトリが削除されない問題に対応
- 各種追加スクリプトやyamlなどの削除を追加

### 削除
- なし

### 移動
#### sup へ
- fps-change.sh
- nocat.sh
- showlic.sh
- shield-registry-start.sh
- spellcheck.sh
- install-proxy-rules.sh
- uninstall-proxy-rules.sh
