# frozen_string_literal: true

require "telegram/bot"

class StockPulseBot
  COMMAND_ALIASES = { "p" => "precio", "w" => "watchlist", "a" => "agregar", "ai" => "analisis", "n" => "noticias" }.freeze

  def initialize
    @token = ENV.fetch("TELEGRAM_BOT_TOKEN", "")
    @running = false
  end

  def start
    @running = true
    setup_signal_handlers

    Rails.logger.info("[TelegramBot] Starting long polling")

    Telegram::Bot::Client.run(@token) do |bot|
      @bot = bot
      bot.listen do |update|
        break unless @running

        handle_update(update)
      rescue StandardError => e
        Rails.logger.error("[TelegramBot] Error handling update: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      end
    end

    Rails.logger.info("[TelegramBot] Stopped")
  end

  private

  def handle_update(update)
    case update
    when Telegram::Bot::Types::Message
      handle_message(update)
    when Telegram::Bot::Types::CallbackQuery
      handle_callback(update)
    end
  end

  # --- Message Routing ---

  def handle_message(message)
    text = message.text&.strip
    return unless text.present?

    chat_id = message.chat.id
    user = resolve_user(message)

    Rails.logger.info("[TelegramBot] #{chat_id}: #{text}")

    if text.start_with?("/")
      handle_command(message, user, text)
    else
      handle_text(message, user, text)
    end
  end

  def handle_command(message, user, text)
    parts = text.split(/\s+/)
    cmd = parts[0].delete_prefix("/").split("@").first.downcase
    cmd = COMMAND_ALIASES[cmd] || cmd
    args = parts[1..]

    case cmd
    when "start" then cmd_start(message, user)
    when "help" then cmd_help(message)
    when "precio" then cmd_precio(message, user, args)
    when "buscar" then cmd_buscar(message, args)
    when "mercado" then cmd_mercado(message)
    when "watchlist" then cmd_watchlist(message, user)
    when "agregar" then cmd_agregar(message, user, args)
    when "eliminar" then cmd_eliminar(message, user, args)
    when "alertas" then cmd_alertas(message, user)
    when "alerta" then cmd_alerta(message, user, args)
    when "desactivar" then cmd_desactivar(message, user, args)
    when "analisis" then cmd_analisis(message, user, args)
    when "noticias" then cmd_noticias(message, user, args)
    when "briefing" then cmd_briefing(message, user)
    when "silenciar" then cmd_silenciar(message, user, args)
    when "activar" then cmd_activar(message, user)
    when "config" then cmd_config(message, user)
    else
      reply(message, "\u{2753} Comando desconocido\\. Usa /help para ver comandos disponibles\\.")
    end
  end

  def handle_text(message, user, text)
    # Check for session state first
    session = get_session(message.chat.id)
    if session
      handle_session(message, user, session, text)
      return
    end

    # Check if it looks like a stock symbol
    if text.match?(/\A[A-Z]{1,5}\z/)
      cmd_precio(message, user, [ text ])
    else
      reply(message, "Envía un símbolo como *AAPL* o usa /help para ver comandos")
    end
  end

  # --- Information Commands ---

  def cmd_start(message, _user)
    text = [
      "\u{1F4C8} *Bienvenido a StockPulse\\!*",
      "",
      "Monitoreo de acciones en tiempo real con alertas inteligentes\\.",
      "",
      "\u{1F4CB} *Comandos principales:*",
      "  /precio \\{SYMBOL\\} \\- Cotización actual",
      "  /watchlist \\- Tu lista de seguimiento",
      "  /alertas \\- Tus alertas activas",
      "  /analisis \\{SYMBOL\\} \\- Análisis IA",
      "  /briefing \\- Resumen del mercado",
      "",
      "Usa /help para ver todos los comandos\\."
    ].join("\n")

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F4CB} Mi Watchlist", callback_data: "cmd:watchlist"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F30D} Mercado", callback_data: "cmd:mercado")
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F4CA} Briefing", callback_data: "cmd:briefing")
        ]
      ]
    )

    reply(message, text, reply_markup: keyboard)
  end

  def cmd_help(message)
    text = [
      "\u{2139}\u{FE0F} *Comandos de StockPulse*",
      "",
      "\u{1F4B0} *Información:*",
      "  /precio \\{SYM\\} \\- Cotización actual",
      "  /buscar \\{query\\} \\- Buscar símbolos",
      "  /mercado \\- Estado del mercado",
      "",
      "\u{1F4CB} *Watchlist:*",
      "  /watchlist \\- Ver lista",
      "  /agregar \\{SYM\\} \\- Agregar símbolo",
      "  /eliminar \\{SYM\\} \\- Eliminar símbolo",
      "",
      "\u{1F514} *Alertas:*",
      "  /alertas \\- Ver alertas activas",
      "  /alerta \\{SYM\\} \\{TIPO\\} \\{VALOR\\} \\- Crear alerta",
      "  /desactivar \\{ID\\} \\- Desactivar alerta",
      "",
      "\u{1F916} *Análisis:*",
      "  /analisis \\{SYM\\} \\- Análisis IA",
      "  /noticias \\{SYM\\} \\- Noticias recientes",
      "  /briefing \\- Resumen diario",
      "",
      "\u{2699}\u{FE0F} *Control:*",
      "  /silenciar \\{MIN\\} \\- Silenciar notificaciones",
      "  /activar \\- Reactivar notificaciones",
      "  /config \\- Configuración"
    ].join("\n")

    reply(message, text)
  end

  def cmd_precio(message, _user, args)
    symbol = args&.first&.upcase
    return reply(message, "\u{26A0}\u{FE0F} Uso: /precio AAPL") unless symbol

    reply(message, "\u{23F3} Consultando #{esc(symbol)}\\.\\.\\.")

    quote = FinnhubClient.new.quote(symbol)
    return reply(message, "\u{274C} No se encontró cotización para #{esc(symbol)}") unless quote&.dig(:c)

    price = quote[:c]
    change = quote[:d] || 0
    change_pct = quote[:dp] || 0
    arrow = change >= 0 ? "\u{1F7E2}" : "\u{1F534}"

    text = [
      "#{arrow} *#{esc(symbol)}*",
      "",
      "\u{1F4B0} Precio: *$#{esc(fmt(price))}*",
      "\u{1F4CA} Cambio: #{esc(fmt_change(change))} \\(#{esc(fmt_change(change_pct))}%\\)",
      "\u{1F4C8} Máximo: $#{esc(fmt(quote[:h]))}",
      "\u{1F4C9} Mínimo: $#{esc(fmt(quote[:l]))}",
      "\u{1F4CA} Volumen: #{esc(number_fmt(quote[:v] || 0))}",
      "\u{1F519} Cierre ant: $#{esc(fmt(quote[:pc]))}"
    ].join("\n")

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{2795} Watchlist", callback_data: "add_watchlist:#{symbol}"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F514} Alerta", callback_data: "create_alert:#{symbol}"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F916} IA", callback_data: "analyze:#{symbol}")
        ]
      ]
    )

    reply(message, text, reply_markup: keyboard)
  rescue BaseClient::RateLimitExceeded
    reply(message, "\u{26A0}\u{FE0F} Límite de API alcanzado\\. Intenta en unos minutos\\.")
  rescue BaseClient::ApiError => e
    reply(message, "\u{274C} Error consultando #{esc(symbol)}: #{esc(e.message)}")
  end

  def cmd_buscar(message, args)
    query = args&.join(" ")
    return reply(message, "\u{26A0}\u{FE0F} Uso: /buscar apple") unless query.present?

    results = FinnhubClient.new.search(query)
    matches = results&.dig(:result)&.first(5)
    return reply(message, "\u{1F50D} Sin resultados para '#{esc(query)}'") if matches.blank?

    buttons = matches.map do |m|
      [ Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "#{m[:symbol]} — #{m[:description]}",
        callback_data: "add_watchlist:#{m[:symbol]}"
      ) ]
    end

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    reply(message, "\u{1F50D} Resultados para '#{esc(query)}':", reply_markup: keyboard)
  rescue StandardError => e
    reply(message, "\u{274C} Error en búsqueda: #{esc(e.message)}")
  end

  def cmd_mercado(message)
    status = FinnhubClient.new.market_status
    is_open = status&.dig(:isOpen)

    emoji = is_open ? "\u{1F7E2}" : "\u{1F534}"
    state = is_open ? "ABIERTO" : "CERRADO"

    reply(message, "#{emoji} Mercado US: *#{state}*")
  rescue StandardError => e
    reply(message, "\u{274C} Error: #{esc(e.message)}")
  end

  # --- Watchlist Commands ---

  def cmd_watchlist(message, user)
    items = user.watchlist_items.active.by_priority.includes(:user)
    return reply(message, "\u{1F4CB} Tu watchlist está vacía\\. Usa /agregar para añadir símbolos\\.") if items.empty?

    lines = items.map do |item|
      stars = "\u{2B50}" * item.priority
      "#{stars} *#{esc(item.symbol)}* \\- #{esc(item.company_name)}"
    end

    text = "\u{1F4CB} *Tu Watchlist:*\n\n#{lines.join("\n")}"
    reply(message, text)
  end

  def cmd_agregar(message, user, args)
    symbol = args&.first&.upcase
    return reply(message, "\u{26A0}\u{FE0F} Uso: /agregar AAPL") unless symbol

    profile = FinnhubClient.new.company_profile(symbol)
    name = profile&.dig(:name) || symbol

    item = user.watchlist_items.find_or_initialize_by(symbol: symbol)
    if item.persisted? && item.is_active
      return reply(message, "\u{2139}\u{FE0F} #{esc(symbol)} ya está en tu watchlist\\.")
    end

    item.update!(company_name: name, is_active: true)

    buttons = (1..5).map do |p|
      [ Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "\u{2B50}" * p,
        callback_data: "priority:#{symbol}:#{p}"
      ) ]
    end

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
    reply(message, "\u{2705} *#{esc(symbol)}* \\(#{esc(name)}\\) agregado\\. Selecciona prioridad:", reply_markup: keyboard)
  rescue StandardError => e
    reply(message, "\u{274C} Error: #{esc(e.message)}")
  end

  def cmd_eliminar(message, user, args)
    symbol = args&.first&.upcase
    return reply(message, "\u{26A0}\u{FE0F} Uso: /eliminar AAPL") unless symbol

    item = user.watchlist_items.find_by(symbol: symbol, is_active: true)
    return reply(message, "\u{274C} #{esc(symbol)} no está en tu watchlist\\.") unless item

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [ [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{2705} Confirmar", callback_data: "remove_watchlist:#{symbol}"),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{274C} Cancelar", callback_data: "cancel")
      ] ]
    )

    reply(message, "\u{26A0}\u{FE0F} ¿Eliminar *#{esc(symbol)}* de tu watchlist?", reply_markup: keyboard)
  end

  # --- Alert Commands ---

  def cmd_alertas(message, user)
    alerts = user.alerts.enabled
    return reply(message, "\u{1F514} No tienes alertas activas\\. Usa /alerta para crear una\\.") if alerts.empty?

    lines = alerts.map do |a|
      "\\##{a.id} *#{esc(a.symbol)}* \\- #{esc(a.alert_type)} \\(#{a.trigger_count}x\\)"
    end

    text = "\u{1F514} *Tus Alertas:*\n\n#{lines.join("\n")}"
    reply(message, text)
  end

  def cmd_alerta(message, user, args)
    return reply(message, "\u{26A0}\u{FE0F} Uso: /alerta AAPL arriba 200") if args.size < 2

    symbol = args[0].upcase
    type_hint = args[1]&.downcase
    value = args[2]

    alert_type, condition = parse_alert_args(type_hint, value)
    return reply(message, "\u{274C} Tipo de alerta no reconocido: #{esc(type_hint)}") unless alert_type

    alert = user.alerts.create!(
      symbol: symbol,
      alert_type: alert_type,
      condition: condition,
      notification_channels: [ "telegram" ]
    )

    reply(message, "\u{2705} Alerta creada \\##{alert.id}: *#{esc(symbol)}* #{esc(alert_type)}")
  rescue ActiveRecord::RecordInvalid => e
    reply(message, "\u{274C} Error creando alerta: #{esc(e.message)}")
  end

  def cmd_desactivar(message, user, args)
    alert_id = args&.first&.to_i
    return reply(message, "\u{26A0}\u{FE0F} Uso: /desactivar 123") unless alert_id&.positive?

    alert = user.alerts.find_by(id: alert_id)
    return reply(message, "\u{274C} Alerta no encontrada\\.") unless alert

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [ [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{2705} Confirmar", callback_data: "disable:#{alert.id}"),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{274C} Cancelar", callback_data: "cancel")
      ] ]
    )

    reply(message, "\u{26A0}\u{FE0F} ¿Desactivar alerta \\##{alert.id} \\(#{esc(alert.symbol)} #{esc(alert.alert_type)}\\)?", reply_markup: keyboard)
  end

  # --- Analysis Commands ---

  def cmd_analisis(message, _user, args)
    symbol = args&.first&.upcase
    return reply(message, "\u{26A0}\u{FE0F} Uso: /analisis AAPL") unless symbol

    reply(message, "\u{1F916} Analizando #{esc(symbol)}\\.\\.\\.")

    quote = FinnhubClient.new.quote(symbol)
    result = AiServiceClient.new.analyze_price(
      symbol: symbol,
      current_price: quote&.dig(:c) || 0,
      previous_close: quote&.dig(:pc) || 0,
      change_percent: quote&.dig(:dp) || 0
    )

    if result&.dig(:error)
      return reply(message, "\u{26A0}\u{FE0F} Análisis IA no disponible\\. Intenta más tarde\\.")
    end

    sentiment_emoji = { "bullish" => "\u{1F7E2}", "bearish" => "\u{1F534}", "neutral" => "\u{1F7E1}" }
    emoji = sentiment_emoji[result[:sentiment]] || "\u{1F7E1}"

    text = [
      "#{emoji} *Análisis IA: #{esc(symbol)}*",
      "",
      esc(result[:summary] || "Sin resumen disponible"),
      "",
      "\u{1F4CA} Confianza: #{result[:confidence]}%",
      "\u{23F0} Horizonte: #{esc(result[:timeframe] || "corto")}",
      "",
      "_Esto no es asesoramiento financiero\\._"
    ].join("\n")

    reply(message, text)
  rescue StandardError => e
    reply(message, "\u{274C} Error en análisis: #{esc(e.message)}")
  end

  def cmd_noticias(message, _user, args)
    symbol = args&.first&.upcase
    return reply(message, "\u{26A0}\u{FE0F} Uso: /noticias AAPL") unless symbol

    response = MarketAuxClient.new.news_for_symbol(symbol, limit: 5)
    articles = response.is_a?(Hash) ? (response[:data] || []) : []
    return reply(message, "\u{1F4F0} Sin noticias recientes para #{esc(symbol)}\\.") if articles.empty?

    lines = articles.first(5).map do |a|
      "\u{1F4F0} #{esc(a[:title] || 'Sin título')}"
    end

    text = "\u{1F4F0} *Noticias: #{esc(symbol)}*\n\n#{lines.join("\n\n")}"
    reply(message, text)
  rescue StandardError => e
    reply(message, "\u{274C} Error: #{esc(e.message)}")
  end

  def cmd_briefing(message, user)
    reply(message, "\u{1F4CA} Generando briefing\\.\\.\\.")

    items = user.watchlist_items.active.by_priority
    return reply(message, "\u{26A0}\u{FE0F} Agrega símbolos a tu watchlist primero\\.") if items.empty?

    watchlist = items.map do |item|
      quote = FinnhubClient.new.quote(item.symbol) rescue {}
      { symbol: item.symbol, price: quote[:c] || 0, change_percent: quote[:dp] || 0 }
    end

    result = AiServiceClient.new.daily_briefing(watchlist: watchlist)

    if result&.dig(:error)
      lines = watchlist.map { |w| "*#{esc(w[:symbol])}*: $#{esc(fmt(w[:price]))} \\(#{esc(fmt_change(w[:change_percent]))}%\\)" }
      return reply(message, "\u{1F4CA} *Resumen Rápido:*\n\n#{lines.join("\n")}\n\n_IA no disponible\\._")
    end

    text = "\u{1F4CA} *Briefing del Mercado*\n\n#{esc(result[:market_summary] || 'Sin resumen')}"
    reply(message, text)
  rescue StandardError => e
    reply(message, "\u{274C} Error: #{esc(e.message)}")
  end

  # --- Control Commands ---

  def cmd_silenciar(message, user, args)
    minutes = (args&.first || 60).to_i
    user.mute!(minutes)
    resume_at = minutes.minutes.from_now.strftime("%H:%M")
    reply(message, "\u{1F515} Notificaciones silenciadas por #{minutes} minutos\\. Se reanudan a las #{esc(resume_at)}\\.")
  end

  def cmd_activar(message, user)
    user.unmute!
    reply(message, "\u{1F514} Notificaciones reactivadas\\.")
  end

  def cmd_config(message, user)
    channels = user.enabled_channels
    muted = user.muted? ? "Sí (hasta #{esc(user.muted_until&.strftime('%H:%M') || '?')})" : "No"

    text = [
      "\u{2699}\u{FE0F} *Configuración:*",
      "",
      "\u{1F4E1} Canales: #{channels.map { |c| esc(c.to_s) }.join(', ').presence || 'ninguno'}",
      "\u{1F515} Silenciado: #{muted}",
      "\u{1F30D} Zona horaria: #{esc(user.timezone)}",
      "\u{1F553} Horas tranquilas: configuradas en preferencias"
    ].join("\n")

    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F515} Silenciar 1h", callback_data: "mute:60"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "\u{1F514} Activar", callback_data: "unmute")
        ]
      ]
    )

    reply(message, text, reply_markup: keyboard)
  end

  # --- Callback Handler ---

  def handle_callback(callback)
    user = resolve_user_from_callback(callback)
    data = callback.data

    case data
    when /\Amute:(\d+)\z/
      user.mute!(::Regexp.last_match(1).to_i)
      answer_callback(callback, "Silenciado por #{::Regexp.last_match(1)} minutos")
    when "unmute"
      user.unmute!
      answer_callback(callback, "Notificaciones activadas")
    when /\Adisable:(\d+)\z/
      alert = user.alerts.find_by(id: ::Regexp.last_match(1))
      alert&.disable!
      answer_callback(callback, "Alerta desactivada")
    when /\Adelete:(\d+)\z/
      alert = user.alerts.find_by(id: ::Regexp.last_match(1))
      alert&.destroy
      answer_callback(callback, "Alerta eliminada")
    when /\Aadd_watchlist:(\w+)\z/
      symbol = ::Regexp.last_match(1)
      profile = FinnhubClient.new.company_profile(symbol) rescue {}
      name = profile&.dig(:name) || symbol
      user.watchlist_items.find_or_create_by!(symbol: symbol) { |i| i.company_name = name }
      answer_callback(callback, "#{symbol} agregado a watchlist")
    when /\Aremove_watchlist:(\w+)\z/
      item = user.watchlist_items.find_by(symbol: ::Regexp.last_match(1))
      item&.soft_delete!
      answer_callback(callback, "#{::Regexp.last_match(1)} eliminado de watchlist")
    when /\Apriority:(\w+):(\d)\z/
      item = user.watchlist_items.find_by(symbol: ::Regexp.last_match(1))
      item&.update!(priority: ::Regexp.last_match(2).to_i)
      answer_callback(callback, "Prioridad actualizada")
    when /\Aanalyze:(\w+)\z/
      answer_callback(callback, "Analizando...")
      cmd_analisis(callback.message, user, [ ::Regexp.last_match(1) ])
    when /\Acmd:(\w+)\z/
      cmd = ::Regexp.last_match(1)
      answer_callback(callback, "")
      handle_command(callback.message, user, "/#{cmd}")
    when "cancel"
      answer_callback(callback, "Cancelado")
      edit_message(callback, "\u{274C} Cancelado")
    else
      answer_callback(callback, "Acción no reconocida")
    end
  rescue StandardError => e
    Rails.logger.error("[TelegramBot] Callback error: #{e.message}")
    answer_callback(callback, "Error: #{e.message.truncate(50)}")
  end

  # --- Session State ---

  def get_session(chat_id)
    raw = REDIS_POOL.with { |r| r.get("bot_session:#{chat_id}") }
    raw ? JSON.parse(raw, symbolize_names: true) : nil
  end

  def set_session(chat_id, data)
    REDIS_POOL.with { |r| r.setex("bot_session:#{chat_id}", 300, data.to_json) }
  end

  def clear_session(chat_id)
    REDIS_POOL.with { |r| r.del("bot_session:#{chat_id}") }
  end

  def handle_session(_message, _user, _session, _text)
    # Reserved for multi-step interactions (alert creation wizard, etc.)
    # Currently all commands are single-step
  end

  # --- Alert Parsing ---

  def parse_alert_args(type_hint, value)
    case type_hint
    when "arriba", "above"
      [ "price_above", { target_price: value.to_f } ]
    when "abajo", "below"
      [ "price_below", { target_price: value.to_f } ]
    when "cambio", "change"
      pct = value&.delete("%").to_f
      [ "percent_change_up", { threshold_percent: pct, timeframe: "1d" } ]
    when "rsi"
      threshold = value&.to_f || 70
      threshold > 50 ? [ "rsi_overbought", { threshold: threshold } ] : [ "rsi_oversold", { threshold: threshold } ]
    when "volumen", "volume"
      [ "volume_spike", { threshold_percent: value&.delete("%").to_f || 200 } ]
    when "noticias", "news"
      [ "news_high_impact", { min_sentiment_score: 0.7 } ]
    end
  end

  # --- User Resolution ---

  def resolve_user(message)
    chat_id = message.chat.id.to_s
    User.find_by(telegram_chat_id: chat_id) || User.create!(
      username: message.from&.username || "tg_#{chat_id}",
      telegram_chat_id: chat_id,
      email: nil
    )
  end

  def resolve_user_from_callback(callback)
    chat_id = callback.message.chat.id.to_s
    User.find_by(telegram_chat_id: chat_id) || User.create!(
      username: callback.from&.username || "tg_#{chat_id}",
      telegram_chat_id: chat_id,
      email: nil
    )
  end

  # --- Telegram API Helpers ---

  def reply(message, text, reply_markup: nil)
    @bot.api.send_message(
      chat_id: message.chat.id,
      text: text,
      parse_mode: "MarkdownV2",
      reply_markup: reply_markup
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.error("[TelegramBot] Send error: #{e.message}")
    # Retry without markdown if formatting fails
    @bot.api.send_message(chat_id: message.chat.id, text: text.gsub(/\\(.)/, '\1'))
  rescue StandardError => e
    Rails.logger.error("[TelegramBot] Send error: #{e.message}")
  end

  def answer_callback(callback, text)
    @bot.api.answer_callback_query(callback_query_id: callback.id, text: text)
  rescue StandardError => e
    Rails.logger.error("[TelegramBot] Callback answer error: #{e.message}")
  end

  def edit_message(callback, text)
    @bot.api.edit_message_text(
      chat_id: callback.message.chat.id,
      message_id: callback.message.message_id,
      text: text,
      parse_mode: "MarkdownV2"
    )
  rescue StandardError => e
    Rails.logger.error("[TelegramBot] Edit error: #{e.message}")
  end

  # --- Formatting ---

  def esc(text)
    return "" if text.nil?

    text.to_s.gsub(/([_*\[\]()~`>#+\-=|{}.!\\])/, '\\\\\1')
  end

  def fmt(num)
    return "N/A" unless num

    format("%.2f", num.to_f)
  end

  def fmt_change(num)
    return "N/A" unless num

    sign = num.to_f >= 0 ? "+" : ""
    "#{sign}#{format('%.2f', num.to_f)}"
  end

  def number_fmt(num)
    num.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  # --- Signal Handling ---

  def setup_signal_handlers
    %w[TERM INT].each do |signal|
      Signal.trap(signal) do
        @running = false
        Rails.logger.info("[TelegramBot] Received SIG#{signal}, shutting down")
      end
    end
  end
end
