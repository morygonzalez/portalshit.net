#!/bin/bash
set -e

if [ ! -f /app/lib/tokenizer/userdic.dic ]; then
  echo "Generating userdic.dic..."
  /usr/lib/mecab/mecab-dict-index \
    -d /usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd \
    -u /app/lib/tokenizer/userdic.dic \
    -f utf-8 -t utf-8 \
    /app/lib/tokenizer/userdic.csv
  echo "Done."
fi

exec "$@"
