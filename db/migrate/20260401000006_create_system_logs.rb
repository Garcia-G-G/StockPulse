# frozen_string_literal: true

class CreateSystemLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :system_logs do |t|
      t.string :level, null: false
      t.string :component, null: false
      t.text :message, null: false
      t.jsonb :details
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :system_logs, %i[component created_at]
    add_index :system_logs, %i[level created_at]
  end
end
