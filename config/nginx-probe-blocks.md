# portalshit.net の探索リクエスト遮断

`nginx-probe-blocks.conf.example` は、portalshit.net の HTTPS の
`server` に置いていた User-Agent、パス、クエリの遮断ルールをまとめた
スニペット。サイトで使っていないことを確認した探索パスを末尾に追加している。

## 本番反映

1. `/etc/nginx/sites-available/portalshit.conf` を退避する。
2. `nginx-probe-blocks.conf.example` を
   `/etc/nginx/snippets/portalshit-probe-blocks.conf` に root 所有で配置する。
3. `portalshit.net` の HTTPS `server` で、旧RSSのリダイレクト直後にある
   `# Block malicious/scanner requests` の区切りから、スクリプト拡張子を
   404 にする最後の `location` までを、次の1行に置き換える。
   `location ~* ^/log-aggregation/.*\.txt$` はその直後に残す。

   ```nginx
   include /etc/nginx/snippets/portalshit-probe-blocks.conf;
   ```

   正規表現の `location` は記述順に評価されるため、この位置で読み込む。
   `http` コンテキストの `$banned_ua` の定義と、プロキシ先ごとの
   `limit_req`・`limit_conn` は、それぞれの設定箇所に置く。

4. `sudo nginx -t` に成功したら `sudo systemctl reload nginx` を実行する。
5. 代表的な探索パスが404になり、アクセスログの `upstream_response_time` が
   `-` であることを確認する。公開記事、Atom、正規のAPI、旧RSSの301も確認する。
   Cloudflareのキャッシュを経由せず確認する場合は、オリジンサーバーから
   `curl --resolve portalshit.net:443:127.0.0.1` でHTTPSリスナーに接続する。

ロールバックは、退避した `portalshit.conf` を元の位置に戻し、
`sudo nginx -t` の成功後にリロードする。
