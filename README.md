# portal shit! (source code of https://portalshit.net)

[![CircleCI](https://circleci.com/gh/morygonzalez/portalshit.net/tree/portalshit.svg?style=svg)](https://circleci.com/gh/morygonzalez/portalshit.net/tree/portalshit)

## macOSでtantinyを読み込めない場合

`mis-aligned LINKEDIT string pool` エラーが発生する場合は、デバッグ情報を残してtantinyを再ビルドする。

```sh
CARGO_PROFILE_RELEASE_DEBUG=1 CARGO_PROFILE_RELEASE_STRIP=none rbenv exec gem pristine tantiny --version 0.4.2
```

RustのmacOS向けビルドに関する問題は [rust-lang/rust#157750](https://github.com/rust-lang/rust/issues/157750) を参照。

# Copyright

Copyright (c) 2010 Masaki Komagata. See LICENSE for details.
