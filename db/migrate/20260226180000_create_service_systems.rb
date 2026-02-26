class CreateServiceSystems < ActiveRecord::Migration[8.1]
  def change
    create_table :service_systems do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :repo_url
      t.integer :system_type, default: 0
      t.timestamps
    end
  end
end
