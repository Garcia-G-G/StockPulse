# Stage 1: Builder
FROM ruby:3.4-slim AS builder

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set frozen true && \
    bundle config set without "development test" && \
    bundle install --jobs 4 --retry 3 && \
    bundle clean --force && \
    rm -rf /usr/local/bundle/cache/*.gem

COPY . .

RUN SECRET_KEY_BASE=dummy RAILS_ENV=production \
    bundle exec rake assets:precompile

# Stage 2: Runtime
FROM ruby:3.4-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libpq5 tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system stockpulse && \
    useradd --system --gid stockpulse --create-home --shell /bin/bash stockpulse

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=stockpulse:stockpulse /app /app

ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

USER stockpulse

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/api/v1/health || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
