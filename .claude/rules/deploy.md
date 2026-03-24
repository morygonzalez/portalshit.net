デプロイは Capistrano を使用: `bundle exec cap production deploy`

- デプロイ前に必ず `git push` してから `cap production deploy`（Capistrano は GitHub から取得するため）
- ブランチは現在の HEAD が自動で使われる（`config/deploy.rb` で設定済み）
- デプロイ先: `/var/www/deploys/portalshit` on `portalshit.net`
- Puma は systemctl で自動再起動される
- `db:migrate` を本番で実行した後は Puma の手動再起動が必要: `ssh app@portalshit.net '/bin/systemctl --user restart portalshit_puma_production'`
