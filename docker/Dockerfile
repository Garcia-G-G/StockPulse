FROM ruby:3.3.8-slim AS base

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    libpq-dev curl && \
    rm -rf /var/lib/apt/lists/*

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git nodejs npm && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install

COPY . .

RUN bundle exec rails assets:precompile SECRET_KEY_BASE=dummy

FROM base

COPY --from=build /app /app
COPY --from=build /usr/local/bundle /usr/local/bundle

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails /app

USER rails:rails

EXPOSE 3000

CMD ["bundle", "exec", "thrust", "bin/rails", "server"]
