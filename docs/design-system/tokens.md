# 既存の色・文字・余白

値は適用箇所とカスケードに依存する。詳しくは参照先の実装を確認する。

## 基本と配色

- 読み込み順は [`style.scss`](../../public/theme/portalshit/style.scss)。変数は [`_variables.scss`](../../public/theme/portalshit/styles/_variables.scss)、基本要素は [`_base.scss`](../../public/theme/portalshit/styles/_base.scss)、モード別の上書きは [`_theme.scss`](../../public/theme/portalshit/styles/_theme.scss)。
- `html.light-mode` / `html.dark-mode` の明示指定と、指定がない場合の `prefers-color-scheme` に対応する。切替と cookie は [`theme-observer.js`](../../public/theme/portalshit/src/theme-observer.js)、条件の詳細は [`_mixins.scss`](../../public/theme/portalshit/styles/_mixins.scss)。両モードを別々に扱う。
- ライトモードの `body` は背景 `#fff`、文字 `#000`、`#content` 背景 `#e8ecef`。ダークモードは黒の背景上に固定写真、文字 `#e8ecef`、本文領域の基本背景 `rgba(33,33,33,.85)`。ダーク側には限定した領域に文字シャドウがある。
- 通常リンクは両モードとも未訪問 `#a60000`、訪問済み `#a3a3a2`、hover `#f60`。ただしライトの本文など特定領域では hover `#e6b422`。下線は基本的に付かない。記事タイトル、ナビ、フッター、OGP には別指定がある。変数 `$light-link-color: #ce5242` は通常リンクの実際の指定とは異なり、タイトルの装飾などに使われる。
- フッターは `#630101` に赤系グラデーション、リンク `#eaeaea`、hover `#f60`。補助情報の基本色は `#595857`。これらは用途を伴う既存値であり、全画面共通の配色パレットではない。根拠: [`_footer.scss`](../../public/theme/portalshit/styles/layout/_footer.scss)、`_theme.scss`、`_mixins.scss`。

## 文字と余白

- `body` は 18px / 26px、640px 以下で 15px。フォントはメイリオ、Lucida Sans Unicode、Lucida Grande、Arial、Helvetica、ヒラギノ系などのフォールバック列。見出し `h2`〜`h5` と `aside dt` は `"Lucida Grande", Lucida, Verdana, sans-serif`。実際の日本語フォントは端末依存。
- 基本の `h2` は 1.45em、太字、行高 115%、下余白 .6em。`#content` 直下の section 等の `h2` は下余白 1.5em。記事本文では `h2` 1.12em・前に ♣、`h3` 1.06em・前に ♦、`h4` 1em。記事タイトルは 1.2em、リンクの背後に大きな `•` を置き、リンクの状態とモードで色が変わる。メタ情報は基本 .8em、本文は最大幅 780px・行高 180%。
- 段落は `margin: 1.5em 0`。`#content` は幅 90%、最大 1280px、padding `20px 30px`。直下の section/article/aside は `margin: 1rem .5rem 4rem`、最後は下 2rem。640px 以下は本文領域幅 100%、padding `.5em 0`。これらは全 UI 共通の余白スケールではない。根拠: `_base.scss`、[`_content.scss`](../../public/theme/portalshit/styles/layout/_content.scss)、`_mixins.scss`。
- インラインコードは Menlo、Consolas、Courier 系、.9em。段落・リスト中は背景 `#212121`、文字 `#b5b2b2`、境界 `#333`、半径 5px。`pre` は .8em・暗い背景で横スクロール。クラスなし引用は暗い背景と引用符、半径 5px。表は交互の半透明グレー、白い境界線。詳細は `_base.scss` と [`_code.scss`](../../public/theme/portalshit/styles/components/_code.scss)。
