# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_01_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "alert_type_enum", ["price_above", "price_below", "percent_change_up", "percent_change_down", "price_range_break", "volume_spike", "volume_dry", "rsi_overbought", "rsi_oversold", "macd_crossover_bullish", "macd_crossover_bearish", "bollinger_break_upper", "bollinger_break_lower", "sma_golden_cross", "sma_death_cross", "news_high_impact"]

  create_table "alert_histories", force: :cascade do |t|
    t.text "ai_analysis"
    t.integer "ai_importance_score"
    t.bigint "alert_id", null: false
    t.string "alert_type", null: false
    t.decimal "change_percent", precision: 8, scale: 4
    t.jsonb "condition_snapshot", default: {}, null: false
    t.jsonb "indicator_values"
    t.jsonb "notification_results", default: {}, null: false
    t.decimal "previous_price", precision: 12, scale: 4
    t.decimal "price_at_trigger", precision: 12, scale: 4, null: false
    t.string "symbol", null: false
    t.datetime "triggered_at", null: false
    t.bigint "user_id", null: false
    t.bigint "volume_at_trigger"
    t.index ["alert_id"], name: "index_alert_histories_on_alert_id"
    t.index ["symbol", "triggered_at"], name: "index_alert_histories_on_symbol_and_triggered_at"
    t.index ["triggered_at"], name: "index_alert_histories_on_triggered_at"
    t.index ["user_id", "triggered_at"], name: "index_alert_histories_on_user_id_and_triggered_at"
    t.index ["user_id"], name: "index_alert_histories_on_user_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.boolean "ai_analysis_enabled", default: true, null: false
    t.enum "alert_type", null: false, enum_type: "alert_type_enum"
    t.jsonb "condition", default: {}, null: false
    t.integer "cooldown_minutes", default: 15, null: false
    t.datetime "created_at", null: false
    t.boolean "is_enabled", default: true, null: false
    t.boolean "is_one_time", default: false, null: false
    t.datetime "last_triggered_at"
    t.integer "max_triggers"
    t.text "notes"
    t.string "notification_channels", default: ["telegram"], array: true
    t.string "symbol", limit: 10, null: false
    t.integer "trigger_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["alert_type"], name: "index_alerts_on_alert_type"
    t.index ["symbol", "is_enabled"], name: "index_alerts_on_symbol_and_is_enabled"
    t.index ["user_id", "is_enabled"], name: "index_alerts_on_user_id_and_is_enabled"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "price_snapshots", force: :cascade do |t|
    t.decimal "change_percent", precision: 8, scale: 4
    t.decimal "close_price", precision: 12, scale: 4, null: false
    t.decimal "high_price", precision: 12, scale: 4
    t.string "interval", default: "1m", null: false
    t.decimal "low_price", precision: 12, scale: 4
    t.decimal "open_price", precision: 12, scale: 4
    t.string "source", default: "finnhub", null: false
    t.string "symbol", limit: 10, null: false
    t.datetime "timestamp", null: false
    t.bigint "volume", default: 0, null: false
    t.decimal "vwap", precision: 12, scale: 4
    t.index ["symbol", "interval", "timestamp"], name: "index_price_snapshots_on_symbol_and_interval_and_timestamp"
    t.index ["symbol", "timestamp", "interval"], name: "index_price_snapshots_on_symbol_and_timestamp_and_interval", unique: true
    t.index ["symbol", "timestamp"], name: "index_price_snapshots_on_symbol_and_timestamp"
  end

  create_table "system_logs", force: :cascade do |t|
    t.string "component", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.jsonb "details"
    t.string "level", null: false
    t.text "message", null: false
    t.index ["component", "created_at"], name: "index_system_logs_on_component_and_created_at"
    t.index ["level", "created_at"], name: "index_system_logs_on_level_and_created_at"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "is_active", default: true, null: false
    t.datetime "muted_until"
    t.jsonb "notification_preferences", default: {"email"=>{"enabled"=>true, "digest_only"=>false}, "telegram"=>{"enabled"=>true, "quiet_end"=>"07:00", "quiet_start"=>"23:00"}, "whatsapp"=>{"enabled"=>false}}, null: false
    t.string "telegram_chat_id"
    t.string "timezone", default: "US/Eastern", null: false
    t.datetime "updated_at", null: false
    t.string "username", limit: 50, null: false
    t.string "whatsapp_number"
    t.index ["telegram_chat_id"], name: "index_users_on_telegram_chat_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "watchlist_items", force: :cascade do |t|
    t.string "asset_type", default: "stock", null: false
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.string "exchange", limit: 20
    t.boolean "is_active", default: true, null: false
    t.text "notes"
    t.integer "priority", default: 3, null: false
    t.string "symbol", limit: 10, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["symbol"], name: "index_watchlist_items_on_symbol"
    t.index ["user_id", "is_active"], name: "index_watchlist_items_on_user_id_and_is_active"
    t.index ["user_id", "symbol"], name: "index_watchlist_items_on_user_id_and_symbol", unique: true
    t.index ["user_id"], name: "index_watchlist_items_on_user_id"
  end

  add_foreign_key "alert_histories", "alerts", on_delete: :cascade
  add_foreign_key "alert_histories", "users", on_delete: :cascade
  add_foreign_key "alerts", "users", on_delete: :cascade
  add_foreign_key "watchlist_items", "users", on_delete: :cascade
end
