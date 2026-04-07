# frozen_string_literal: true

require "cgi"

module Notifications
  class Formatter
    def format(message, channel:)
      return message if message.is_a?(String)

      case channel.to_sym
      when :telegram
        format_telegram(message)
      when :email
        format_email(message)
      when :whatsapp
        format_whatsapp(message)
      else
        message.to_s
      end
    end

    private

    def format_telegram(msg)
      return msg if msg.is_a?(String)

      parts = []
      parts << "*#{msg[:title]}*" if msg[:title]
      parts << msg[:message] if msg[:message]
      parts << "" if msg[:data]
      if msg[:data].is_a?(Hash)
        msg[:data].each { |k, v| parts << "#{k}: `#{v}`" }
      end
      parts << "\n_#{msg[:footer]}_" if msg[:footer]
      parts.join("\n")
    end

    def format_email(msg)
      return msg if msg.is_a?(String)

      parts = []
      parts << "<h2>#{h msg[:title]}</h2>" if msg[:title]
      parts << "<p>#{h msg[:message]}</p>" if msg[:message]
      if msg[:data].is_a?(Hash)
        parts << "<table>"
        msg[:data].each { |k, v| parts << "<tr><td><strong>#{h k}</strong></td><td>#{h v}</td></tr>" }
        parts << "</table>"
      end
      parts << "<p><em>#{h msg[:footer]}</em></p>" if msg[:footer]
      parts.join("\n")
    end

    def format_whatsapp(msg)
      return msg if msg.is_a?(String)

      parts = []
      parts << "*#{msg[:title]}*" if msg[:title]
      parts << msg[:message] if msg[:message]
      if msg[:data].is_a?(Hash)
        msg[:data].each { |k, v| parts << "#{k}: #{v}" }
      end
      parts.join("\n")
    end

    def h(value)
      CGI.escapeHTML(value.to_s)
    end
  end
end
