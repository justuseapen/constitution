class AddPidToWorkOrderExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_order_executions, :pid, :integer
  end
end
