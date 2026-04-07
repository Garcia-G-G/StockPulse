# frozen_string_literal: true

class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :email, unique: true, where: "email IS NOT NULL"

    add_index :alerts, %i[user_id active], name: "index_alerts_on_user_id_and_active"
    add_index :alerts, %i[user_id symbol], name: "index_alerts_on_user_id_and_symbol"

    add_index :watchlist_items, %i[user_id symbol], name: "index_watchlist_items_on_user_id_and_symbol"
    add_index :watchlist_items, %i[user_id active], name: "index_watchlist_items_on_user_id_and_active"

    add_index :price_snapshots, :captured_at
    add_index :system_logs, :created_at
  end
end
