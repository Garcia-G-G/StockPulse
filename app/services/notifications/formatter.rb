# frozen_string_literal: true

module Notifications
  class Formatter
    EMOJIS = {
      "price_above" => "\u{1F4C8}",         # chart increasing
      "price_below" => "\u{1F4C9}",         # chart decreasing
      "percent_change_up" => "\u{1F680}",    # rocket
      "percent_change_down" => "\u{1F4C9}",  # chart decreasing
      "price_range_break" => "\u{1F4CA}",    # bar chart
      "rsi_overbought" => "\u{1F525}",       # fire
      "rsi_oversold" => "\u{2744}\u{FE0F}",  # snowflake
      "macd_crossover_bullish" => "\u{2B06}\u{FE0F}", # green arrow up
      "macd_crossover_bearish" => "\u{2B07}\u{FE0F}", # red arrow down
      "bollinger_break_upper" => "\u{1F30A}", # wave
      "bollinger_break_lower" => "\u{1F30A}", # wave
      "sma_golden_cross" => "\u{2B50}",       # star
      "sma_death_cross" => "\u{1F480}",       # skull
      "volume_spike" => "\u{1F4E2}",          # megaphone
      "volume_dry" => "\u{1F3DC}\u{FE0F}",   # desert
      "news_high_impact" => "\u{1F4F0}"       # newspaper
    }.freeze

    ALERT_TYPE_LABELS = {
      "price_above" => "Precio por encima",
      "price_below" => "Precio por debajo",
      "percent_change_up" => "Cambio porcentual alcista",
      "percent_change_down" => "Cambio porcentual bajista",
      "price_range_break" => "Ruptura de rango",
      "rsi_overbought" => "RSI sobrecompra",
      "rsi_oversold" => "RSI sobreventa",
      "macd_crossover_bullish" => "MACD cruce alcista",
      "macd_crossover_bearish" => "MACD cruce bajista",
      "bollinger_break_upper" => "Ruptura Bollinger superior",
      "bollinger_break_lower" => "Ruptura Bollinger inferior",
      "sma_golden_cross" => "Cruce dorado SMA",
      "sma_death_cross" => "Cruce de la muerte SMA",
      "volume_spike" => "Pico de volumen",
      "volume_dry" => "Volumen seco",
      "news_high_impact" => "Noticia de alto impacto"
    }.freeze

    def format_telegram(alert, price_data, ai_analysis = nil)
      emoji = EMOJIS[alert.alert_type] || "\u{1F514}" # bell
      label = ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type
      symbol = alert.symbol
      price = price_data[:close] || price_data[:price]
      change_pct = price_data[:change_percent]

      lines = []
      lines << "#{emoji} *#{esc(label)}*"
      lines << ""
      lines << "\u{1F4B9} *#{esc(symbol)}* \\| #{esc(company_name(alert))}"
      lines << "\u{1F4B0} Precio: *$#{esc(format_number(price))}*"
      lines << "\u{1F4CA} Cambio: #{esc(format_change(change_pct))}" if change_pct
      lines << ""
      lines << "\u{26A0}\u{FE0F} _#{esc(trigger_description(alert, price_data))}_"

      if ai_analysis.present? && !ai_analysis[:error]
        lines << ""
        lines << "\u{1F916} *Análisis IA:*"
        lines << esc(ai_analysis[:summary] || ai_analysis[:recommendation] || "Sin análisis disponible")
      end

      lines << ""
      lines << "\u{1F552} #{esc(Time.current.strftime('%H:%M:%S %Z'))}"

      lines.join("\n")
    end

    def format_whatsapp(alert, price_data, ai_analysis = nil)
      emoji = EMOJIS[alert.alert_type] || "\u{1F514}"
      label = ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type
      price = price_data[:close] || price_data[:price]
      change_pct = price_data[:change_percent]

      lines = []
      lines << "#{emoji} *#{label}*"
      lines << ""
      lines << "\u{1F4B9} *#{alert.symbol}* | #{company_name(alert)}"
      lines << "\u{1F4B0} Precio: *$#{format_number(price)}*"
      lines << "\u{1F4CA} Cambio: #{format_change(change_pct)}" if change_pct
      lines << ""
      lines << "\u{26A0}\u{FE0F} _#{trigger_description(alert, price_data)}_"

      if ai_analysis.present? && !ai_analysis[:error]
        lines << ""
        lines << "\u{1F916} *Análisis IA:*"
        lines << (ai_analysis[:summary] || "Sin análisis disponible")
      end

      lines << ""
      lines << "\u{1F552} #{Time.current.strftime('%H:%M:%S %Z')}"
      lines << ""
      lines << "_StockPulse - Monitoreo en Tiempo Real_"

      result = lines.join("\n")
      result.truncate(1600)
    end

    def format_email_subject(alert)
      emoji = EMOJIS[alert.alert_type] || "\u{1F514}"
      label = ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type
      "[StockPulse] #{emoji} #{alert.symbol}: #{label}"
    end

    def format_email_body(alert, price_data, ai_analysis = nil)
      {
        alert: alert,
        price_data: price_data,
        ai_analysis: ai_analysis,
        emoji: EMOJIS[alert.alert_type] || "\u{1F514}",
        label: ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type,
        company: company_name(alert),
        trigger_desc: trigger_description(alert, price_data),
        formatted_price: format_number(price_data[:close] || price_data[:price]),
        formatted_change: format_change(price_data[:change_percent])
      }
    end

    private

    def esc(text)
      return "" if text.nil?

      text.to_s.gsub(/([_*\[\]()~`>#+\-=|{}.!\\])/, '\\\\\1')
    end

    def format_number(num)
      return "N/A" unless num

      format("%.2f", num.to_f)
    end

    def format_change(pct)
      return "N/A" unless pct

      sign = pct.to_f >= 0 ? "+" : ""
      "#{sign}#{format('%.2f', pct.to_f)}%"
    end

    def company_name(alert)
      item = WatchlistItem.find_by(symbol: alert.symbol)
      item&.company_name || alert.symbol
    end

    def trigger_description(alert, price_data)
      condition = alert.condition.deep_symbolize_keys
      case alert.alert_type
      when "price_above"
        "Precio cruzó por encima de $#{format_number(condition[:target_price])}"
      when "price_below"
        "Precio cruzó por debajo de $#{format_number(condition[:target_price])}"
      when "percent_change_up"
        "Subió #{format_change(price_data[:change_percent])} (umbral: +#{condition[:threshold_percent]}%)"
      when "percent_change_down"
        "Bajó #{format_change(price_data[:change_percent])} (umbral: -#{condition[:threshold_percent]}%)"
      when "price_range_break"
        "Precio rompió rango [$#{format_number(condition[:lower])} - $#{format_number(condition[:upper])}]"
      when "rsi_overbought"
        "RSI entró en zona de sobrecompra (umbral: #{condition[:threshold] || 70})"
      when "rsi_oversold"
        "RSI entró en zona de sobreventa (umbral: #{condition[:threshold] || 30})"
      when "macd_crossover_bullish"
        "MACD cruce alcista detectado"
      when "macd_crossover_bearish"
        "MACD cruce bajista detectado"
      when "bollinger_break_upper"
        "Precio rompió banda superior de Bollinger"
      when "bollinger_break_lower"
        "Precio rompió banda inferior de Bollinger"
      when "sma_golden_cross"
        "Cruce dorado: SMA50 cruzó por encima de SMA200"
      when "sma_death_cross"
        "Cruce de la muerte: SMA50 cruzó por debajo de SMA200"
      when "volume_spike"
        "Pico de volumen detectado (umbral: #{condition[:threshold_percent]}%)"
      when "volume_dry"
        "Volumen seco detectado (umbral: #{condition[:threshold_percent]}%)"
      when "news_high_impact"
        "Noticia de alto impacto detectada (sentimiento: #{condition[:min_sentiment_score]})"
      else
        "Alerta activada"
      end
    end
  end
end
