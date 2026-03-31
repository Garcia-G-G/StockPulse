# frozen_string_literal: true

class CreateAlerts < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      CREATE TYPE alert_type_enum AS ENUM (
        'price_above', 'price_below', 'percent_change_up', 'percent_change_down',
        'price_range_break', 'volume_spike', 'volume_dry',
        'rsi_overbought', 'rsi_oversold',
        'macd_crossover_bullish', 'macd_crossover_bearish',
        'bollinger_break_upper', 'bollinger_break_lower',
        'sma_golden_cross', 'sma_death_cross',
        'news_high_impact'
      );
    SQL

    create_table :alerts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :symbol, null: false, limit: 10
      t.column :alert_type, :alert_type_enum, null: false
      t.jsonb :condition, null: false, default: {}
      t.boolean :is_enabled, null: false, default: true
      t.boolean :is_one_time, null: false, default: false
      t.integer :cooldown_minutes, null: false, default: 15
      t.datetime :last_triggered_at
      t.integer :trigger_count, null: false, default: 0
      t.integer :max_triggers
      t.string :notification_channels, array: true, default: [ "telegram" ]
      t.boolean :ai_analysis_enabled, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :alerts, %i[symbol is_enabled]
    add_index :alerts, %i[user_id is_enabled]
    add_index :alerts, :alert_type
  end

  def down
    drop_table :alerts
    execute "DROP TYPE alert_type_enum;"
  end
end
