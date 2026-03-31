class CreateWatchlistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :watchlist_items, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.string :symbol
      t.string :name
      t.string :exchange
      t.datetime :added_at
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :watchlist_items, :symbol
  end
end
