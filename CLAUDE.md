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

## プロジェクト構成

- `public/plugin/lokka-*` — プラグイン
- `public/theme/portalshit` — テーマ
- `bin/` — シェルスクリプト系バッチ処理
- `lib/tasks/` — rake タスク

## cron

- 設定ファイル: `config/crontab`
- デプロイ時にサーバーへ自動反映される
- 新規タスク追加時は `config/crontab` を編集するだけでよい
