# 既存のページ構造とコンポーネント

## ページ構造と画像

- 共通構造は [`layout.haml`](../../public/theme/portalshit/layout.haml) のヘッダー、`main#content`、フッター。ヘッダーは写真を `cover`、上中央に配置し下から暗いグラデーションを重ねる。内側は幅 90%・最大 1280px・最小高 350px。サイト名は太字 3em/62px の Helvetica 系。背景画像はモードと `data-bg-*` により変わる。640px 以下は内側幅 95%・高さ 200px。根拠: [`_header.scss`](../../public/theme/portalshit/styles/layout/_header.scss)、`_theme.scss`、`_mixins.scss`。
- ヘッダーナビは Theme / About / Archives / Search、Font Awesome アイコンと半透明の明色背景。Theme は OS / light / dark のメニュー、Search はモーダル。検索モーダルはライトモードでは背景 `#212121`・文字とリンク `#e8ecef`・検索結果の hover／キーボード選択背景 `#444439`、ダークモードでは背景 `#eaeaea`・文字とリンク `#16160e`・検索結果の hover／選択背景 `rgba(93,94,73,.4)` を使う。モーダルの角は 1rem、内側の余白は上下と右が .5rem、左が .3rem。入力欄は両モードとも白背景。Theme メニューの背景は `#eaeaea` のまま。パンくずと写真の説明はヘッダー下部。フッターはデスクトップで3列、640px 以下は縦並び。具体的な構造・hover・モバイルの詳細は `layout.haml`、`_header.scss`、`_footer.scss` を参照。
- 基本画像は `max-width: 100%; height: auto`。記事本文の `figure.one-column` は中央揃え、`two-column` / `three-column` は画像最大幅を各々 `100% / 2 - .3rem` / `100% / 3 - .3rem` にする。640px 以下では、`one-column`、`two-column`、`three-column` のいずれも付いていない figure 直下の img が画面幅まで広がる（画像の数はセレクターで判定していない）が、キャプションは本文幅に残る。1422px 以上では記事の `.large` 画像等が本文カラムから 1280px 幅にはみ出す。iframe の Google Maps、Slideshare、YouTube はコンテナごとに縦横比が異なる。根拠: `_base.scss`、`_content.scss`。

## 画面ごとの繰り返しパターン

| パターン | 現在の表現と根拠 |
| --- | --- |
| 新着・カテゴリー等の記事 | 特集記事 `.new-entry` と `.past-entries` を区別。後者は通常3列、1279px 以下2列、640px 以下1列。タイトル、日付、画像、要約、タグ、コメントを配置。画像半径 5px。特集記事の `picture img` は最大高 1000px、元画像なしの既定画像は別扱い。小画面の通常記事は画像と要約が横並び。 [`_entry_cards.scss`](../../public/theme/portalshit/styles/components/_entry_cards.scss)、[`_entry_cards_featured.haml`](../../public/theme/portalshit/_entry_cards_featured.haml)、[`_entry_cards_item.haml`](../../public/theme/portalshit/_entry_cards_item.haml) |
| 人気・関連記事など | `.entries-list` は通常2列、640px 以下1列。タイトルと日付、画像と要約の組。画像は通常150px、1279px 以下100px、半径5px。記事カードとは別実装。[`_entries-list.scss`](../../public/theme/portalshit/styles/components/_entries-list.scss)、`_mixins.scss`、[`_entry_list_item.haml`](../../public/theme/portalshit/_entry_list_item.haml) |
| カテゴリーカード | 2列、640px 以下1列、gap 1rem、padding 1rem、薄い境界と背景、半径5px。画像は90px正方形・`object-fit: cover`。 [`_content.scss`](../../public/theme/portalshit/styles/layout/_content.scss)、[`_category_cards.haml`](../../public/theme/portalshit/_category_cards.haml) |
| OGPカード | 最大幅800px・高さ202px、画像200px正方形で cover、明色背景 `#fffffc`、境界 `#8b968d`、半径5px。hover は暗色背景。414px 以下は高さ122px・画像120px、説明は2行に制限。[`_ogp.scss`](../../public/theme/portalshit/styles/components/_ogp.scss) |
| コメント | 最大幅780px、メタ情報30%・本文70%。フォームは最大500px、暗い入力背景、可視性選択は枠付きラベル、送信ボタンは選択状態に応じて表示。640px 以下でフォーム幅や入力サイズが変わる。[`_comments.scss`](../../public/theme/portalshit/styles/components/_comments.scss)、[`comment.haml`](../../public/theme/portalshit/comment.haml) |
| Archives | 年・カテゴリー・検索・件数フィルターと月別一覧、ヒートマップ。検索は白背景・高さ40px・半径4px。640px 以下ではフィルターを折り返す。[`_archive.scss`](../../public/theme/portalshit/styles/components/_archive.scss)、[`lokka-archives/src`](../../public/plugin/lokka-archives/src) |
| Activity | 統計グリッド、グラフ、横スクロール可能な表。指標選択ボタンは透明背景・丸い枠、active と hover に別指定。距離等のスライダーには青 `#3b82f6` がある。これは通常リンク色とは別の局所的なスタイル。[`_activity.scss`](../../public/theme/portalshit/styles/components/_activity.scss)、[`lokka-activity_tracker/src`](../../public/plugin/lokka-activity_tracker/src) |
| チャット | サイト右下の起動ボタンとチャット UI は専用実装。色・サイズ・状態は [`_dify_chat.scss`](../../public/theme/portalshit/styles/components/_dify_chat.scss) と [`src/chat`](../../public/theme/portalshit/src/chat) を参照。一般的なボタンの規格として扱わない。 |

他にも Amazon、PhotoSwipe、コード表示などは [`styles/components`](../../public/theme/portalshit/styles/components) に個別指定がある。ボタン、カード、余白、文字サイズに単一の全サイト共通規格があるかは不明。外部ライブラリや埋め込み先の描画、管理画面・別テーマ、上記以外の状態は個別に調査する。
