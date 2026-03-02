class FixExtractedArtifactsUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :extracted_artifacts, [ :codebase_file_id, :name ]
    add_index :extracted_artifacts, [ :codebase_file_id, :name, :artifact_type ], unique: true, name: "index_extracted_artifacts_on_file_name_and_type"
  end
end
