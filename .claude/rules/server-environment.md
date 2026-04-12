Production サーバーでアプリケーションを動かしているユーザーは `app`（ホームディレクトリ: `/var/www/app`）。

- cron の設定ファイルは `config/crontab` にある（app ユーザーの crontab として登録）
- cron 内のスクリプトパスは `$BIN=/var/www/deploys/portalshit/current/bin` を基準にしている
- デプロイ時に `config/crontab` が自動的にサーバーの crontab に登録される
- cron 追加・変更時は `config/crontab` を編集し、app ユーザーで実行されることを前提にする
