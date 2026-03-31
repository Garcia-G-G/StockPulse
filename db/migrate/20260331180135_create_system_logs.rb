class CreateSystemLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :system_logs, id: :bigint do |t|
      t.string :level
      t.string :component
      t.text :message
      t.jsonb :data

      t.timestamps
    end
    add_index :system_logs, :level
    add_index :system_logs, :component
  end
end
