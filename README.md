<div align="center">

# StockPulse

**Real-time stock monitoring, intelligent alerts, and AI-powered analysis**

[![CI](https://github.com/Garcia-G-G/StockPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/Garcia-G-G/StockPulse/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.8-red?logo=ruby)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0-red?logo=rubyonrails)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?logo=postgresql)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-red?logo=redis)](https://redis.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## Overview

StockPulse is a self-hosted stock market monitoring platform built with Rails 8. It connects to financial data APIs, evaluates custom alert conditions in real-time, and delivers notifications via Telegram, WhatsApp, and email. An integrated AI service powered by Google Gemini provides market analysis and daily briefings.

```
Finnhub/Alpaca WSS ──► PriceStreamManager ──► ActionCable ──► Browser
                            │                      │
                        Redis Cache            AlertEngine
                            │                      │
                      PriceSnapshots          Notifications
                          (DB)            (Telegram/Email/WA)
```

---

## Features

| Category | Details |
|----------|---------|
| **Real-Time Data** | WebSocket streaming from Finnhub + Alpaca with automatic failover, 1-second aggregation, Redis price cache |
| **Smart Alerts** | Price thresholds, percent change, RSI, MACD crossover, Bollinger bands, volume spikes, news sentiment, multi-condition (AND/OR) |
| **Notifications** | Telegram bot (14 commands), WhatsApp (Twilio/OpenClaw), email with HTML templates |
| **AI Analysis** | Google Gemini integration for market analysis, daily briefings, alert importance scoring |
| **Dashboard** | Analytical dark-theme UI with live stats, watchlist table, alert feed, market status |
| **Background Jobs** | Sidekiq-powered: price snapshots, indicator updates, news checks, scheduled briefings, cleanup |
| **API** | RESTful JSON API with token + Telegram auth, rate limiting, circuit breaker pattern |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby 3.3.8, Rails 8.0, Puma |
| Database | PostgreSQL 16, Redis 7 |
| Background Jobs | Sidekiq 8 + sidekiq-cron |
| Real-Time | ActionCable (Solid Cable), Faye WebSocket |
| Data Sources | Finnhub (primary), Alpha Vantage (indicators), MarketAux (news) |
| AI | Google Gemini 2.0 Flash via FastAPI microservice |
| Notifications | Telegram Bot API, Twilio (WhatsApp), SMTP |
| Frontend | Server-rendered ERB + Tailwind CSS + Stimulus |
| Infrastructure | Docker Compose, GitHub Actions CI, Kamal deploy |

---

## Quick Start

### Prerequisites

- Ruby 3.3.8 (via rbenv/asdf)
- PostgreSQL 16+
- Redis 7+
- Node.js 20+ (for asset pipeline)

### Setup

```bash
# Clone
git clone https://github.com/Garcia-G-G/StockPulse.git
cd StockPulse

# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env with your API keys (Finnhub, Telegram, etc.)

# Setup database
bin/rails db:create db:migrate db:seed

# Start everything
bin/dev
```

The dashboard will be available at **http://localhost:3000**

### With Docker

```bash
cp .env.example .env
# Edit .env with your credentials

# Development (includes pgAdmin + RedisInsight)
make dev

# Production
make prod
```

---

## API Keys

| Service | Free Tier | Get Key |
|---------|-----------|---------|
| **Finnhub** | 60 calls/min, WebSocket | [finnhub.io/register](https://finnhub.io/register) |
| **Alpha Vantage** | 25 calls/day | [alphavantage.co/support](https://www.alphavantage.co/support/#api-key) |
| **MarketAux** | 100 calls/day | [marketaux.com](https://www.marketaux.com/) |
| **Google Gemini** | 15 RPM free | [ai.google.dev](https://ai.google.dev/) |
| **Telegram Bot** | Unlimited | [@BotFather](https://t.me/BotFather) |

---

## Architecture

### Services

```
bin/dev starts:
  web:    Rails server (port 3000)
  worker: Sidekiq background jobs
  css:    Tailwind CSS watcher

Separate process:
  stream: bin/rails stream:start  (WebSocket price streaming)
  bot:    StockPulseBot           (Telegram bot)
```

### Scheduled Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `SyncSubscriptionsJob` | Every 5 min | Rebalance WebSocket subscriptions |
| `UpdateIndicatorsJob` | Every 15 min | Fetch RSI, MACD, Bollinger from Alpha Vantage |
| `CheckNewsJob` | Every 30 min | Check MarketAux for relevant news |
| `MorningBriefingJob` | 8:00 AM ET (weekdays) | AI-generated morning briefing |
| `DailySummaryJob` | 5:00 PM ET (weekdays) | End-of-day summary + email digest |
| `WeeklyReportJob` | 8:00 PM ET (Sunday) | Weekly performance report |
| `CleanupSnapshotsJob` | 3:00 AM daily | Purge snapshots > 30 days |

### Alert Types

| Type | Trigger |
|------|---------|
| `price_above` / `price_below` | Price crosses threshold |
| `price_change_pct` | Percent change exceeds limit |
| `rsi_overbought` / `rsi_oversold` | RSI crosses 70/30 |
| `macd_crossover` | MACD/Signal line cross |
| `bollinger_breakout` | Price exits Bollinger bands |
| `volume_spike` | Volume exceeds N% of 20-day average |
| `news_sentiment` | High-impact news detected |
| `multi_condition` | AND/OR combination of above |

---

## API Endpoints

### Watchlist
```
GET    /api/v1/watchlists           # List watchlist
POST   /api/v1/watchlists           # Add symbol
DELETE /api/v1/watchlists/:id       # Remove symbol
GET    /api/v1/watchlists/:id/quote # Live quote
```

### Alerts
```
GET    /api/v1/alerts               # List active alerts
POST   /api/v1/alerts               # Create alert
PATCH  /api/v1/alerts/:id           # Update alert
DELETE /api/v1/alerts/:id           # Delete alert
GET    /api/v1/alerts/history       # Triggered alert history
```

### Analysis
```
GET    /api/v1/analysis/:symbol/overview   # AI analysis + quote + indicators
GET    /api/v1/analysis/:symbol/technical  # RSI, MACD, Bollinger
GET    /api/v1/analysis/:symbol/news       # News + sentiment
GET    /api/v1/analysis/briefing           # Daily briefing
```

### Prices (Real-Time)
```
GET    /api/v1/prices/current?symbols=AAPL,MSFT  # Current prices from cache
GET    /api/v1/prices/:symbol/history             # Price history
GET    /api/v1/prices/stream_status               # WebSocket connection status
```

### System
```
GET    /api/v1/health               # Health check (public)
GET    /api/v1/health/metrics       # System metrics
```

**Authentication:** Pass `X-Telegram-Chat-Id` header or `X-API-Token` header.

---

## Telegram Bot Commands

```
/start      — Register and set up your account
/watch AAPL — Add symbol to watchlist
/unwatch AAPL — Remove symbol
/watchlist  — View watchlist with prices
/quote AAPL — Get current quote
/alert AAPL above 200 — Create price alert
/alerts     — View active alerts
/remove 5   — Remove alert #5
/analysis AAPL — AI analysis
/briefing   — Generate daily briefing
/mute       — Mute notifications
/unmute     — Unmute notifications
/status     — System status
/help       — List all commands
```

---

## Testing

```bash
# Full suite
make test

# By category
bundle exec rspec spec/models
bundle exec rspec spec/services
bundle exec rspec spec/requests
bundle exec rspec spec/jobs

# Lint + security
make lint
make security
```

---

## Deployment

### Hetzner / VPS

```bash
# One-time server setup
scripts/setup_server.sh

# Deploy
scripts/deploy.sh

# Backup
scripts/backup.sh
```

### Environment

Required production environment variables — see [`.env.example`](.env.example) for the full list.

---

## Project Structure

```
app/
  channels/       — ActionCable channels (prices, alerts, status)
  clients/        — API clients (Finnhub, Alpha Vantage, MarketAux, Alpaca, AI)
  controllers/    — API v1 controllers + dashboard
  jobs/           — Sidekiq background jobs
  mailers/        — Email templates
  models/         — ActiveRecord models + concerns
  serializers/    — JSONAPI serializers
  services/
    alerts/       — Alert evaluators (price, technical, volume, news, multi)
    notifications/— Senders (Telegram, Email, WhatsApp) + formatter
    streaming/    — PriceStreamManager, TradeAggregator, RedisPriceCache
    watchlists/   — Watchlist manager
    stock_pulse_bot.rb — Telegram bot
  views/          — Dashboard ERB templates
ai_service/       — Python FastAPI + Google Gemini
config/
  initializers/   — Finnhub, Alpaca, Redis, Sidekiq, Telegram, CORS, CSP
  routes.rb       — API routes + ActionCable + Sidekiq Web
spec/             — RSpec tests (models, services, requests, jobs)
```

---

## Estimated Costs

| Service | Monthly Cost |
|---------|-------------|
| Hetzner CX21 (4GB RAM) | ~$9 |
| Finnhub Free Tier | $0 |
| Alpha Vantage Free | $0 |
| Google Gemini Free | $0 |
| Telegram Bot | $0 |
| **Total** | **~$9/month** |

---

## License

MIT

</div>
