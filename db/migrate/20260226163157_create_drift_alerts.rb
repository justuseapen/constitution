class CreateDriftAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :drift_alerts do |t|
      t.references :project, null: false, foreign_key: true
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.text :message
      t.integer :status, default: 0
      t.timestamps
    end
    add_index :drift_alerts, [ :source_type, :source_id ]
    add_index :drift_alerts, [ :target_type, :target_id ]
    add_index :drift_alerts, :status
  end
end
