class CreateBlueprintVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :blueprint_versions do |t|
      t.references :blueprint, null: false, foreign_key: true
      t.text :body_snapshot
      t.integer :version_number
      t.bigint :created_by_id
      t.text :diff_from_previous
      t.timestamps
    end
    add_index :blueprint_versions, :created_by_id
  end
end
