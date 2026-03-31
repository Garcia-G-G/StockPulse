# frozen_string_literal: true

module Notifications
  class TelegramSender
    API_BASE = "https://api.telegram.org"

    def send_notification(user:, alert:, price_data:, ai_analysis:, formatter:)
      chat_id = user.telegram_chat_id
      raise "No telegram_chat_id for user #{user.id}" unless chat_id.present?

      text = formatter.format_telegram(alert, price_data, ai_analysis)
      keyboard = build_inline_keyboard(alert)

      response = connection.post("/bot#{token}/sendMessage") do |req|
        req.body = {
          chat_id: chat_id,
          text: text,
          parse_mode: "MarkdownV2",
          reply_markup: keyboard.to_json
        }
      end

      body = response.body
      raise "Telegram API error: #{body[:description]}" unless body[:ok]

      { message_id: body.dig(:result, :message_id)&.to_s }
    rescue Faraday::ClientError => e
      handle_telegram_error(e, user)
    end

    # For simple text messages (used by legacy notify path)
    def send_message(user:, message:)
      chat_id = user.telegram_chat_id
      return unless chat_id.present?

      connection.post("/bot#{token}/sendMessage") do |req|
        req.body = { chat_id: chat_id, text: message, parse_mode: "MarkdownV2" }
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: API_BASE) do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: true }
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def token
      ENV.fetch("TELEGRAM_BOT_TOKEN", "")
    end

    def build_inline_keyboard(alert)
      {
        inline_keyboard: [
          [
            { text: "\u{1F50D} Ver detalles", url: dashboard_url },
            { text: "\u{1F515} Silenciar 1h", callback_data: "mute:60" }
          ],
          [
            { text: "\u{274C} Desactivar alerta", callback_data: "disable:#{alert.id}" }
          ]
        ]
      }
    end

    def dashboard_url
      "#{ENV.fetch('APP_HOST', 'http://localhost:3000')}/"
    end

    def handle_telegram_error(error, user)
      response_body = error.response&.dig(:body)
      error_code = response_body&.dig(:error_code)

      case error_code
      when 429
        retry_after = response_body&.dig(:parameters, :retry_after) || 30
        Rails.logger.warn("[TelegramSender] Rate limited, retry after #{retry_after}s")
        sleep(retry_after)
        raise error # Let Manager retry
      when 403
        Rails.logger.warn("[TelegramSender] Bot blocked by user #{user.id}, disabling Telegram")
        prefs = user.notification_preferences&.deep_dup || {}
        prefs["telegram"] ||= {}
        prefs["telegram"]["enabled"] = false
        user.update!(notification_preferences: prefs)
        { message_id: nil, error: "Bot blocked by user" }
      when 400
        Rails.logger.error("[TelegramSender] Bad request: #{response_body&.dig(:description)}")
        { message_id: nil, error: response_body&.dig(:description) }
      else
        raise error
      end
    end
  end
end
