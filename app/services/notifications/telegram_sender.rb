# frozen_string_literal: true

module Notifications
  class TelegramSender
    API_BASE = "https://api.telegram.org"

    def send_message(user:, message:)
      chat_id = user.telegram_chat_id
      return unless chat_id.present?

      text = Notifications::Formatter.new.format(message, channel: :telegram)
      post_message(chat_id, text)
    end

    private

    def post_message(chat_id, text)
      token = ENV.fetch("TELEGRAM_BOT_TOKEN", nil)
      return unless token.present?

      conn = Faraday.new(url: API_BASE) do |f|
        f.request :json
        f.response :json
        f.request :retry, max: 2, interval: 1
        f.adapter Faraday.default_adapter
      end

      response = conn.post("/bot#{token}/sendMessage", {
        chat_id: chat_id,
        text: text,
        parse_mode: "Markdown",
        disable_web_page_preview: false
      })

      unless response.success?
        raise "Telegram API error: #{response.status} - #{response.body}"
      end

      response.body
    end
  end
end
