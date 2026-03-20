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
2. `git push` でリモートに push する（reject された場合は `git pull --rebase` してからリトライ）
3. `bundle exec cap production deploy` を実行する
4. デプロイ結果を確認して報告する

## 備考

- デプロイは現在の HEAD が自動で使われる（`config/deploy.rb` で設定済み）
- デプロイ先: `/var/www/deploys/portalshit` on `portalshit.net`
- Puma が systemctl で自動再起動される
