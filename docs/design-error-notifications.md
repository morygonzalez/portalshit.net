# 500エラー通知機能 設計ドキュメント

## 概要

NGINX の LTSV アクセスログを監視し、`status:500` のリクエストを検知した場合にメールで通知する。

## 方針

既存の `bin/` 配下のログ集約スクリプト群と同じアプローチ（シェルスクリプト + cron）で実装する。メール送信には AWS CLI の `ses send-email` を使う。

### 既存スクリプトとの整合性

| 項目 | 既存スクリプト | 本機能 |
|------|---------------|--------|
| 言語 | Bash + awk | Bash + awk |
| 共通ライブラリ | `bin/lib/common.sh` | 同左を利用 |
| データ整形 | `bin/lib/*.awk` | `bin/lib/format_error_lines.awk` |
| ログ読み込み | `find + zcat -f` | ポジションファイル + `dd` で差分のみ |
| 実行方法 | 手動 or cron | cron（5分間隔） |

## アーキテクチャ

```
cron (5分間隔)
  └─ bin/notify_errors（Bash: ログ解析・メール送信）
       ├─ source bin/lib/common.sh （共通定数の利用）
       ├─ ポジションファイルでログの差分を読み取り
       ├─ status:5xx を grep で抽出
       ├─ bin/lib/format_error_lines.awk（awk: LTSV パース・メール本文整形）
       └─ aws sesv2 send-email で通知
```

**役割分担:**
- **Bash（`bin/notify_errors`）**: ポジション管理、ログ差分読み取り、エラー行の grep 抽出、メール送信
- **awk（`bin/lib/format_error_lines.awk`）**: LTSV フィールドのパース、メール本文の組み立て・整形

## 詳細設計

### 1. スクリプト: `bin/notify_errors`

```bash
#!/bin/bash
source "$(dirname "$0")/lib/common.sh"

POSITION_FILE="${LOG_DIR}/.notify_errors_position"
ACCESS_LOG="${LOG_DIR}/access.log"
NOTIFY_TO="通知先メールアドレス（設定ファイルから読み込み）"
NOTIFY_FROM="portal shit! <info@portalshit.net>"
```

### 2. ログ読み取り方式: ポジションファイル方式

前回読み取った位置（バイトオフセット）を記録し、差分のみを処理する。

```
1. POSITION_FILE から前回のオフセットを読み込む（初回は0）
2. access.log の現在のファイルサイズを取得
3. 前回オフセット〜現在サイズの差分を dd で読み取る
4. 処理後、現在のファイルサイズを POSITION_FILE に記録
```

**ログローテーション対応:**
- 現在のファイルサイズが前回オフセットより小さい場合はローテーションが発生したと判断し、オフセットを 0 にリセットして最初から読む

### 3. 500 エラーの抽出

```bash
# 差分ログから status:500 の行を抽出
# 静的ファイル（css, js, 画像等）は除外
echo "$new_lines" \
  | grep -P '\tstatus:500\t' \
  | grep -vP 'request_uri:\S+\.(css|js|png|jpe?g|gif|svg|ico|woff2?|ttf|eot|map)(\?|\t)'
```

### 4. メール送信: AWS CLI (`aws sesv2 send-email`)

既存の `CommentNotifier` は Ruby（`Aws::SESV2::Client`）だが、本機能はシェルスクリプトなので AWS CLI を使う。サーバーには既に AWS CLI がインストールされている（`bin/log_backup` で `aws s3 cp` を使用済み）。

```bash
aws sesv2 send-email \
  --from-email-address "$NOTIFY_FROM" \
  --destination "ToAddresses=$NOTIFY_TO" \
  --content "Simple={
    Subject={Data='[portalshit] 500エラーが発生しました'},
    Body={Text={Data='$body'}}
  }"
```

**認証:** サーバーの IAM ロールまたは `~/.aws/credentials` を利用（`log_backup` と同じ方式）。

### 5. メール本文の整形: awk (`bin/lib/format_error_lines.awk`)

既存の `bin/lib/nginx_request_time_daily.awk` 等と同じパターンで、LTSV のパースと整形を awk に委譲する。
`notify_errors` からは `echo "$error_lines" | gawk -v max_errors=50 -f format_error_lines.awk` のようにパイプで呼び出す。

**awk が行うこと:**
- `FS="\t"` で LTSV をタブ分割
- `time:`, `request_method:`, `request_uri:`, `status:`, `remote_addr:`, `request_time:` フィールドを抽出
- `max_errors` 変数で表示件数を制御し、超過分は省略表示

**出力例:**

```
[portalshit.net] サーバーエラー通知

以下のリクエストでサーバーエラーが発生しました。

---
発生時刻: 2026-03-10T12:34:56+09:00
リクエスト: GET /some/path
ステータス: 500
リモートアドレス: 203.0.113.1
レスポンスタイム: 1.234s
---

合計: 3件
```

### 6. 重複通知の防止

- ポジションファイルでログの読み取り位置を管理するため、同じログ行が2回処理されることはない
- cron 実行間隔（5分）内に発生した500エラーをまとめて1通のメールで通知する（メール爆発を防ぐ）

### 7. cron 設定

```cron
*/5 * * * * /var/www/app/portalshit/bin/notify_errors 2>> /var/www/app/portalshit/log/notify_errors.log
```

### 8. 設定ファイル: `bin/conf/notify_errors.conf`

```bash
# 通知先メールアドレス（カンマ区切りで複数指定可）
NOTIFY_TO="admin@example.com"

# 通知元メールアドレス
NOTIFY_FROM="portal shit! <info@portalshit.net>"

# 通知対象のステータスコード（将来的に502, 503等も追加可能）
NOTIFY_STATUS_CODES="500"
```

## ファイル構成

```
bin/
├── notify_errors              # メインスクリプト（新規）
├── conf/
│   └── notify_errors.conf     # 設定ファイル（新規）
└── lib/
    ├── common.sh              # 既存（変更なし）
    └── format_error_lines.awk # LTSV パース・メール本文整形（新規）
```

## 考慮事項

### エラーが大量発生した場合

5分間に大量の500エラーが発生した場合でも1通のメールにまとめるため、メール通知のスパム化は起きない。ただし、メール本文が非常に長くなる可能性があるため、一定件数（例: 50件）を超えた場合は先頭のみ表示し「他 N 件」と省略する。

### ログローテーション

NGINX のログローテーション（`logrotate`）によりファイルが切り替わった場合、ファイルサイズがポジションより小さくなることで検知し、オフセットをリセットする。`copytruncate` 方式のローテーションにも対応。

### AWS SES のリージョン

`CommentNotifier` と同じ `us-east-1` を使用する。

### テスト方法

```bash
# ドライラン（メール送信せずに抽出結果を表示）
bin/notify_errors --dry-run

# 手動でテスト送信
bin/notify_errors --test
```
