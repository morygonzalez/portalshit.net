# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1: builder — ビルド専用ステージ
# ============================================================
FROM ruby:3.2.7-slim AS builder

RUN mkdir -p /app
WORKDIR /app

ENV IPADIC_VERSION=2.7.0-20070801
ENV IPADIC_URL=https://github.com/shogo82148/mecab/releases/download/v0.996.10/mecab-ipadic-${IPADIC_VERSION}.tar.gz
ENV PATH=$PATH:/root/.cargo/bin
ENV RUST_VERSION=1.93.1
ENV MECAB_PATH=/usr/lib/x86_64-linux-gnu/libmecab.so.2
ENV TZ=Asia/Tokyo

# 基本ツール & ビルド依存のインストール
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash build-essential curl git file sudo openssh-client ca-certificates \
      libssl-dev libxml2-dev libxslt1-dev zlib1g zlib1g-dev tzdata \
      default-mysql-client default-libmysqlclient-dev \
      mecab libmecab-dev mecab-ipadic-utf8 \
      gcc make pkg-config wget libffi-dev libclang-dev \
      libsqlite3-dev sqlite3 \
      imagemagick \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # Neologd の導入
    && cd /root \
    && git clone --depth 1 https://github.com/morygonzalez/mecab-ipadic-neologd.git \
    && mkdir mecab-ipadic-neologd/build \
    && curl -SL -o mecab-ipadic-neologd/build/mecab-ipadic-${IPADIC_VERSION}.tar.gz ${IPADIC_URL} \
    && mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -a -y \
    && cp /etc/mecabrc /etc/mecabrc.backup \
    && sed -i 's#^\(dicdir = .*\)/ipadic#\1/mecab-ipadic-neologd#' /etc/mecabrc \
    # SQLite 拡張をビルド
    && cd /root \
    && curl -SL -o extension-functions.c "http://www.sqlite.org/contrib/download/extension-functions.c?get=25" \
    && gcc -fPIC -shared extension-functions.c -o /usr/local/lib/libsqlitefunctions.so -lsqlite3 -lm \
    # Rust を導入
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && /root/.cargo/bin/rustup toolchain install ${RUST_VERSION} \
    && /root/.cargo/bin/rustup default ${RUST_VERSION} \
    # 掃除
    && rm -rf /var/lib/apt/lists/* /root/mecab-ipadic-neologd /root/extension-functions.c

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    PATH="/usr/local/bundle/bin:${PATH}"

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

RUN bash -lc 'gem install bundler:2.6.3 && \
              bundle config set path /usr/local/bundle && \
              bundle config set without postgresql && \
              cd /app && bundle install -j4' \
    && rm -rf /usr/local/bundle/ruby/*/gems/tantiny-*/target \
              /usr/local/bundle/ruby/*/cache

# ============================================================
# Stage 2: runtime — 実行用ステージ
# ============================================================
FROM ruby:3.2.7-slim AS runtime

ENV TZ=Asia/Tokyo
ENV MECAB_PATH=/usr/lib/x86_64-linux-gnu/libmecab.so.2
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    PATH="/usr/local/bundle/bin:${PATH}"

# ランタイムに必要なパッケージのみインストール
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libmecab2 mecab mecab-ipadic-utf8 \
      default-mysql-client libmariadb3 \
      libxml2 libxslt1.1 \
      libffi8 \
      libsqlite3-0 sqlite3 \
      imagemagick \
      zlib1g tzdata \
      libimage-exiftool-perl \
      ca-certificates \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# builder からビルド済みアーティファクトをコピー
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd /usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd
COPY --from=builder /etc/mecabrc /etc/mecabrc
COPY --from=builder /usr/local/lib/libsqlitefunctions.so /usr/local/lib/libsqlitefunctions.so

WORKDIR /app
COPY . /app
COPY Gemfile.docker /app/Gemfile
RUN mkdir -p log

ENV HOME=/app
CMD ["/bin/bash"]
