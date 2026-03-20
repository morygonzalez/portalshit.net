# CLAUDE.md

## 作業フロー

以下のフローを必ず守ること。

1. ユーザーから作業を依頼される
2. **修正方針を提示してユーザーの承認を得る**（実装前）
3. 実装する
4. **ユーザーがレビュー・動作確認をして承認する**（コミット前）
5. コミットしてデプロイする

動作確認が必要な変更（新機能・バグ修正・設定変更など）は、ユーザーの承認なしにコミット・デプロイしないこと。

## システム構成

- **OS**: Ubuntu (プロダクションサーバー)
- **Web サーバー**: Nginx
- **言語**: Ruby
- **フレームワーク**: Sinatra（CMS [Lokka](https://github.com/lokka/lokka) ベース）
- **ORM**: ActiveRecord
- **アプリケーションサーバー**: Puma
- **全文検索**: tantiny
- **フロントエンド**: ほとんど Sinatra + Slim だが、一部で Node.js + React を利用
    - public/plugin/lokka-archives
    - public/plugin/lokka-activity_tracker
    - public/theme/portalshit
    - public/admin

## プロジェクト構成

- `public/plugin/lokka-*` — プラグイン
- `public/theme/portalshit` — テーマ
- `bin/` — シェルスクリプト系バッチ処理
- `lib/tasks/` — rake タスク

## Docker

- イメージ: `morygonzalez/portalshit:latest`（Docker Hub）
- プロダクションでの用途:
  - **デプロイ時**: MeCab ユーザー辞書（`userdic.dic`）をイメージからコピー（`deploy:compile_userdic` タスク）
  - **cron**: 検索インデックス更新・類似記事更新などのバッチ処理（`bin/run_update_search_index` 等）
- プロダクションではホスト側の `.env`、`database.yml`、アプリコード等を `-v` でマウントして実行するため、イメージ自体にシークレットを含める必要はない
- CI（CircleCI）でもこのイメージをベースに使用

## cron

- 設定ファイル: `config/crontab`
- デプロイ時にサーバーへ自動反映される
- 新規タスク追加時は `config/crontab` を編集するだけでよい
