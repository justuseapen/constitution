class CreateExtractedArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :extracted_artifacts do |t|
      t.references :codebase_file, null: false, foreign_key: true
      t.integer :artifact_type, null: false
      t.string :name, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :extracted_artifacts, :artifact_type
    add_index :extracted_artifacts, [ :codebase_file_id, :name ], unique: true
  end
end
