class CreateBlueprints < ActiveRecord::Migration[8.1]
  def change
    create_table :blueprints do |t|
      t.references :project, null: false, foreign_key: true
      t.references :document, foreign_key: true  # optional FK to source document
      t.string :title
      t.text :body
      t.integer :blueprint_type, default: 0
      t.string :status, default: "draft"
      t.integer :version, default: 0
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.timestamps
    end
    add_index :blueprints, :created_by_id
    add_index :blueprints, :updated_by_id
  end
end
