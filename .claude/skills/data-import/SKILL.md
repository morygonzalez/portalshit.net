---
name: data-import
description: Import the latest database backup from S3 into the local Docker MySQL
disable-model-invocation: true
allowed-tools: Bash(bin/data_import*)
---

# Data Import

S3 上の最新バックアップをローカルの MySQL にインポートする。

## 手順

1. `bin/data_import` を実行する
2. 結果を確認して報告する

## 処理内容（`bin/data_import` の動作）

- S3 (`s3://backup.portalshit.net/database/`) から当日分の `.sql.gz` をダウンロード
- gunzip して `docker-compose run` 経由でローカル MySQL にインポート
- 古いバックアップファイルを自動削除

## 前提条件

- AWS CLI が設定済み（`--profile=personal`）
- Docker Compose でローカルの DB コンテナが起動していること
