class CreatePriceSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :price_snapshots, id: :bigint do |t|
      t.string :symbol
      t.decimal :price
      t.decimal :open
      t.decimal :high
      t.decimal :low
      t.bigint :volume
      t.decimal :change_percent
      t.jsonb :data
      t.datetime :captured_at

      t.timestamps
    end
    add_index :price_snapshots, :symbol
    add_index :price_snapshots, [ :symbol, :captured_at ]
  end
end
