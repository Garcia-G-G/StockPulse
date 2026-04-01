require "telegram/bot" if ENV["TELEGRAM_BOT_TOKEN"].present? && !ENV["TELEGRAM_BOT_TOKEN"].start_with?("your_")
