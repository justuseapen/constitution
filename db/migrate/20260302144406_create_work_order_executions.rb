class CreateWorkOrderExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :work_order_executions do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :repository, null: true, foreign_key: true
      t.references :triggered_by, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.string :branch_name
      t.string :pull_request_url
      t.text :log
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :work_order_executions, [ :work_order_id, :status ]
  end
end
