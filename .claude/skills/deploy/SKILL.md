---
name: deploy
description: Deploy the application to production using Capistrano
disable-model-invocation: true
allowed-tools: Bash(bundle exec cap *), Bash(git *), Bash(npm *)
---

# Deploy to Production

portalshit.net を本番環境にデプロイする。

## 手順

1. `git status` で未コミットの変更がないか確認する
2. JS の変更がある場合は「JS ビルド」の手順を実行する
3. `git push` でリモートに push する（reject された場合は `git pull --rebase` してからリトライ）
4. `bundle exec cap production deploy` を実行する
5. デプロイ結果を確認して報告する

## JS ビルド

このリポジトリには 3 つの Node.js プロジェクトがある。
JS の変更があったプロジェクトのみビルドすればよい。

| プロジェクト | ディレクトリ | ビルドコマンド | 成果物 |
|---|---|---|---|
| admin | `public/admin` | `npm run build` | `js/` |
| theme | `public/theme/portalshit` | `npm run build` | `scripts/manifest.json` + JS |
| archives | `public/plugin/lokka-archives` | `npm run production-build` | `assets/manifest.json` + JS |

各プロジェクトで以下を実行する:

1. 該当ディレクトリで `npm run build`（lokka-archives は `npm run production-build`）を実行
2. 生成された manifest.json やビルド成果物を `git add` する
3. ビルド成果物を含めて `git commit` する

## 備考

- デプロイは現在の HEAD が自動で使われる（`config/deploy.rb` で設定済み）
- デプロイ先: `/var/www/deploys/portalshit` on `portalshit.net`
- Puma が systemctl で自動再起動される
