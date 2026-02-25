class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.text :body
      t.integer :document_type, default: 0
      t.string :status, default: "draft"
      t.integer :version, default: 0
      t.bigint :created_by_id
      t.bigint :updated_by_id

      t.timestamps
    end

    add_index :documents, :created_by_id
    add_index :documents, :updated_by_id
  end
end
