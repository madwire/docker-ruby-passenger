FROM ruby:3.4
LABEL MAINTAINER Richard Adams richard@madwire.co.uk

ENV PORT=80
ENV MIN_INSTANCES=2
ENV MAX_POOL_SIZE=6
ENV RUBY_YJIT_ENABLE=1

RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -y build-essential nodejs yarn libsodium23 libjemalloc2 && rm -rf /var/lib/apt/lists/*

# Enable Jemalloc
RUN ln -s /usr/lib/*-linux-gnu/libjemalloc.so.2 /usr/lib/libjemalloc.so.2
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

RUN gem install passenger && passenger-config install-standalone-runtime && passenger-config build-native-support
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ONBUILD COPY Gemfile /usr/src/app/
ONBUILD COPY Gemfile.lock /usr/src/app/
ONBUILD ARG GITHUB_PKG_AUTH_TOKEN
ONBUILD RUN if [[ -z "$GITHUB_PKG_AUTH_TOKEN" ]] ; then echo 'Argument not provided' ; else bundle config set rubygems.pkg.github.com ${GITHUB_PKG_AUTH_TOKEN} ; fi
ONBUILD RUN bundle config --global frozen 1 && bundle install --jobs 4 --deployment --without development test

ONBUILD COPY . /usr/src/app
ONBUILD RUN NODE_ENV=production RAILS_ENV=production SECRET_KEY_BASE=temp bundle exec rake assets:precompile

CMD sh -c 'passenger start -p $PORT --max-pool-size $MAX_POOL_SIZE --min-instances $MIN_INSTANCES --disable-log-prefix --log-file /dev/stdout'
