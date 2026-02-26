class CreateSystemDependencies < ActiveRecord::Migration[8.1]
  def change
    create_table :system_dependencies do |t|
      t.references :source_system, null: false, foreign_key: { to_table: :service_systems }
      t.references :target_system, null: false, foreign_key: { to_table: :service_systems }
      t.integer :dependency_type, default: 0
      t.text :description
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    add_index :system_dependencies, [:source_system_id, :target_system_id, :dependency_type],
              unique: true, name: "idx_sys_deps_unique"
  end
end
