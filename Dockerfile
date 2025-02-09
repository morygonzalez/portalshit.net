FROM ruby:3.1.6-alpine

RUN mkdir -p /app
WORKDIR /app

ENV MECAB_VERSION=0.996.10
ENV IPADIC_VERSION=2.7.0-20070801
ENV mecab_url=https://github.com/shogo82148/mecab/releases/download/v${MECAB_VERSION}/mecab-${MECAB_VERSION}.tar.gz
ENV ipadic_url=https://github.com/shogo82148/mecab/releases/download/v${MECAB_VERSION}/mecab-ipadic-${IPADIC_VERSION}.tar.gz
ENV build_deps='alpine-sdk curl git file sudo openssh'
ENV dependencies='openssl'
ENV sqlite_version=sqlite-autoconf-3230100
ENV PATH=$PATH:/root/.cargo/bin
ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV RUST_VERSION=1.77
ENV MECAB_PATH=/usr/local/lib/libmecab.so

# Install dependencies
RUN apk add --no-cache bash ${build_deps} \
  && apk add --no-cache ${dependencies} \
# Install MeCab
  && mkdir -p mecab \
  && cd mecab \
  && curl -SL -o mecab-${MECAB_VERSION}.tar.gz ${mecab_url} \
  && tar zxf mecab-${MECAB_VERSION}.tar.gz \
  && cd mecab-${MECAB_VERSION} \
  && ./configure --enable-utf8-only --with-charset=utf8 \
  && make \
  && make install \
# Install Neologd
  && cd \
  && git clone --depth 1 https://github.com/morygonzalez/mecab-ipadic-neologd.git \
  && mkdir mecab-ipadic-neologd/build && curl -SL -o mecab-ipadic-neologd/build/mecab-ipadic-${IPADIC_VERSION}.tar.gz ${ipadic_url} \
  && mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -a -y \
  && cp /usr/local/etc/mecabrc /usr/local/etc/mecabrc.backup \
  && sed -i -r 's/^(dicdir =.+?\/)ipadic/\1mecab-ipadic-neologd/' /usr/local/etc/mecabrc \
# Install SQLite
  && cd \
  && curl -SLO http://www.sqlite.org/2018/${sqlite_version}.tar.gz \
  && tar xvzf ${sqlite_version}.tar.gz \
  && cd ${sqlite_version} \
  && curl -SL -o extension-functions.c http://www.sqlite.org/contrib/download/extension-functions.c?get=25 \
  && ./configure && make && make install \
  && gcc -fPIC -shared extension-functions.c -o /usr/local/lib/libsqlitefunctions.so -lm \
# Install Rust
  && cd \
  && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
  && rustup toolchain add ${RUST_VERSION} \
  && rustup default ${RUST_VERSION} \
# Clean up
  && cd \
  && rm -rf \
    mecab \
    mecab-ipadic-neologd \
    ${sqlite_version}*

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

RUN gem install bundler:2.6.3
RUN apk add --no-cache nodejs mysql-client mysql-dev less
RUN apk add --no-cache --virtual bundler_build_deps libxml2-dev libxslt-dev zlib zlib-dev tzdata \
  && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
  && cd /app && bundle install -j4 --without postgresql:sqlite \
  && apk del ${build_deps} bundler_build_deps \
  && rm -rf /tmp/* /var/cache/apk/*

COPY . /app
COPY Gemfile.docker /app/Gemfile
RUN mkdir -p log

ENV HOME=/app
CMD ["/bin/bash"]
