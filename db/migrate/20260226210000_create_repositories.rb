class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.references :service_system, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false
      t.string :default_branch, default: "main"
      t.datetime :last_indexed_at
      t.integer :indexing_status, default: 0, null: false

      t.timestamps
    end

    add_index :repositories, [:service_system_id, :name], unique: true
  end
end
