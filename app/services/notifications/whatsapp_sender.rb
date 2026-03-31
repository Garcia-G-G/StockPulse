# frozen_string_literal: true

module Notifications
  class WhatsappSender
    def send_notification(user:, alert:, price_data:, ai_analysis:, formatter:)
      method = ENV.fetch("WHATSAPP_METHOD", "disabled")
      return { message_id: nil, skipped: true } if method == "disabled"

      number = user.whatsapp_number
      raise "No whatsapp_number for user #{user.id}" unless number.present?

      text = formatter.format_whatsapp(alert, price_data, ai_analysis)

      case method
      when "openclaw" then send_via_openclaw(number, text)
      when "twilio" then send_via_twilio(number, text)
      else
        Rails.logger.warn("[WhatsappSender] Unknown WHATSAPP_METHOD: #{method}")
        { message_id: nil, error: "Unknown method: #{method}" }
      end
    end

    # For simple text messages (used by legacy notify path)
    def send_message(user:, message:)
      send_notification(
        user: user,
        alert: OpenStruct.new(alert_type: "price_above", symbol: "INFO", condition: {}),
        price_data: {},
        ai_analysis: nil,
        formatter: simple_formatter(message)
      )
    end

    private

    # OpenClaw v2026.3.22 — uses Baileys (unofficial WhatsApp Web API).
    # Note: High-volume use may result in WhatsApp account ban.
    def send_via_openclaw(number, text)
      Rails.logger.info("[WhatsappSender] Sending via OpenClaw to #{number}")

      response = openclaw_connection.post("/api/v1/messages/send") do |req|
        req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENCLAW_API_KEY', '')}"
        req.body = { to: number, text: text }
      end

      body = response.body
      { message_id: body[:id]&.to_s || body[:message_id]&.to_s }
    end

    def send_via_twilio(number, text)
      Rails.logger.info("[WhatsappSender] Sending via Twilio to #{number}")

      client = Twilio::REST::Client.new(
        ENV.fetch("TWILIO_ACCOUNT_SID", ""),
        ENV.fetch("TWILIO_AUTH_TOKEN", "")
      )

      message = client.messages.create(
        from: "whatsapp:#{ENV.fetch('TWILIO_WHATSAPP_FROM', '')}",
        to: "whatsapp:#{number}",
        body: text
      )

      { message_id: message.sid }
    end

    def openclaw_connection
      @openclaw_connection ||= Faraday.new(url: ENV.fetch("OPENCLAW_API_URL", "")) do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: true }
        f.response :raise_error
        f.adapter :typhoeus
      end
    end

    def simple_formatter(message)
      formatter = Object.new
      formatter.define_singleton_method(:format_whatsapp) { |_alert, _price, _ai| message }
      formatter
    end
  end
end
