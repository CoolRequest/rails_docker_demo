FROM ruby:2.7.4-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
              ca-certificates \
		      curl \
              git \
              openssh-client \
              build-essential \
              libc6 \
              gnupg \
              shared-mime-info && \
    rm -rf /var/lib/apt/lists/*

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# install yarn
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
#     echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#     apt-get update && \
#     apt-get install -y --no-install-recommends yarn && \
#     rm -rf /var/lib/apt/lists/*
RUN npm install --global yarn

RUN gem install bundler

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app
WORKDIR /app
COPY . /app

RUN bundle config set --local deployment 'true'
RUN bundle config set --local without 'development test'
RUN bundle install -j5

RUN yarn

RUN bundle exec rake assets:precompile DB_ADAPTER=nulldb NODE_ENV=development RAILS_ENV=staging SECRET_KEY_BASE=123

# docker build -t coolrequest/docker_app .