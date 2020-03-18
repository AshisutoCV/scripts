# Changelog

## [VER=20200318a] - 2020/03/18

### 変更
#### shield-setup.sh
* k8sリソース予約、ブラウザコンテナのリソース設定変更を.es_custom_envで行えるように修正

#### shield-start.sh
* ブラウザコンテナのリソース設定変更を.es_custom_envで恒久保持できるように修正

--------------------------------------------------------------

## [VER=20200313a] - 2020/03/13

### 変更
#### shield-sup.sh
* /var/lib/docker/containers配下のjsonログを取得対象に追加。

#### delete-all.sh
* delete-all単体での実行時は自分自身の削除をしないように変更。
* /var/lib/kubelet/pods/配下の削除が出来なくなる問題を修正

#### shield-setup.sh
* deployが失敗する場合、startを再実行してケア(主にUpdate時)
* deploy時の標準出力を廃止。

#### shield-start.sh
* deployが失敗する場合、startを再実行してケア
* deploy時の標準出力を廃止。

#### shield-status.sh
* setup/startの修正に伴う微調整

--------------------------------------------------------------

## [VER=20200227b] - 2020/02/27

### 変更
#### shield-status.sh
* typo 

--------------------------------------------------------------

## [VER=20200227a] - 2020/02/27

### 変更
#### shield-status.sh
* 未展開時のエラーコントロール

### 変更
#### shield-start.sh
* deploy前のsystem Projectステータス確認で1911より前にバグがある問題を修正

--------------------------------------------------------------

## [VER=20200226a] - 2020/02/26

### 変更
#### shield-setup.sh
* swarm版で使っていた場合に固定されているdocker-ceのバージョンを解除
* deploy前のsystem Projectステータス確認で1911より前にバグがある問題を修正

#### shield-sup.sh
* containerログがシンボリックリンクのまま収集されていた問題を修正しました。

--------------------------------------------------------------

## [VER=20200219a] - 2020/02/19

### 変更
#### shield-setup.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)
* elk snapshotとantiafinityのコメント処理修正
* deploy前のsystem Projectステータス確認の追加

#### shield-status.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)
* system Projectステータス確認の追加

#### shield-start.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)
* deploy前のsystem Projectステータス確認の追加

#### shield-nodes.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)

#### shield-restore.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)

#### shield-update.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)
* elk snapshotとantiafinityのコメント処理修正

#### shield-stop.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)

#### shield-sup.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)

#### getlog.sh
* HOMEおよびKUBECONFIGのexportを追加(UbuntuとCentOSでのsudo差分保護)

--------------------------------------------------------------

## [VER=20200217a] - 2020/02/17

### 変更
#### shield-update.sh
* タイプミス修正
--------------------------------------------------------------

## [VER=20200212a] - 2020/02/12

### 変更
#### shield-setup.sh
* elkのsnapshotについてコメントアウトを実装。

#### shield-update.sh
* elkのsnapshotについてコメントアウトを実装。

--------------------------------------------------------------

## [VER=20200210a] - 2020/02/10

### 変更
#### shield-setup.sh
* clean-rancher-agent.sh をDLコマンドに追加。
* updateの直接呼び出しを抑止
* antiAffinityのコメントアウト調整

#### shield-update.sh
* antiAffinityのコメントアウト調整

#### shield-status.sh
* workload未Active時の表示変更(改善)

#### shield-stop.sh
* 停止済みで実行した際のエラー表示抑止

--------------------------------------------------------------

## [VER=20200207a] - 2020/02/07

### 変更
#### shield-setup.sh
* shield-statusによる確認メッセージ表示
* helmのupdateに対応

#### shield-update.sh
* helmのupdateに対応
* rancherのupdateに対応

#### shield-start.sh
* shield-statusによる確認メッセージ表示

#### shield-status.sh
* workload未Active時の表示変更

#### shield-sup.sh
* getlogの呼び出し時レポート指定の追加

#### getlog.sh
* レポート指定の一部でtypo修正

--------------------------------------------------------------

## [VER=20200206c] - 2020/02/06

### 変更
#### shield-setup.sh
* クラスタ作成パラメタとしてkubelet,systemのリザーブを設定。
* helmの更新に対応。

--------------------------------------------------------------

## [VER=20200206b] - 2020/02/06

### 変更
#### shield-setup.sh
* 20200206aを一時切り戻し対応。

--------------------------------------------------------------

## [VER=20200206a] - 2020/02/06

### 変更
#### shield-sup.sh
* custom-management.yamlにおいてlocalpathを変更している場合にエラーとなる問題を修正(k8s)

#### shield-setup.sh
* クラスタ作成パラメタとしてkubelet,systemのリザーブを設定。

#### delete-all.sh
* 誤って(?)sudoによる実行を行った場合、ericomshieldディレクトリのownerがrootになる問題に対応

--------------------------------------------------------------

## [VER=20200205a] - 2020/02/05

### 変更
#### shield-sup.sh
* 相対パスでshield-sup.shを実行した際、getlog.shの呼び出しが失敗する問題を修正。

#### getlog.sh
* elastichserchの待ち受けポートを9200と9100の両方に対応。

--------------------------------------------------------------

## [VER=20200124a] - 2020/01/24

### 追加
#### shield-status.sh
* (k8s) workloadがActiveかどうかの確認を行うスクリプトを追加。

### 変更
#### shield-setup.sh
* shield-status.shをGETするように変更。

--------------------------------------------------------------

## [VER=20200115a] - 2020/01/15

### 追加
#### backup-restore.sh
* （swarm専用）バックアップ前にクラスタからの切り離し。リストア時に再参加。

--------------------------------------------------------------

## [VER=20200109a] - 2020/01/09

### 変更
#### shield-update.sh
* 実行PATHがカレントでない場合をケア

#### shield-setup.sh
* 実行PATHがカレントでない場合をケア
* add-shield-repo.shのSHIELD_REPOの変更ミスに影響されないように対処。

#### shield-stop.sh
* 実行PATHがカレントでない場合をケア

#### shield-start.sh
* 実行PATHがカレントでない場合をケア

#### shield-nodes.sh
* 実行PATHがカレントでない場合をケア

--------------------------------------------------------------

## [VER=20200108a] - 2020/01/08

### 変更
#### siheld-sup.sh
* logsディレクトリのPATH変更対応

#### shield-update.sh
* rancher-storeのPATH変更対応
* バージョン選択でのバージョン表記変更(dev/staging除く)
* ericomshieldディレクトリ配下への移動対応。(1911以降)

#### shield-setup.sh
* バージョン選択でのバージョン表記変更(dev/staging除く)
* ericomshieldディレクトリ配下への移動対応。(1911以降)
* docker グループへの追加判定処理の修正

#### shield-stop.sh
* Dev/Staging選択時にエラーになる問題を修正。
* ericomshieldディレクトリ配下への移動対応。(1911以降)

#### shield-start.sh
* ericomshieldディレクトリ配下への移動対応。(1911以降)

--------------------------------------------------------------

## [VER=20191227a] - 2019/12/27

### 変更
#### shield-sup.sh
* swarm版のコンテナログを収集
* その他微修正

#### getlog.sh
* TZの扱いを修正。サーバのTZに依存せず処理可能。

#### shield-update.sh
* 実際のUpdate処理直前に、shield-stopによる停止を行うように変更。

#### shield-setup.sh
* TOKEN取得などのエラーハンドリング強化
* Docker0のbip変更対応(.es_custom_env) 

#### shield-nodes.sh
* 構成選択によるラベリングをshield-setup.shと揃えた。

#### shield-start.sh
* 実行完了時に、Rancherによる確認を行うようメッセージを表示。

--------------------------------------------------------------

## [VER=20191218c] - 2019/12/18

### 変更
#### shield-setup.sh
* 19.12(dev)のdeployが失敗する問題に対応。（LOGFILEパスの修正：再）

#### shield-start.sh
* 19.12(dev)のdeployが失敗する問題に対応。（LOGFILEパスの修正：再）

--------------------------------------------------------------

## [VER=20191218b] - 2019/12/18

### 変更
#### shield-setup.sh
* 19.12(dev)のdeployが失敗する問題に対応。（typo）

#### shield-update.sh
* 引数利用時に、再実行コマンドの表示として引数を明示するように修正

--------------------------------------------------------------

## [VER=20191218a] - 2019/12/18

### 変更
#### shield-update.sh
* Devが利用出来ない問題を修正

#### shield-setup.sh
* 19.12(dev)のdeployが失敗する問題に対応。（LOGFILEパスの修正）

--------------------------------------------------------------

## [VER=20191216a] - 2019/12/16

### 変更
#### delete-all.sh
* 削除対象ディレクトリを拡張

--------------------------------------------------------------

## [VER=20191213a] - 2019/12/13

### 変更
#### shield-setup.sh
* 初回LOGINTOKEの取得前にスリープを設定

--------------------------------------------------------------

## [VER=20191212a] - 2019/12/12

### 変更
#### delete-all.sh
* 19.11からのrancher-storeパス変更にともなう対応

--------------------------------------------------------------

## [VER=20191211a] - 2019/12/11

### 変更
#### shield-setup.sh
* ファームサービスの標準配置をsystemコンポーネント側に変更。
* --delete-allオプションでnoを入れても処理が進む問題を修正。

--------------------------------------------------------------

## [VER=20191206a] - 2019/12/06

### 変更
#### shield-stop.sh
* 19.11でのdelete-shield.sh変更に対応。

### 変更
#### shield-setup.sh
* オールインワンインストールの選択をAdvance側へ。

--------------------------------------------------------------

## [VER=20191203a] - 2019/12/03

### 変更
#### shield-update.sh
* configure-sysctl-values.sh の差分実行コマンドミス修正。

--------------------------------------------------------------

## [VER=20191119a] - 2019/11/19

### 変更
#### proxy-cent.py
* yumのproxy指定修正。

--------------------------------------------------------------

## [VER=20191106a] - 2019/11/6

### 変更
#### shield-setup.sh
* DevおよびStaging選択時のブランチ指定を修正。

#### shield-update.sh
* DevおよびStaging選択時のブランチ指定を修正。

--------------------------------------------------------------

## [VER=20191105a] - 2019/11/5

### 変更
#### shield-nodes.sh
* command.txtの書き換えに失敗していた問題を修正。

--------------------------------------------------------------

## [VER=20191101b] - 2019/11/1

### 変更
#### shield-setup.sh
* TZ対応の不足対応。

#### shield-start.sh
* TZ対応の不足対応。

--------------------------------------------------------------


## [VER=20191101a] - 2019/11/1

### 変更
#### shield-setup.sh
* antiafinityの設定処理が正しくおこなわれていない問題を修正。

--------------------------------------------------------------

## [VER=20191031b] - 2019/10/31

### 追加
#### shield-sup.sh
* 新規作成。

### 変更
#### getlog.sh
* swarm版にも対応。

#### shield-setup.sh
* UbuntuにおいてUniverseリポジトリの追加と、libssl1.1の問題に対処しました。(BugFix)
* shield-sup.sh および getlog.sh を取得するように設定。(sup/ 配下に配置。)

--------------------------------------------------------------

## [VER=20191031a] - 2019/10/31

### 変更
#### getlog.sh
* デフォルトでのTZ指定を廃止。および収集単位を10000レコードに。TZ指定した場合は100レコード単位にスイッチする。

#### shield-setup.sh
* deploy-shield.sh内のTZ指定部分のメーカーbugをケアするように対応
* ses_limit_flgが正しく指定できない問題を修正。
* UbuntuにおいてUniverseリポジトリの追加と、libssl1.1の問題に対処しました。

#### shield-start.sh
* deploy-shield.sh内のTZ指定部分のメーカーbugをケアするように対応

--------------------------------------------------------------

## [VER=20191018a] - 2019/10/18

### 変更
#### shield-setup.sh
* 他ノードでの実行コマンド表示で不要なコマンド(setup-node.sh)が表示されていたのを削除。

--------------------------------------------------------------

## [VER=20191016a] - 2019/10/16

### 変更
#### shield-update.sh
* chekc_sysctlが未呼び出しである問題を修正

--------------------------------------------------------------

## [VER=20191010a] - 2019/10/10

### 変更
#### shield-update.sh
* yamlファイルの比較で差分がまったく無い場合にエラーになる問題を修正。

--------------------------------------------------------------

## [VER=20191008a] - 2019/10/08

### 変更
#### shield-restore.sh
* 自動リストア抑止が行われるようになったbuild576以降のconsul_backupに対応。

#### shield-update.sh
* configure-sysctl-values.shの差分があった場合、他のノードでも実行するように表示。

--------------------------------------------------------------

## [VER=20191007b] - 2019/10/07

### 変更
#### shield-update.sh
* 差分確認後の再実行時、updateを実行してよいかどうかの確認を行うように修正。

--------------------------------------------------------------

## [VER=20191007a] - 2019/10/07

### 変更
#### shield-update.sh
* shield-setups.shの更新箇所にバグあり。修正対応。
* logsディレクトリが存在しない場合に作成するように修正。

#### shield-start.sh
* logsディレクトリが存在しない場合に作成するように修正。

#### shield-stop.sh
* logsディレクトリが存在しない場合に作成するように修正。

#### shield-nodes.sh
* logsディレクトリが存在しない場合に作成するように修正。

--------------------------------------------------------------

## [VER=20191003a] - 2019/10/03

### 追加
#### shield-update.sh
* yamlファイル差分のチェックを事前実施して警告。後にshieldsetup.shを呼び出すように実装。

### 変更
#### shield-setup.sh
* bonding対応
* System component が3台構成ならantiafinity:hardを有効化
* updateを別スクリプト(shield-update.sh)からのトリガーを想定するように修正
* Dockerバージョン固定の修正
* logファイルをlogディレクトリに集約

#### shield-start.sh
* logファイルをlogディレクトリに集約

#### shield-stop.sh
* logファイルをlogディレクトリに集約
* 以前のバージョンにおける不正な common の削除を判定により削除可能なよう修正(恒久対策完了)

#### shield-nodes.sh
* logファイルをlogディレクトリに集約
* Rancher Agent追加用コマンド(command.txt)を実行時に随時更新するように変更。

#### delete-all.sh
* CentOSにおいて、rancher-store ディレクトリが削除されない問題に対応
* 各種追加スクリプトやyamlなどの削除を追加

#### getlog.sh
* 複数ログ対応
* 10000件以上の出力に対応
* TZ指定による時刻変換に対応
* ファイルへの出力対応

### 移動
#### sup へ
* getlog.sh

--------------------------------------------------------------

## [VER=20190920a] - 2019/09/20

### 追加
#### shield-restore.sh
* 特定顧客向けにリストアスクリプトを作成

--------------------------------------------------------------

## [VER=20190919b] - 2019/09/19
### 変更
#### shield-stop.sh
* 以前のバージョンにおける不正な common の削除を網羅的に実施。存在しない場合のエラーを許容。(暫定対応)

--------------------------------------------------------------

## [VER=20190919a] - 2019/09/19
### 変更
#### shield-setup.sh
* updateにおいて、moveto_projectを行うように修正。

--------------------------------------------------------------

## [VER=20190823a] - 2019/09/18
### 変更
#### shield-stop.sh
* バージョン番号付与開始? (作成当時の日付をバージョンとして設定)

--------------------------------------------------------------

## [VER=20190913a] - 2019/09/13
### 変更
#### shield-setup.sh
* バージョン番号付与開始
* クラスタ作成時にlocalClusterAuthEndpointを追加。（他C/Mにkubectlを入れて代替オペ可能)
* NWをcalicoからflannelに変更
* configure-sysctl-values.shの実行タイミング変更
* clean-rancher-agent.shおよびdelete-all.shをDLしておくように設定

--------------------------------------------------------------

## [VER=20190911a] - 2019/09/11
### 変更
#### shield-start.sh
* バージョン番号付与開始
* deploy-shield.shにおけるSHIELD_REPO変数に対応。(19.09から。ビルドは564以降)
* common 対応

--------------------------------------------------------------

## [VER=20190910a] - 2019/09/10
### 追加
#### shield-nodes.sh
* バージョン番号付与開始?

--------------------------------------------------------------

## [VER=] - 2019/09/06
### 変更
#### shield-setup.sh
* deploy-shield.shにおけるSHIELD_REPO変数に対応。(19.09から。ビルドは564以降)
* NWをcalicoからflannelに変更しようとしたができておらず。
* common 対応

