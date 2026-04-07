# frozen_string_literal: true

module Notifications
  class WhatsappSender
    def send_message(user:, message:)
      return unless user.whatsapp_number.present?

      text = Notifications::Formatter.new.format(message, channel: :whatsapp)
      method = ENV.fetch("WHATSAPP_METHOD", "twilio")

      case method
      when "twilio"
        send_via_twilio(user.whatsapp_number, text)
      when "openclaw"
        send_via_openclaw(user.whatsapp_number, text)
      end
    end

    private

    def send_via_twilio(to_number, text)
      account_sid = ENV.fetch("TWILIO_ACCOUNT_SID", nil)
      auth_token = ENV.fetch("TWILIO_AUTH_TOKEN", nil)
      from_number = ENV.fetch("TWILIO_WHATSAPP_FROM", nil)
      return unless account_sid.present? && auth_token.present?

      client = Twilio::REST::Client.new(account_sid, auth_token)
      client.messages.create(
        from: "whatsapp:#{from_number}",
        to: "whatsapp:#{to_number}",
        body: text
      )
    end

    def send_via_openclaw(to_number, text)
      api_url = ENV.fetch("OPENCLAW_API_URL", nil)
      return unless api_url.present?

      conn = Faraday.new(url: api_url) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      conn.post("/api/send", {
        platform: "whatsapp",
        to: to_number,
        message: text
      })
    end
  end
end
