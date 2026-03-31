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

ActiveRecord::Schema[8.1].define(version: 2026_03_31_180135) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["level"], name: "index_system_logs_on_level"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.boolean "notifications_muted", default: false
    t.jsonb "settings", default: {}
    t.string "telegram_chat_id"
    t.datetime "updated_at", null: false
    t.string "whatsapp_number"
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
    t.index ["user_id"], name: "index_watchlist_items_on_user_id"
  end

  add_foreign_key "alert_histories", "alerts"
  add_foreign_key "alert_histories", "users"
  add_foreign_key "alerts", "users"
  add_foreign_key "watchlist_items", "users"
end
