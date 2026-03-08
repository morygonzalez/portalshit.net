---
name: docker-build-push
description: Build the Docker image for the app service and push to Docker Hub. Use when the Dockerfile or app code has changed and the image needs to be updated.
disable-model-invocation: true
allowed-tools: Bash
---

`morygonzalez/portalshit` イメージをビルドして Docker Hub に push します。

## 手順

1. `linux/amd64` プラットフォーム向けにビルド:
   ```
   docker compose build app
   ```

2. Docker Hub に push:
   ```
   docker push morygonzalez/portalshit
   ```

## 注意点

- ビルドには MeCab neologd のインストールが含まれるため時間がかかる場合がある（初回のみ）
- キャッシュが有効な場合は差分のみビルドされるため高速
- `mecab-dict-index` は `/usr/lib/mecab/mecab-dict-index` にある（PATH 未登録）
- push 前に Docker Hub へのログインが必要な場合は `docker login` を実行すること
