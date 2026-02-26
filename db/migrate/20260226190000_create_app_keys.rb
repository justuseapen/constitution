class CreateAppKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :app_keys do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :app_keys, :token, unique: true
  end
end
