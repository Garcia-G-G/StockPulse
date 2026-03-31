# frozen_string_literal: true

class CreatePriceSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :price_snapshots do |t|
      t.string :symbol, null: false, limit: 10
      t.decimal :open_price, precision: 12, scale: 4
      t.decimal :high_price, precision: 12, scale: 4
      t.decimal :low_price, precision: 12, scale: 4
      t.decimal :close_price, precision: 12, scale: 4, null: false
      t.bigint :volume, null: false, default: 0
      t.decimal :vwap, precision: 12, scale: 4
      t.decimal :change_percent, precision: 8, scale: 4
      t.datetime :timestamp, null: false
      t.string :interval, null: false, default: "1m"
      t.string :source, null: false, default: "finnhub"
    end

    add_index :price_snapshots, %i[symbol timestamp interval], unique: true
    add_index :price_snapshots, %i[symbol timestamp]
    add_index :price_snapshots, %i[symbol interval timestamp]
  end
end
