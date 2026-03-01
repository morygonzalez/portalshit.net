# syntax=docker/dockerfile:1.7
FROM ruby:3.2.7-slim

RUN mkdir -p /app
WORKDIR /app

ENV IPADIC_VERSION=2.7.0-20070801
ENV IPADIC_URL=https://github.com/shogo82148/mecab/releases/download/v0.996.10/mecab-ipadic-${IPADIC_VERSION}.tar.gz
ENV PATH=$PATH:/root/.cargo/bin
ENV CARGO=/root/.cargo/bin/cargo \
    CARGO_TARGET_DIR=/root/target \
    CARGO_TERM_COLOR=always
ENV RUST_VERSION=1.93.1
# Debian の MeCab 共有ライブラリの一般的なパス（必要なら後で上書き可）
ENV MECAB_PATH=/usr/lib/x86_64-linux-gnu/libmecab.so.2
ENV TZ=Asia/Tokyo

# 基本ツール & ビルド依存のインストール（APT キャッシュを BuildKit で再利用）
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash build-essential curl git file sudo openssh-client ca-certificates \
      libssl-dev libxml2-dev libxslt1-dev zlib1g zlib1g-dev tzdata \
      nodejs default-mysql-client default-libmysqlclient-dev less \
      mecab libmecab-dev mecab-ipadic-utf8 \
      gcc make pkg-config wget libffi-dev libclang-dev \
      libsqlite3-dev sqlite3 \
      imagemagick \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # Neologd の導入（従来と同じ。公式 ipadic を置換）
    && cd /root \
    && git clone --depth 1 https://github.com/morygonzalez/mecab-ipadic-neologd.git \
    && mkdir mecab-ipadic-neologd/build \
    && curl -SL -o mecab-ipadic-neologd/build/mecab-ipadic-${IPADIC_VERSION}.tar.gz ${IPADIC_URL} \
    && mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -a -y \
    && cp /etc/mecabrc /etc/mecabrc.backup \
    && sed -i 's#^\(dicdir = .*\)/ipadic#\1/mecab-ipadic-neologd#' /etc/mecabrc \
    # SQLite 拡張だけをビルド（本体はシステムの libsqlite3 を使用）
    && cd /root \
    && curl -SL -o extension-functions.c "http://www.sqlite.org/contrib/download/extension-functions.c?get=25" \
    && gcc -fPIC -shared extension-functions.c -o /usr/local/lib/libsqlitefunctions.so -lsqlite3 -lm \
    # Rust 1.80.1 を導入 & 既定化
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && /root/.cargo/bin/rustup toolchain install ${RUST_VERSION} \
    && /root/.cargo/bin/rustup default ${RUST_VERSION} \
    # sccache: Rustビルドキャッシュ
    && curl -fsSL https://github.com/mozilla/sccache/releases/download/v0.7.5/sccache-v0.7.5-x86_64-unknown-linux-musl.tar.gz -o /tmp/sccache.tgz \
    && tar -xzf /tmp/sccache.tgz -C /tmp \
    && install -m0755 /tmp/sccache-*/sccache /usr/local/bin/sccache \
    && rm -rf /tmp/sccache* \
    # 掃除
    && rm -rf /var/lib/apt/lists/* /root/mecab-ipadic-neologd /root/extension-functions.c

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    PATH="/usr/local/bundle/bin:${PATH}"

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

RUN bash -lc 'gem install bundler:2.6.3 && \
              bundle config set path /usr/local/bundle && \
              bundle config set without postgresql:sqlite && \
              export RUSTC_WRAPPER=/usr/local/bin/sccache && \
              export SCCACHE_DIR=/root/.cache/sccache && \
              export SCCACHE_CACHE_SIZE=10G && \
              cd /app && bundle install -j4'

COPY . /app
COPY Gemfile.docker /app/Gemfile
RUN mkdir -p log

ENV HOME=/app
CMD ["/bin/bash"]
