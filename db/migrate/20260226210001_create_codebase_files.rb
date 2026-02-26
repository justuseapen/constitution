class CreateCodebaseFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :codebase_files do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :path, null: false
      t.string :language
      t.text :content
      t.string :sha
      t.datetime :last_indexed_at

      t.timestamps
    end

    add_index :codebase_files, [:repository_id, :path], unique: true
  end
end
