# Atom フィードの Cloudflare キャッシュ

対象は `https://portalshit.net/index.atom`。クエリなしの公開フィードを Cloudflare で最大1時間キャッシュする。クライアントには `max-age=0` を返し、既存の弱い ETag で再検証できるようにする。クエリ付きのリクエスト（`?page=2` など）と、Cookie または Authorization を持つリクエストは共有キャッシュを経由させない。

## API トークン

Cloudflare でカスタム API トークンを作成する。権限は **Zone → Cache Purge → Purge**、対象リソースは **portalshit.net** ゾーンに限定する。ゾーンの Overview で Zone ID を確認する。

本番の共有 `.env` に `CLOUDFLARE_ZONE_ID` と `CLOUDFLARE_API_TOKEN` を設定し、Puma が起動時に読み込むようにする。片方でも空ならパージ処理は無効になり、公開記事の変更をコミットした後に直接 PubSubHubbub に通知する。

[Cloudflare の API トークン作成手順](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)

## Cache Rules

**Caching → Cache Rules** で次の Expression を使う。Cloudflare の DNS プロキシを有効にし、オリジンとの接続には HTTPS（Full (strict)）を使う。

```text
(http.request.full_uri eq "https://portalshit.net/index.atom"
 and raw.http.request.uri eq "/index.atom"
 and not http.request.headers.truncated
 and not any(lower(http.request.headers.names[*])[*] in {
   "cookie" "authorization" "origin"
   "x-http-method-override" "x-http-method" "x-method-override"
   "x-forwarded-host" "x-host" "x-forwarded-scheme"
   "x-original-url" "x-rewrite-url" "forwarded"
 }))
```

- **Cache eligibility** を **Eligible for cache** にする。
- **Edge TTL** はオリジンの `Cache-Control` に従う設定にする。ヘッダーがないときはバイパスする選択肢を使う。Enterprise で Origin Cache Control を変更している場合は、このルールで有効にする。
- **Browser TTL** は **Respect origin** にする。
- 既定のキャッシュキーを使う。デバイス、国、言語、ヘッダーなどによるキーの追加設定は適用しない。

正規化の前後を確認する条件とクエリを含まない URL の完全一致で、別表記やページ番号ごとのキャッシュを避ける。既定キーを分ける `Origin` などのヘッダーも除外する。パージ時のリクエストにもルールを適用できるよう、メソッドで絞り込まない。

既存の Cache Rules、Page Rules、URL Rewrite Rules も確認し、Atom のパスに URL 書き換え、カスタムキー、TTL の上書きが適用されないようにする。既存の広いキャッシュルールが Atom も対象にする場合は、Atom のパスをそのルールから除外する。

[Cache Rules の設定項目](https://developers.cloudflare.com/cache/how-to/cache-rules/settings/) · [既定のキャッシュキー](https://developers.cloudflare.com/cache/how-to/cache-keys/) · [URL 単位パージの制約](https://developers.cloudflare.com/cache/how-to/purge-cache/purge-by-single-file/)

## 切り替えと確認

1. 現行の Nginx 設定を退避する。Cloudflare の Atom 用ルールは下書きにしておく。
2. 本番の共有 `.env` を設定し、アプリをデプロイして Puma を再起動する。
3. HTTPS の `location = /index.atom` を [Nginx 設定例](../config/nginx-atom.conf.example) に置き換え、Atom 更新用の `127.0.0.1:18081` リスナーを削除する。`nginx -t` の成功後にリロードする。この間に記事を更新した場合は、切り替え後に下記の手動復旧を行う。
4. オリジンサーバー上から、HTTPS リスナーに直接アクセスして最新の XML、`Cache-Control: public, max-age=0, s-maxage=3600`、ETag を確認する。以下は HTTPS リスナーがループバックから到達できる場合の例。
   ```sh
   curl -fsS -D - --resolve portalshit.net:443:127.0.0.1 https://portalshit.net/index.atom
   ```
5. Cloudflare の Atom ルールを有効にする。過去の Atom 設定で残ったキャッシュがあれば、対象 URL をパージする。同じ接続元から Cookie なしで GET を繰り返し、ヘッダーと XML を確認する。初回の `MISS` に続き `HIT` と `Age` が返ることを確認する。
   ```sh
   curl -fsS -D - -o /dev/null https://portalshit.net/index.atom
   ```
6. `?page=2`、Cookie 付き、Authorization 付き、`Origin` 付きのアクセスで `HIT` が返らないことを確認する。クエリなしの GET で取得した ETag を `If-None-Match` に指定し、変更前のフィードが 304 を返すことも確認する。
7. 公開記事を編集して保存し、同じ公開 URL で新しい内容と ETag が返ることを確認する。ハブが先に取得すると、確認時点ですでに `HIT` になる場合がある。Puma のエラーログ（`log/puma_error.log`）に `Cloudflare Atom cache purge failed` や `PubSubHubbub Atom notification failed` が出ていないことを確認し、通知を受け取れる購読先で更新を確認する。フィード取得ログを使える場合はハブからの取得も照合する。

## 手動復旧

保存と外部通信は DB コミットを境に分かれている。パージまたは通知が失敗しても保存は完了する。パージが失敗するとその回の通知は保留となり、自動再試行は行われない。Cloudflare のキャッシュは通常 TTL で失効するが、失効しても保留した通知は送られない。

1. Puma のエラーログで失敗した処理を確認し、トークンの権限、ゾーン ID、サービスの応答を確認する。
2. Cloudflare の **Caching → Configuration → Purge Cache → Custom Purge** から `https://portalshit.net/index.atom` を URL 指定でパージする。
3. 公開 URL を GET し、最新の内容を確認してからハブに通知する。
   ```sh
   curl -fsS --connect-timeout 2 --max-time 10 \
     --data-urlencode 'hub.mode=publish' \
     --data-urlencode 'hub.url=https://portalshit.net/index.atom' \
     https://pubsubhubbub.appspot.com/
   ```

サイト名や著者名の変更、記事のコールバックを経由しない一括更新をすぐ反映させたい場合も同じ手順を使う。

## ロールバック

1. Cloudflare の Atom 用ルールを無効にし、対象 URL をパージする。公開 URL が共有キャッシュから配信されなくなったことを確認する。
2. Cloudflare 連携だけ止める場合は、共有 `.env` から両方の変数を削除して Puma を再起動する。
3. アプリも以前の版に戻す場合は、以前のアプリが必要とする Atom 用 Nginx キャッシュとループバックリスナーを退避した設定から復元する。`nginx -t` とリロード後、旧版をデプロイする。オリジンのフィードが最新になることと、更新後に購読先に通知が届くことを確認する。
