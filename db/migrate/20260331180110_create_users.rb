class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :bigint do |t|
      t.string :telegram_chat_id
      t.string :email
      t.string :whatsapp_number
      t.string :name
      t.jsonb :settings, default: {}
      t.boolean :notifications_muted, default: false
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :users, :telegram_chat_id
  end
end
