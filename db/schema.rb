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

ActiveRecord::Schema[8.1].define(version: 2026_04_07_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "alert_type_enum", ["price_above", "price_below", "percent_change_up", "percent_change_down", "price_range_break", "volume_spike", "volume_dry", "rsi_overbought", "rsi_oversold", "macd_crossover_bullish", "macd_crossover_bearish", "bollinger_break_upper", "bollinger_break_lower", "sma_golden_cross", "sma_death_cross", "news_high_impact"]

  create_table "alert_histories", force: :cascade do |t|
    t.bigint "alert_id", null: false
    t.string "alert_type"
    t.jsonb "channels_notified"
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.text "message"
    t.string "symbol"
    t.datetime "triggered_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["alert_id"], name: "index_alert_histories_on_alert_id"
    t.index ["symbol", "triggered_at"], name: "index_alert_histories_on_symbol_and_triggered_at"
    t.index ["user_id"], name: "index_alert_histories_on_user_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "alert_type"
    t.jsonb "channels"
    t.jsonb "condition"
    t.integer "cooldown_minutes", default: 15
    t.datetime "created_at", null: false
    t.datetime "last_triggered_at"
    t.string "symbol"
    t.integer "trigger_count", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["symbol"], name: "index_alerts_on_symbol"
    t.index ["user_id", "active"], name: "index_alerts_on_user_id_and_active"
    t.index ["user_id", "symbol"], name: "index_alerts_on_user_id_and_symbol"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "price_snapshots", force: :cascade do |t|
    t.datetime "captured_at"
    t.decimal "change_percent"
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.decimal "high"
    t.decimal "low"
    t.decimal "open"
    t.decimal "price"
    t.string "symbol"
    t.datetime "updated_at", null: false
    t.bigint "volume"
    t.index ["captured_at"], name: "index_price_snapshots_on_captured_at"
    t.index ["symbol", "captured_at"], name: "index_price_snapshots_on_symbol_and_captured_at"
    t.index ["symbol"], name: "index_price_snapshots_on_symbol"
  end

  create_table "system_logs", force: :cascade do |t|
    t.string "component"
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.string "level"
    t.text "message"
    t.datetime "updated_at", null: false
    t.index ["component"], name: "index_system_logs_on_component"
    t.index ["created_at"], name: "index_system_logs_on_created_at"
    t.index ["level"], name: "index_system_logs_on_level"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.boolean "notifications_muted", default: false
    t.boolean "onboarding_completed", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.jsonb "settings", default: {}
    t.string "telegram_chat_id"
    t.datetime "updated_at", null: false
    t.string "whatsapp_number"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["telegram_chat_id"], name: "index_users_on_telegram_chat_id"
  end

  create_table "watchlist_items", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "added_at"
    t.datetime "created_at", null: false
    t.string "exchange"
    t.string "name"
    t.string "symbol"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["symbol"], name: "index_watchlist_items_on_symbol"
    t.index ["user_id", "active"], name: "index_watchlist_items_on_user_id_and_active"
    t.index ["user_id", "symbol"], name: "index_watchlist_items_on_user_id_and_symbol"
    t.index ["user_id"], name: "index_watchlist_items_on_user_id"
  end

  add_foreign_key "alert_histories", "alerts"
  add_foreign_key "alert_histories", "users"
  add_foreign_key "alerts", "users"
  add_foreign_key "watchlist_items", "users"
end
