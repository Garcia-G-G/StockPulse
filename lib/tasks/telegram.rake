# frozen_string_literal: true

namespace :telegram do
  namespace :bot do
    desc "Start the interactive Telegram bot"
    task start: :environment do
      StockPulseBot.new.start
    end
  end
end
