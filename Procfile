web: bin/rails server -p 3000
worker: bundle exec sidekiq
stream: bin/rails stream:start
bot: bin/rails runner "StockPulseBot.new.start"
css: bin/rails tailwindcss:watch
