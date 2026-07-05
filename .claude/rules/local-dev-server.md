ローカル開発環境は Docker Compose で構成されている（`docker-compose.yml`）。

- `app` サービス: `morygonzalez/portalshit` イメージ、`bundle exec puma` で起動。カレントディレクトリを `/app` にボリュームマウントしているため、コード変更はコンテナ再起動なしでも反映される（Sinatra はリクエストごとにコードを再評価するため）
- `db` サービス: MySQL

## I18n の翻訳ファイルは再起動が必要

`i18n/*.yml`（および各プラグインの `i18n/*.yml`、テーマの `i18n/*.yml`）は Puma プロセス起動時に一度だけ読み込まれ、`I18n::Backend::Simple` にキャッシュされる。そのため、翻訳ファイルを編集しても **Puma プロセスを再起動するまで新しいキーが反映されず「translation missing」になる**。

翻訳ファイル（`i18n/ja.yml`, `i18n/en.yml`, `public/plugin/lokka-*/i18n/*.yml` など）を編集したら、以下でアプリコンテナを再起動する:

```
docker compose restart app
```

再起動後、起動確認:

```
docker compose ps
```

`translation missing` の確認例:

```
curl -s -H "Accept-Language: ja" http://localhost:3000/ | grep -o "translation missing[^<]*"
```

何も出力されなければ翻訳漏れなし。
