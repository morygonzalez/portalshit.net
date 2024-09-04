FROM ruby:3.3.5-alpine

RUN mkdir -p /app
WORKDIR /app

ENV MECAB_VERSION 0.996
ENV IPADIC_VERSION 2.7.0-20070801
ENV mecab_url https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE
ENV ipadic_url https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7MWVlSDBCSXZMTXM
ENV build_deps 'alpine-sdk curl git file sudo openssh'
ENV dependencies 'openssl'
ENV sqlite_version sqlite-autoconf-3230100
ENV PATH $PATH:/root/.cargo/bin
ENV RUSTFLAGS="-C target-feature=-crt-static"

RUN apk add --no-cache bash ${build_deps} \
  # Install dependencies
  && apk add --no-cache ${dependencies} \
  # Install MeCab
  && curl -SL -o mecab-${MECAB_VERSION}.tar.gz ${mecab_url} \
  && tar zxf mecab-${MECAB_VERSION}.tar.gz \
  && cd mecab-${MECAB_VERSION} \
  && ./configure --enable-utf8-only --with-charset=utf8 \
  && make \
  && make install \
  && cd \
  # Install Neologd
  && git clone --depth 1 https://github.com/shugyosha89/mecab-ipadic-neologd.git \
  && mkdir mecab-ipadic-neologd/build && curl -SL -o mecab-ipadic-neologd/build/mecab-ipadic-${IPADIC_VERSION}.tar.gz ${ipadic_url} \
  && echo 'Hash値' \
  && echo `openssl sha1 mecab-ipadic-neologd/build/mecab-ipadic-${IPADIC_VERSION}.tar.gz | cut -d $' ' -f 2,2` \
  && mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -a -y \
  && cp /usr/local/etc/mecabrc /usr/local/etc/mecabrc.backup \
  && sed -i -r 's/^(dicdir =.+?\/)ipadic/\1mecab-ipadic-neologd/' /usr/local/etc/mecabrc \
  # Install SQLite
  && curl -SLO http://www.sqlite.org/2018/${sqlite_version}.tar.gz \
  && tar xvzf ${sqlite_version}.tar.gz \
  && cd ${sqlite_version} \
  && curl -SL -o extension-functions.c http://www.sqlite.org/contrib/download/extension-functions.c?get=25 \
  && ./configure && make && make install \
  && gcc -fPIC -shared extension-functions.c -o /usr/local/lib/libsqlitefunctions.so -lm \
  && cd \
  # Install Rust
  && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
  && cd \
  # Clean up
  && rm -rf \
    mecab-${MECAB_VERSION}* \
    mecab-ipadic-${IPADIC_VERSION}* \
    mecab-ipadic-neologd \
    ${sqlite_version}*

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

RUN gem install bundler:2.1.2
RUN apk add --no-cache nodejs mysql-client mysql-dev less
RUN apk add --no-cache --virtual bundler_build_deps libxml2-dev libxslt-dev zlib zlib-dev tzdata \
  && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
  && cd /app && bundle install -j4 --without postgresql:sqlite \
  && apk del ${build_deps} bundler_build_deps \
  && rm -rf /tmp/* /var/cache/apk/*

COPY . /app
COPY Gemfile.docker /app/Gemfile

CMD /bin/bash
