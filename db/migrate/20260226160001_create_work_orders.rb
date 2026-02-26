class CreateWorkOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :work_orders do |t|
      t.references :project, null: false, foreign_key: true
      t.references :phase, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.text :acceptance_criteria
      t.text :implementation_plan
      t.integer :status, default: 0
      t.integer :priority, default: 1
      t.integer :position, default: 0
      t.bigint :assignee_id
      t.timestamps
    end
    add_index :work_orders, :assignee_id
    add_index :work_orders, :status
    add_index :work_orders, :priority
  end
end
