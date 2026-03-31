class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.string :symbol
      t.string :alert_type
      t.jsonb :condition
      t.jsonb :channels
      t.integer :cooldown_minutes, default: 15
      t.datetime :last_triggered_at
      t.integer :trigger_count, default: 0
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :alerts, :symbol
  end
end
