FROM ruby:2.4.2-alpine3.7

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

ENV BUNDLE_PATH /bundle
ENV BUNDLE_BIN false
ENV BUNDLE_DISABLE_SHARED_GEMS 1
ENV BUNDLE_GEMFILE /app/Gemfile
ENV BUNDLE_APP_CONFIG /bundle

RUN gem install bundler
RUN apk add --no-cache bash nodejs mysql-client sqlite mysql-dev sqlite-dev
RUN apk add --no-cache alpine-sdk \
      --virtual .build_deps libxml2-dev libxslt-dev zlib zlib-dev tzdata \
      && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
      && bundle install -j4 --without postgresql:sqlite:batch \
      && apk del alpine-sdk .build_deps \
      && rm -rf /tmp/* /var/cache/apk/*

COPY . /app
COPY Gemfile.docker /app/Gemfile

CMD /bin/sh
