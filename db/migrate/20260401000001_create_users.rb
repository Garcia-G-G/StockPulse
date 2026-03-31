# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false, limit: 50
      t.string :telegram_chat_id
      t.string :whatsapp_number
      t.string :email
      t.jsonb :notification_preferences, null: false, default: {
        telegram: { enabled: true, quiet_start: "23:00", quiet_end: "07:00" },
        whatsapp: { enabled: false },
        email: { enabled: true, digest_only: false }
      }
      t.string :timezone, null: false, default: "US/Eastern"
      t.boolean :is_active, null: false, default: true
      t.datetime :muted_until

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :telegram_chat_id, unique: true
  end
end
