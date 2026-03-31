# frozen_string_literal: true

class CreateAlertHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_histories do |t|
      t.references :alert, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :symbol, null: false
      t.string :alert_type, null: false
      t.datetime :triggered_at, null: false
      t.decimal :price_at_trigger, precision: 12, scale: 4, null: false
      t.decimal :previous_price, precision: 12, scale: 4
      t.decimal :change_percent, precision: 8, scale: 4
      t.bigint :volume_at_trigger
      t.jsonb :indicator_values
      t.jsonb :condition_snapshot, null: false, default: {}
      t.jsonb :notification_results, null: false, default: {}
      t.text :ai_analysis
      t.integer :ai_importance_score
    end

    add_index :alert_histories, %i[symbol triggered_at]
    add_index :alert_histories, %i[user_id triggered_at]
    add_index :alert_histories, :triggered_at
  end
end
