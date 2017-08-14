FROM ruby:2.3-alpine

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile.docker /app/Gemfile
COPY Gemfile.lock /app/

RUN gem install bundler
RUN apk add --no-cache bash nodejs mysql-client sqlite mysql-dev sqlite-dev
RUN apk add --no-cache alpine-sdk \
      --virtual .build_deps libxml2-dev libxslt-dev zlib zlib-dev \
      && bundle install -j4 --without postgresql \
      && apk del alpine-sdk .build_deps \
      && rm -rf /tmp/* /var/cache/apk/*

COPY . /app

CMD /bin/sh
