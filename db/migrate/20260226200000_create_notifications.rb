class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.text :message, null: false
      t.boolean :read, default: false
      t.timestamps
    end
    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, [:user_id, :read]
  end
end
