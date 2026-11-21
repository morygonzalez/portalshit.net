# Cloudflare プロキシへの移行

サイトと管理画面・チャット API・imageproxy を確認できる時間帯に作業する。
Cloudflare の設定を確認するまでは、既存の IP 単位の制限を本番から外さない。
Cloudflare Free のレート制限ルール数には限りがあり、チャットと通常ページの
制限を現在と同じ条件で再現できるとは限らない。

## 本番 Nginx の変更

Cloudflare 側の防御設定と、直接アクセスの扱いを決めた後に適用する。
実際のファイルをバックアップし、内容を確認してから次を編集する。

- `/etc/nginx/sites-available/portalshit.conf` の `if ($blocked_ips) { return 444; }` を削除する。
- 同ファイルの `limit_req zone=puma_flood`、`limit_req zone=chat_messages`、
  `limit_req zone=chat_api`、`limit_conn chat_conn` の行を削除する。
- `limit_conn chat_conn_global 4;` と `limit_req zone=crawler_rate_limit` は残す。
  不審なパスや User-Agent の遮断と既存の proxy 設定も残す。
- `/etc/nginx/conf.d/puma_rate_limit.conf` の `puma_flood` の定義を削除する。
- `/etc/nginx/conf.d/chat-rate-limit.conf` の `chat_api`、`chat_messages`、
  `chat_conn` の定義を削除し、`chat_conn_global` と `limit_conn_status` を残す。
- `/etc/nginx/conf.d/nginx-abuse-block.conf` の `$blocked_ips` 定義を削除する。
  他に利用している server がないことを事前に確認する。
- `sudo nginx -t` に成功したら `sudo systemctl reload nginx` を実行する。
  失敗した場合はバックアップを戻し、再度テストする。

デプロイ前に現行 cron の `update_abuse_blocks` を無効化する。新しいリリースの
`config/crontab` は同ジョブを含まない。既存の `/etc/nginx/blocked_ips.conf` や
共有ディレクトリの履歴、公開済み集計ファイルは自動削除されない。必要に応じて
バックアップ・保管方針を決めた上で別途整理する。

## 検証

- Cloudflare の DNS レコード・TLS、オリジンへの直接アクセスの扱いを確認する。
- 記事、管理画面、Atom、imageproxy、チャットのストリーミングを確認する。
- 通常ページとチャットの制限が期待どおりに働くこと、正常な利用が遮断されないことを確認する。
- CDN のキャッシュや遮断により、Nginx のログ集計には届かないリクエストがある。
  IP 復元を設定しない場合、残るアクセスログの IP は Cloudflare 側の IP になる。
