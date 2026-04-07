if defined?(Telegram::Bot) && ENV["TELEGRAM_BOT_TOKEN"].present?
  Telegram::Bot::Client.define do |config|
    config.bots = {
      default: ENV["TELEGRAM_BOT_TOKEN"]
    }
  end
end
