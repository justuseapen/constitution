class CreateProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :project_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true

      t.timestamps
    end
    add_index :project_repositories, [ :project_id, :repository_id ], unique: true
  end
end
