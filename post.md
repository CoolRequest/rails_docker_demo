<!--intro-->
Wether you are running apps on your own infrastructure or deploying to the cloud, there are many [reasons](https://www.docker.com/why-docker) to containerize your Rails application (incluir link?). However, the rails new template doesn’t help you there, as the default generated code needs to be adapted to run in Docker. You will need to do some modifications to the app and add a carefully designed Dockerfile, which is important for speeding up build times and reducing the image size. That's what this post is about.

This text is divided in two parts. Part one will cover the basics, and show how to write a simple Dockerfile that should work for most apps. Part two will explain some tweaks that you can use to make your build faster and the resulting image lightweight. A basic understanding of Docker concepts and Dockerfile syntax is required for understanding the content.

One very important decision, that will impact the way you build your image is how you want to handle the assets. Particularlly, you should answer these two questions:
1) When will the assets precompilation happen? Will it be done in development time, and pushed to the source code repository? Or will it be done later, during the deploy process?
2) How will these assets be served? Same application server? External CDN?

There are no correct answers here, as this depends on many factors that are application or environment-specific. In our use-case, which we describe on this article, we assume that:
1) We don't want developers to care about building assets for production. The CI script should handle it.
2) In a small scale environment, the assets can be served by the same container that runs the application.

<!-- configs -->
Now let's get started. The first thing to be aware of when containerizing your application is that you should not have any configuration data in your docker image. This means that you will have to look at your application source code searching for files that hold database connection settings, URLs for external services, and any other settings that might change depending on the environment. Typical files to look are `config/database.yml`, `config/storage.yml`, and `config/initializers/*`. You should replace hard-coded values with environment variables. Here is what a typical `database.yml` would look like, using postgresql as an example:

```
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 20) %>
  database: <%= ENV["DB_DATABASE"] %>
  username: <%= ENV["DB_USERNAME"] %>
  password: <%= ENV["DB_PASSWORD"] %>
  host: <%= ENV["DB_HOST"] %>
  port: <%= ENV["DB_PORT"] || 5432 %>

development:
  <<: *default

test:
  <<: *default

staging:
  <<: *default

production:
  <<: *default
```

<!--dockerfile v1-->
Now that our configuration data is taken care of, let’s look at the steps necessary for building the image that will run the application. Starting from a very skinny linux distribution, we need to install all the things necessary to precompile the assets and run the app. In summary, what needs to be done is:
1. Setup the environment
- Choose a base image to start from
- Install basic build tools
- Install nodejs & yarn & bundler
- Install database client
2. Install the application
- Copy application files
- Install ruby dependencies (bundle)
- Install javascript dependencies (yarn)
- Precompile the assets

Let's go over these, step by, step. We start from the official ruby Docker image:
```
FROM ruby:2.7.4-slim
```

Then, add basic build tools which will be required in subsequent steps:
```
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
```

We will be needing *nodejs* to handle assets precompiling, *yarn* to install javascript dependencies, and *bundler* for the ruby gems:
```
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends yarn && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler
```

Next step, database client. You will need to install the client library / headers. This part is highly dependable on the database you are using. Here is what you would need for `postgresql`:
```
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client && \
    rm -rf /var/lib/apt/lists/*
```

So far, we have covered environment setup. Now we will start installing the application. First, we coppy the application files:
```
RUN mkdir -p /app
WORKDIR /app
COPY . /app
```

Then, install ruby dependencies:
```
RUN bundle install
```

.. and javascript dependencies:
```
RUN yarn
```

The assets are going to be precompiled during the image build process:
```
RUN bundle exec rake assets:precompile DB_ADAPTER=nulldb NODE_ENV=development RAILS_ENV=staging SECRET_KEY_BASE=123
```

<!-- fechamento -->
That's it. Now you can run your Rails application inside a Docker container, be it for development or production. You can access the full Dockerfile in [this link](https://github.com/coolrequest/docker_demo/Dockerfile).
Stay tuned for part 2 of this series, we will show some optimizations that can be done to this basic Dockerfile.
