# AGENTS.md

## 作業フロー

作業環境によってフローが分岐する。詳細は `.claude/rules/work-environment.md` を参照。

### ユーザーの端末内で作業する場合（基本フロー）

1. ユーザーから作業を依頼される
2. **修正方針を提示してユーザーの承認を得る**（実装前）
3. 実装する
4. **ユーザーがレビュー・動作確認をして承認する**（コミット前）
5. コミットしてデプロイする

動作確認が必要な変更（新機能・バグ修正・設定変更など）は、ユーザーの承認なしにコミット・デプロイしないこと。

### Claude が用意した仮想環境で作業する場合

ユーザーが手元で動作確認するには `git pull` が必要なため、ブランチを切って作業し、実装後にコミット・プッシュまで完了させる。プッシュ後にユーザーへレビュー・動作確認を依頼する。

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

### Gemfile.docker

- `Gemfile.docker` は `bin/docker_gemfile` が各 `Gemfile`（ルート・プラグイン・テーマ）を連結して生成するファイル。手で編集しない
- `.githooks/pre-commit` が、`Gemfile` をステージしたコミット時に自動で再生成し同じコミットに含める
- フックを有効化するにはクローンごとに一度だけ実行: `git config core.hooksPath .githooks`

## cron

- 設定ファイル: `config/crontab`
- デプロイ時にサーバーへ自動反映される
- 新規タスク追加時は `config/crontab` を編集するだけでよい

## 公開サイトのデザイン

- 公開サイト用テーマと公開プラグインの UI 実装前に `docs/design-system/README.md` と関連文書、対象画面・類似画面の既存実装を確認する。文書は現状の記録であり、詳細や例外はコードを確認する。
- 既存のコンポーネントや CSS クラスを優先して再利用し、新しい色、フォント、余白、装飾を独自に導入しない。異なる既存スタイルは勝手に統一しない。
- 新規 UI は類似画面の実装を参考にする。該当する既存パターンがなく、デザインの判断が必要な場合は勝手に決めずユーザーに確認する。
- UI 変更後は対象と既存画面を比較し、関連する画面幅、ライト・ダークモード、操作状態で視覚的な一貫性を確認する。確認できなかった範囲は報告する。
