テーマ（public/theme/portalshit）の SCSS を修正した際、webpack ビルドは不要。CSS は Ruby の sassc によってビルドされる。webpack はテーマの JS バンドルのみ担当。

SCSS ファイルを編集した後に `npm run build` を実行しないこと。
