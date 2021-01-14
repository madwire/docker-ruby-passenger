FROM ruby:2.5
MAINTAINER Richard Adams richard@madwire.co.uk

ENV PORT=80
ENV MIN_INSTANCES=2
ENV MAX_POOL_SIZE=6

RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -y build-essential nodejs yarn libsodium23

RUN gem install passenger && passenger-config install-standalone-runtime && passenger-config build-native-support
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ONBUILD COPY Gemfile /usr/src/app/
ONBUILD COPY Gemfile.lock /usr/src/app/
ONBUILD RUN bundle config --global frozen 1 && bundle install --jobs 4 --deployment --without development test

ONBUILD COPY . /usr/src/app
ONBUILD RUN NODE_ENV=production RAILS_ENV=production SECRET_KEY_BASE=temp bundle exec rake assets:precompile

CMD sh -c 'passenger start -p $PORT --max-pool-size $MAX_POOL_SIZE --min-instances $MIN_INSTANCES --disable-log-prefix --log-file /dev/stdout'
