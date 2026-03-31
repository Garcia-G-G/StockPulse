web: bin/rails server -p 3000
worker: bundle exec sidekiq
stream: bin/rails runner "Streaming::PriceStreamManager.new.start"
bot: bin/rails runner "StockPulseBot.new.start"
css: bin/rails tailwindcss:watch
