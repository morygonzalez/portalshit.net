# CLAUDE.md

## Deploy

```
bundle exec cap production deploy
```

## JS changes

npm で管理している JS コードを変更した場合は、コミット前に以下を実行して manifest.json も一緒にコミットすること。

```
npm run production-build
```
