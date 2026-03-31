# frozen_string_literal: true

class CreateWatchlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :watchlist_items do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :symbol, null: false, limit: 10
      t.string :company_name, null: false
      t.string :exchange, limit: 20
      t.string :asset_type, null: false, default: "stock"
      t.integer :priority, null: false, default: 3
      t.text :notes
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :watchlist_items, %i[user_id symbol], unique: true
    add_index :watchlist_items, :symbol
    add_index :watchlist_items, %i[user_id is_active]
  end
end
