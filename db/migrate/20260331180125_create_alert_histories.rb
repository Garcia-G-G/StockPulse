class CreateAlertHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :alert_histories, id: :bigint do |t|
      t.references :alert, null: false, foreign_key: true, type: :bigint
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.string :symbol
      t.string :alert_type
      t.text :message
      t.jsonb :data
      t.jsonb :channels_notified
      t.datetime :triggered_at

      t.timestamps
    end
    add_index :alert_histories, [ :symbol, :triggered_at ]
  end
end
