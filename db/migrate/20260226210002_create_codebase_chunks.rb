class CreateCodebaseChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :codebase_chunks do |t|
      t.references :codebase_file, null: false, foreign_key: true
      t.text :content, null: false
      t.string :chunk_type
      t.integer :start_line
      t.integer :end_line
      t.vector :embedding, limit: 1536

      t.timestamps
    end

    add_index :codebase_chunks, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
